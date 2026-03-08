import Foundation
import ApplicationServices

final class PermissionManager {
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
