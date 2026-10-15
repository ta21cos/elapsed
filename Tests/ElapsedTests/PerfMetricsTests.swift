import XCTest
@testable import Elapsed

final class PerfMetricsTests: XCTestCase {
    private var snapshots: [PerfSnapshot] = []

    private let launch = Date(timeIntervalSince1970: 1_000_000)

    private func snapshot(wall: TimeInterval, awake: TimeInterval, cpu: Double, footprintMB: UInt64 = 30) -> PerfSnapshot {
        PerfSnapshot(
            wallTime: launch.addingTimeInterval(wall),
            awakeUptime: 5_000 + awake,
            cpuSeconds: cpu,
            footprintBytes: footprintMB * 1_048_576
        )
    }

    /// `PerfMetrics` は init で 1 回、`makeReport()` ごとに 1 回 snapshot を取る
    private func makeMetrics(_ sequence: [PerfSnapshot]) -> PerfMetrics {
        snapshots = sequence
        return PerfMetrics(sample: { [unowned self] in self.snapshots.removeFirst() }, appVersion: "1.0.7(8)")
    }

    func testReportCoversOnlyTheIntervalSinceThePreviousReport() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 1),
            snapshot(wall: 300, awake: 300, cpu: 4),
            snapshot(wall: 600, awake: 600, cpu: 10),
        ])

        _ = metrics.makeReport()
        let report = metrics.makeReport()

        XCTAssertEqual(report.wallSeconds, 300)
        XCTAssertEqual(report.awakeSeconds, 300)
        XCTAssertEqual(report.cpuSeconds, 6, accuracy: 0.0001)
        XCTAssertEqual(report.sinceLaunchAwakeSeconds, 600)
    }

    func testCPUPercentExcludesTimeSpentAsleep() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 0),
            snapshot(wall: 3_600, awake: 300, cpu: 15),
        ])

        let report = metrics.makeReport()

        XCTAssertEqual(report.wallSeconds, 3_600)
        XCTAssertEqual(report.cpuPercentOfAwake, 5, accuracy: 0.0001)
    }

    func testCPUPercentIsZeroWhenNoAwakeTimeElapsed() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 0),
            snapshot(wall: 0, awake: 0, cpu: 0),
        ])

        XCTAssertEqual(metrics.makeReport().cpuPercentOfAwake, 0)
    }

    func testCountersAreResetAfterEachReport() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 0),
            snapshot(wall: 300, awake: 300, cpu: 1),
            snapshot(wall: 600, awake: 600, cpu: 2),
        ])

        metrics.count(.timerIcon)
        metrics.count(.timerIcon)
        metrics.count(.bodyApp)
        let first = metrics.makeReport()
        metrics.count(.bodyApp)
        let second = metrics.makeReport()

        XCTAssertEqual(first.counters[.timerIcon], 2)
        XCTAssertEqual(first.counters[.bodyApp], 1)
        XCTAssertNil(second.counters[.timerIcon])
        XCTAssertEqual(second.counters[.bodyApp], 1)
    }

    func testGaugesAreReadAtReportTime() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 0),
            snapshot(wall: 300, awake: 300, cpu: 1),
        ])
        var sessionCount = 3.0
        metrics.registerGauge("sessions.total") { sessionCount }

        sessionCount = 7
        let report = metrics.makeReport()

        XCTAssertEqual(report.gauges.map(\.name), ["sessions.total"])
        XCTAssertEqual(report.gauges.map(\.value), [7])
    }

    func testCSVListsEveryCounterInAFixedOrderEvenWhenZero() {
        let metrics = makeMetrics([
            snapshot(wall: 0, awake: 0, cpu: 0),
            snapshot(wall: 300, awake: 200, cpu: 10, footprintMB: 34),
        ])
        metrics.count(.bodyApp)
        metrics.registerGauge("sessions.total") { 42 }

        let report = metrics.makeReport()
        let counterNames = PerfCounter.allCases.map(\.rawValue).joined(separator: ",")
        let counterValues = PerfCounter.allCases.map { $0 == .bodyApp ? "1" : "0" }.joined(separator: ",")

        XCTAssertEqual(
            report.csvHeader,
            "timestamp,app_version,wall_s,awake_s,cpu_s,cpu_pct,footprint_mb,since_launch_awake_h,"
                + counterNames + ",sessions.total"
        )
        XCTAssertEqual(
            report.csvRow,
            "1970-01-12T13:51:40Z,1.0.7(8),300.0,200.0,10.000,5.00,34.0,0.06,"
                + counterValues + ",42.0"
        )
    }

    func testCurrentSnapshotReadsProcessCPUTimeAndFootprint() {
        let snapshot = PerfSnapshot.current()

        XCTAssertGreaterThan(snapshot.cpuSeconds, 0)
        XCTAssertGreaterThan(snapshot.footprintBytes, 0)
        XCTAssertGreaterThan(snapshot.awakeUptime, 0)
    }
}
