import AppKit
import ApplicationServices

enum AccessibilityWindows {
    private static let vscodeBundleId = "com.microsoft.VSCode"

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func openSettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let target = URL(string: url) { NSWorkspace.shared.open(target) }
    }

    static func vscodeWindowTitles() -> [String] {
        vscodeWindows().map { window in
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
            return value as? String ?? ""
        }
    }

    /// Aciona o botão de fechar da janela, como se a pessoa clicasse nele. Assim o aviso
    /// de arquivo sem salvar continua sendo o do próprio VS Code.
    static func pressClose(windowAt index: Int) -> Bool {
        let windows = vscodeWindows()
        guard windows.indices.contains(index) else { return false }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windows[index], kAXCloseButtonAttribute as CFString, &value) == .success,
              let button = value, CFGetTypeID(button) == AXUIElementGetTypeID()
        else { return false }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    private static func vscodeWindows() -> [AXUIElement] {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: vscodeBundleId).first else {
            return []
        }
        var value: CFTypeRef?
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }
}
