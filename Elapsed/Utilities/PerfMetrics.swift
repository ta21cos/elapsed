import Foundation
import os.log

private let logger = Logger(subsystem: "com.ta21cos.Elapsed", category: "Perf")

private extension Bundle {
    var versionLabel: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(version)(\(build))"
    }
}

enum PerfCounter: String, CaseIterable {
    case timerIcon = "timer.icon"
    case timerSession = "timer.session"
    case timerPolling = "timer.polling"
    case assignMenuBarIcon = "assign.menuBarIcon"
    case assignMenuBarTitle = "assign.menuBarTitle"
    case bodyApp = "body.app"
    case bodyPopover = "body.popover"
    case bodyMenuBarLabel = "body.menuBarLabel"
    case imageRender = "image.render"
    case eventSleep = "event.sleep"
    case eventWake = "event.wake"
    case eventLock = "event.lock"
    case eventUnlock = "event.unlock"
    case startMonitoring = "start.monitoring"
}

struct PerfSnapshot {
    let wallTime: Date
    /// `systemUptime` は mach_absolute_time 由来でスリープ中は進まないため、起きていた時間として扱える
    let awakeUptime: TimeInterval
    let cpuSeconds: Double
    let footprintBytes: UInt64

    static func current() -> PerfSnapshot {
        PerfSnapshot(
            wallTime: Date(),
            awakeUptime: ProcessInfo.processInfo.systemUptime,
            cpuSeconds: processCPUSeconds(),
            footprintBytes: physFootprintBytes()
        )
    }

    private static func processCPUSeconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        return user + system
    }

    private static func physFootprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }
}

struct PerfReport {
    let timestamp: Date
    let appVersion: String
    let wallSeconds: TimeInterval
    let awakeSeconds: TimeInterval
    let cpuSeconds: Double
    let footprintBytes: UInt64
    let sinceLaunchAwakeSeconds: TimeInterval
    let counters: [PerfCounter: Int]
    let gauges: [(name: String, value: Double)]

    /// スリープ時間を分母に含めると、長く眠っていた区間ほど使用率が低く見えてしまうため、起きていた時間で割る
    var cpuPercentOfAwake: Double {
        guard awakeSeconds > 0 else { return 0 }
        return cpuSeconds / awakeSeconds * 100
    }

    /// 列の順序を固定するため、カウンタは値が 0 でも全件を出力する
    var csvHeader: String {
        let columns = [
            "timestamp", "app_version", "wall_s", "awake_s", "cpu_s", "cpu_pct", "footprint_mb", "since_launch_awake_h",
        ]
        return (columns + PerfCounter.allCases.map(\.rawValue) + gauges.map(\.name)).joined(separator: ",")
    }

    var csvRow: String {
        var fields = [
            ISO8601DateFormatter().string(from: timestamp),
            appVersion,
            format(wallSeconds),
            format(awakeSeconds),
            format(cpuSeconds, digits: 3),
            format(cpuPercentOfAwake, digits: 2),
            format(Double(footprintBytes) / 1_048_576),
            format(sinceLaunchAwakeSeconds / 3600, digits: 2),
        ]
        fields += PerfCounter.allCases.map { String(counters[$0, default: 0]) }
        fields += gauges.map { format($0.value) }
        return fields.joined(separator: ",")
    }

    private func format(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", value)
    }
}

final class PerfMetrics {
    static let shared = PerfMetrics()

    private let lock = NSLock()
    private let sample: () -> PerfSnapshot
    private let appVersion: String
    private let launchSnapshot: PerfSnapshot
    private var lastSnapshot: PerfSnapshot
    private var counters: [PerfCounter: Int] = [:]
    private var gauges: [(name: String, read: () -> Double)] = []
    private var flushTimer: Timer?

    init(
        sample: @escaping () -> PerfSnapshot = PerfSnapshot.current,
        appVersion: String = Bundle.main.versionLabel
    ) {
        self.sample = sample
        self.appVersion = appVersion
        let snapshot = sample()
        self.launchSnapshot = snapshot
        self.lastSnapshot = snapshot
    }

    /// タイマーのクロージャや `@MainActor` でないサービスからも呼ばれるため、アクターではなくロックで保護する
    func count(_ counter: PerfCounter) {
        lock.lock()
        counters[counter, default: 0] += 1
        lock.unlock()
    }

    func registerGauge(_ name: String, read: @escaping () -> Double) {
        lock.lock()
        gauges.append((name, read))
        lock.unlock()
    }

    /// 区間の値を集計し、カウンタと基準の snapshot をリセットする
    func makeReport() -> PerfReport {
        let snapshot = sample()

        lock.lock()
        let previous = lastSnapshot
        let intervalCounters = counters
        let registeredGauges = gauges
        lastSnapshot = snapshot
        counters = [:]
        lock.unlock()

        return PerfReport(
            timestamp: snapshot.wallTime,
            appVersion: appVersion,
            wallSeconds: snapshot.wallTime.timeIntervalSince(previous.wallTime),
            awakeSeconds: snapshot.awakeUptime - previous.awakeUptime,
            cpuSeconds: snapshot.cpuSeconds - previous.cpuSeconds,
            footprintBytes: snapshot.footprintBytes,
            sinceLaunchAwakeSeconds: snapshot.awakeUptime - launchSnapshot.awakeUptime,
            counters: intervalCounters,
            gauges: registeredGauges.map { ($0.name, $0.read()) }
        )
    }

    /// 設定の変更を監視してタイマーを止めたり作り直したりすると区間の境界がずれるため、
    /// タイマーは常に動かし、書き出すかどうかだけを `isEnabled` で切り替える
    func start(interval: TimeInterval, writer: PerfCSVWriter, isEnabled: @escaping () -> Bool) {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let report = self.makeReport()
            guard isEnabled() else { return }
            do {
                try writer.append(header: report.csvHeader, row: report.csvRow)
            } catch {
                logger.error("Failed to write perf CSV: \(error.localizedDescription, privacy: .public)")
            }
        }
        flushTimer?.tolerance = 5
    }
}

/// unified log は数日で古い行が消え、取り出すにも `log` コマンドが要るため、アプリ自身が CSV に追記する
struct PerfCSVWriter {
    static let defaultFileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Elapsed", isDirectory: true)
        .appendingPathComponent("perf.csv")

    let fileURL: URL
    let maxBytes: Int

    init(fileURL: URL = Self.defaultFileURL, maxBytes: Int = 5 * 1_048_576) {
        self.fileURL = fileURL
        self.maxBytes = maxBytes
    }

    var previousFileURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("perf.previous.csv")
    }

    /// 列の構成が変わったときやサイズの上限を超えたときは、既存のファイルを 1 世代だけ退避して新しく始める
    func append(header: String, row: String) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: fileURL.path), try needsRotation(header: header) {
            if fileManager.fileExists(atPath: previousFileURL.path) {
                try fileManager.removeItem(at: previousFileURL)
            }
            try fileManager.moveItem(at: fileURL, to: previousFileURL)
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            try Data((header + "\n" + row + "\n").utf8).write(to: fileURL)
            return
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((row + "\n").utf8))
    }

    private func needsRotation(header: String) throws -> Bool {
        let size = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
        if size >= maxBytes { return true }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: header.utf8.count + 1) ?? Data()
        return head != Data((header + "\n").utf8)
    }
}
