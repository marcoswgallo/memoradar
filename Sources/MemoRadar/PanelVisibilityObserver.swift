import AppKit
import SwiftUI

/// Avisa quando a janela do painel aparece ou some. Dentro do `MenuBarExtra`, o `onAppear`
/// só roda na primeira vez e o `onDisappear` não roda, então é preciso observar a janela.
struct PanelVisibilityObserver: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> WatcherView {
        let view = WatcherView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: WatcherView, context: Context) {
        view.onChange = onChange
    }

    final class WatcherView: NSView {
        var onChange: (@MainActor (Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            report()
        }

        private func report() {
            onChange?(window?.occlusionState.contains(.visible) == true)
        }
    }
}
