import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
let sourceImage = CommandLine.arguments.count > 2
    ? NSImage(contentsOfFile: CommandLine.arguments[2])
    : nil

let iconSizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2),
]

for icon in iconSizes {
    let pixels = Int(icon.points * icon.scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("无法创建图标位图")
    }

    rep.size = NSSize(width: icon.points, height: icon.points)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let drawRect = NSRect(x: 0, y: 0, width: icon.points, height: icon.points)
    if let sourceImage {
        drawSourceIcon(sourceImage, in: drawRect)
    } else {
        drawIcon(in: drawRect)
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("无法生成图标 PNG")
    }
    try png.write(to: outputURL.appendingPathComponent(icon.name))
}

private func drawSourceIcon(_ image: NSImage, in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    guard let representation = image.representations.first else {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        return
    }

    let sourceSize = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    let sourceSide = min(sourceSize.width, sourceSize.height)
    let sourceRect = NSRect(
        x: (sourceSize.width - sourceSide) / 2,
        y: (sourceSize.height - sourceSide) / 2,
        width: sourceSide,
        height: sourceSide
    )
    image.draw(in: rect, from: sourceRect, operation: .sourceOver, fraction: 1)
}

private func drawIcon(in rect: NSRect) {
    let side = rect.width

    NSColor.clear.setFill()
    rect.fill()

    let cornerRadius = side * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)

    NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.055, blue: 0.055, alpha: 1),
        NSColor(calibratedRed: 0.105, green: 0.108, blue: 0.112, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.025, blue: 0.025, alpha: 1),
    ])?.draw(in: background, angle: 90)

    // 细描边和顶部高光让深色底在 Finder 里更像原生 macOS 图标。
    NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
    background.lineWidth = max(0.5, side * 0.006)
    background.stroke()

    let highlightRect = rect.insetBy(dx: side * 0.08, dy: side * 0.08)
    let highlight = NSBezierPath(roundedRect: highlightRect, xRadius: cornerRadius * 0.78, yRadius: cornerRadius * 0.78)
    NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.12),
        NSColor(calibratedWhite: 1, alpha: 0.00),
    ])?.draw(in: highlight, angle: 90)

    let center = NSPoint(x: rect.midX, y: rect.midY)
    let ringRadius = side * 0.285
    let ringWidth = max(1.7, side * 0.055)

    drawArc(center: center, radius: ringRadius, width: ringWidth, start: 130, end: -48, clockwise: false, color: NSColor(calibratedWhite: 1, alpha: 0.16))
    drawArc(center: center, radius: ringRadius, width: ringWidth, start: 136, end: -56, clockwise: true, color: .white)
    drawArc(center: center, radius: ringRadius, width: ringWidth, start: 60, end: 24, clockwise: true, color: NSColor(calibratedWhite: 0.58, alpha: 0.96))

    let text = "C"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize = side * 0.38
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1),
        .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributed.size()
    attributed.draw(in: NSRect(
        x: rect.midX - textSize.width / 2,
        y: rect.midY - textSize.height / 2 - side * 0.01,
        width: textSize.width,
        height: textSize.height
    ))
}

private func drawArc(center: NSPoint, radius: CGFloat, width: CGFloat, start: CGFloat, end: CGFloat, clockwise: Bool, color: NSColor) {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: clockwise)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}
