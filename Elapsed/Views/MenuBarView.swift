import SwiftUI
import AppKit

@MainActor
final class MenuBarImageCache {
    static let shared = MenuBarImageCache()

    private struct Key: Hashable {
        let icon: String
        let title: String
    }

    private var cache: [Key: NSImage] = [:]
    private let capacity = 16

    func image(icon: String, title: String) -> NSImage {
        let key = Key(icon: icon, title: title)
        if let cached = cache[key] {
            return cached
        }
        let image = renderMenuBarImage(icon: icon, title: title)
        if cache.count >= capacity {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = image
        return image
    }
}

struct MenuBarLabel: View {
    let icon: String
    let title: String

    var body: some View {
        Image(nsImage: MenuBarImageCache.shared.image(icon: icon, title: title))
    }
}

private func renderMenuBarImage(icon: String, title: String) -> NSImage {
    let fontSize: CGFloat = 12
    let iconTextSpacing: CGFloat = 3
    let baselineOffset: CGFloat = 0

    let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
    let iconConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
    let iconImage = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
        .withSymbolConfiguration(iconConfig) ?? NSImage()

    let iconSize = iconImage.size

    if title.isEmpty {
        return iconImage
    }

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .baselineOffset: baselineOffset,
    ]
    let textSize = (title as NSString).size(withAttributes: attrs)

    let totalWidth = iconSize.width + iconTextSpacing + textSize.width
    let height = max(iconSize.height, textSize.height)

    let image = NSImage(size: NSSize(width: totalWidth, height: height))
    image.lockFocus()

    let iconY = (height - iconSize.height) / 2
    iconImage.draw(
        in: NSRect(x: 0, y: iconY, width: iconSize.width, height: iconSize.height),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )

    let textX = iconSize.width + iconTextSpacing
    let textY = (height - textSize.height) / 2 + baselineOffset
    (title as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    image.unlockFocus()
    image.isTemplate = true
    return image
}

enum MenuBarIconProvider {
    static func warningThresholdSeconds(workDurationMinutes: Int) -> Int {
        let buffer = min(Constants.Defaults.warningBufferMinutes, workDurationMinutes - 1)
        return max(0, workDurationMinutes - max(buffer, 0)) * 60
    }

    static func icon(
        breakState: BreakReminderService.BreakState,
        activityState: ActivityMonitorService.ActivityState,
        isTracking: Bool,
        sessionSeconds: Int,
        workDurationMinutes: Int
    ) -> String {
        guard isTracking else { return Constants.Icon.stopped }

        switch breakState {
        case .reminderSent:
            return Constants.Icon.activeWarning
        case .working:
            switch activityState {
            case .inactive:
                return Constants.Icon.inactive
            case .active:
                let threshold = warningThresholdSeconds(
                    workDurationMinutes: workDurationMinutes
                )
                if sessionSeconds >= threshold {
                    return Constants.Icon.activeWarning
                }
                return Constants.Icon.activeNormal
            }
        }
    }
}
