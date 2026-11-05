import AppKit
import MemoRadarCore
import SwiftUI

/// A cor nunca é o único sinal: atenção e crítico também mudam o desenho.
struct MenuBarIcon: View {
    let state: IconState

    var body: some View {
        Image(nsImage: Self.image(for: state))
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch state {
        case .normal: "MemoRadar, memória normal"
        case .attention: "MemoRadar, pede atenção"
        case .critical: "MemoRadar, memória crítica"
        }
    }

    static func image(for state: IconState) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        switch state {
        case .normal:
            let image = symbol("memorychip", configuration)
            image.isTemplate = true
            return image
        case .attention:
            return badged(symbolName: "memorychip", color: .systemYellow, configuration: configuration)
        case .critical:
            return badged(symbolName: "memorychip.fill", color: .systemRed, configuration: configuration)
        }
    }

    private static func symbol(_ name: String, _ configuration: NSImage.SymbolConfiguration) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: "MemoRadar")?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }

    private static func badged(symbolName: String, color: NSColor, configuration: NSImage.SymbolConfiguration) -> NSImage {
        let tinted = configuration.applying(.init(paletteColors: [color]))
        let base = symbol(symbolName, tinted)
        let size = NSSize(width: base.size.width + 5, height: base.size.height)
        let image = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(origin: .zero, size: base.size))
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - 7, y: size.height - 7, width: 7, height: 7)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
