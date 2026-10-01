import AppKit

// Render the supplied Byte SVG at every native icon size without approximating its geometry.
let markURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Resources/ByteMark.svg")
guard let mark = NSImage(contentsOf: markURL) else { fatalError("Byte mark could not be loaded") }
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
        // 84% white over #66BFFF yields approximately #E7F5FF.
        mark.draw(
            in: NSRect(x: 272, y: 272, width: 480, height: 480),
            from: .zero, operation: .sourceOver, fraction: 0.84)
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
