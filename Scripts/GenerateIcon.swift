import AppKit

// Original vector artwork. Render at each native icon size for crisp edges.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0), let graphics = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            fatalError("Icon bitmap could not be allocated")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let outer = NSBezierPath(roundedRect: NSRect(x: 92, y: 92, width: 840, height: 840), xRadius: 188, yRadius: 188)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        NSColor(red: 102 / 255, green: 191 / 255, blue: 1, alpha: 1).setFill()
        outer.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        outer.lineWidth = 3
        outer.stroke()
        // Byte's solid B mark. Coordinates are original vector geometry, scaled
        // consistently across all representations; the blue identifies Relay.
        context.translateBy(x: 265, y: 275)
        context.scaleBy(x: 16.0, y: 16.0)
        let mark = NSBezierPath()
        mark.move(to: NSPoint(x: 3.2, y: 0))
        mark.line(to: NSPoint(x: 24.2, y: 0))
        mark.curve(
            to: NSPoint(x: 26.4, y: 0.9), controlPoint1: NSPoint(x: 25.2, y: 0), controlPoint2: NSPoint(x: 25.7, y: 0.2)
        )
        mark.line(to: NSPoint(x: 29.6, y: 4.1))
        mark.curve(
            to: NSPoint(x: 30.5, y: 6.3), controlPoint1: NSPoint(x: 30.3, y: 4.8),
            controlPoint2: NSPoint(x: 30.5, y: 5.3))
        mark.line(to: NSPoint(x: 30.5, y: 12.5))
        mark.curve(
            to: NSPoint(x: 29, y: 14), controlPoint1: NSPoint(x: 30.5, y: 13.6), controlPoint2: NSPoint(x: 30, y: 14))
        mark.line(to: NSPoint(x: 24.8, y: 14))
        mark.curve(
            to: NSPoint(x: 24, y: 14.8), controlPoint1: NSPoint(x: 24.2, y: 14), controlPoint2: NSPoint(x: 24, y: 14.2))
        mark.line(to: NSPoint(x: 24, y: 15.2))
        mark.curve(
            to: NSPoint(x: 24.8, y: 16), controlPoint1: NSPoint(x: 24, y: 15.8), controlPoint2: NSPoint(x: 24.2, y: 16))
        mark.line(to: NSPoint(x: 29, y: 16))
        mark.curve(
            to: NSPoint(x: 30.5, y: 17.5), controlPoint1: NSPoint(x: 30, y: 16),
            controlPoint2: NSPoint(x: 30.5, y: 16.4))
        mark.line(to: NSPoint(x: 30.5, y: 23.7))
        mark.curve(
            to: NSPoint(x: 29.6, y: 25.9), controlPoint1: NSPoint(x: 30.5, y: 24.7),
            controlPoint2: NSPoint(x: 30.3, y: 25.2))
        mark.line(to: NSPoint(x: 26.4, y: 29.1))
        mark.curve(
            to: NSPoint(x: 24.2, y: 30), controlPoint1: NSPoint(x: 25.7, y: 29.8),
            controlPoint2: NSPoint(x: 25.2, y: 30))
        mark.line(to: NSPoint(x: 3.2, y: 30))
        mark.curve(
            to: NSPoint(x: 0.5, y: 27.3), controlPoint1: NSPoint(x: 1.1, y: 30), controlPoint2: NSPoint(x: 0.5, y: 29.4)
        )
        mark.line(to: NSPoint(x: 0.5, y: 2.7))
        mark.curve(
            to: NSPoint(x: 3.2, y: 0), controlPoint1: NSPoint(x: 0.5, y: 0.6), controlPoint2: NSPoint(x: 1.1, y: 0))
        mark.close()
        NSColor(red: 0.055, green: 0.13, blue: 0.19, alpha: 1).setFill()
        mark.fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon render failed") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}

// Package PNG representations directly, avoiding iconutil's platform-dependent encoders.
if CommandLine.arguments.count > 2 {
    let representations = [
        ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"), ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"), ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"), ("ic14", "icon_256x256@2x.png"),
    ]
    func bigEndian(_ value: Int) -> Data {
        var number = UInt32(value).bigEndian
        return withUnsafeBytes(of: &number) { Data($0) }
    }
    var contents = Data()
    for (type, filename) in representations {
        let png = try Data(contentsOf: directory.appendingPathComponent(filename))
        contents.append(Data(type.utf8))
        contents.append(bigEndian(png.count + 8))
        contents.append(png)
    }
    var icon = Data("icns".utf8)
    icon.append(bigEndian(contents.count + 8))
    icon.append(contents)
    try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
