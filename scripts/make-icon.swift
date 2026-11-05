// Gera Resources/AppIcon.icns. Uso: swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

func draw(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = CGFloat(pixels) / 1024

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)
    }
    let center = NSPoint(x: 512 * unit, y: 512 * unit)

    // Fundo no formato padrão de ícones do macOS, com margem transparente.
    let base = rect(100, 100, 824, 824)
    let background = NSBezierPath(roundedRect: base, xRadius: 185 * unit, yRadius: 185 * unit)
    NSGradient(
        starting: NSColor(calibratedRed: 0.09, green: 0.16, blue: 0.30, alpha: 1),
        ending: NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.13, alpha: 1)
    )!.draw(in: background, angle: -90)

    NSGraphicsContext.current?.saveGraphicsState()
    background.addClip()

    // Varredura do radar.
    let accent = NSColor(calibratedRed: 0.27, green: 0.88, blue: 0.78, alpha: 1)
    let sweep = NSBezierPath()
    sweep.move(to: center)
    sweep.appendArc(withCenter: center, radius: 620 * unit, startAngle: 12, endAngle: 72)
    sweep.close()
    accent.withAlphaComponent(0.16).setFill()
    sweep.fill()

    // Anéis do radar.
    for radius in [240.0, 330.0] as [CGFloat] {
        let ring = NSBezierPath(ovalIn: rect(512 - radius, 512 - radius, radius * 2, radius * 2))
        ring.lineWidth = 14 * unit
        accent.withAlphaComponent(radius < 300 ? 0.55 : 0.30).setStroke()
        ring.stroke()
    }
    NSGraphicsContext.current?.restoreGraphicsState()

    // Chip de memória, com terminais de cima a baixo.
    let chip = NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.99, alpha: 1)
    chip.setFill()
    for index in 0..<4 {
        let x = 512 - 165 + CGFloat(index) * 110 - 22
        NSBezierPath(roundedRect: rect(x, 325, 44, 374), xRadius: 14 * unit, yRadius: 14 * unit).fill()
    }
    NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.21, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect(320, 372, 384, 280), xRadius: 54 * unit, yRadius: 54 * unit).fill()
    chip.setFill()
    NSBezierPath(roundedRect: rect(340, 392, 344, 240), xRadius: 40 * unit, yRadius: 40 * unit).fill()
    accent.setFill()
    NSBezierPath(roundedRect: rect(412, 462, 200, 100), xRadius: 22 * unit, yRadius: 22 * unit).fill()

    // O ponto amarelo é o mesmo aviso do ícone da barra de menu.
    NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: rect(690, 655, 118, 118)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString).appendingPathExtension("iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try draw(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try draw(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try tool.run()
tool.waitUntilExit()
exit(tool.terminationStatus)
