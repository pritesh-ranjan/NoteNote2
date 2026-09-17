import Cocoa
import CoreGraphics
import CoreText

func createCGContext(width: Int, height: Int) -> CGContext? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
}

func savePNG(image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func drawRoundedRect(context: CGContext, rect: CGRect, radius: CGFloat, fillColor: CGColor) {
    context.saveGState()
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fillColor)
    context.fillPath()
    context.restoreGState()
}

func drawString(
    _ string: String,
    in rect: CGRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 4
) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    let attrStr = NSAttributedString(string: string, attributes: attrs)
    let framesetter = CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
    
    // In CGContext where origin is bottom-left
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attrStr.length), path, nil)
    
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    CTFrameDraw(frame, ctx)
}

// MARK: - 1. Generate header_hover.png
func generateHeaderHoverPNG() {
    let width = 640
    let height = 640
    guard let context = createCGContext(width: width, height: height) else { return }
    
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext
    
    // Transparent canvas background
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    
    // Note Card: 560 x 560, centered
    let cardRect = CGRect(x: 40, y: 40, width: 560, height: 560)
    let cardRadius: CGFloat = 28
    
    // Seamless unibody yellow background (100% borderless, NO header line!)
    let yellowColor = CGColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 1.0)
    drawRoundedRect(context: context, rect: cardRect, radius: cardRadius, fillColor: yellowColor)
    
    // --- Header Controls (Hovered state) ---
    let headerY = cardRect.maxY - 56 // top area
    
    // 1. Red close button
    let closeRect = CGRect(x: cardRect.minX + 26, y: headerY + 12, width: 22, height: 22)
    context.setFillColor(CGColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1.0))
    context.fillEllipse(in: closeRect)
    
    // White 'x' on close button
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: closeRect.minX + 6.5, y: closeRect.minY + 6.5))
    context.addLine(to: CGPoint(x: closeRect.maxX - 6.5, y: closeRect.maxY - 6.5))
    context.move(to: CGPoint(x: closeRect.minX + 6.5, y: closeRect.maxY - 6.5))
    context.addLine(to: CGPoint(x: closeRect.maxX - 6.5, y: closeRect.minY + 6.5))
    context.strokePath()
    
    // 2. New note button (+)
    let addRect = CGRect(x: closeRect.maxX + 14, y: closeRect.minY, width: 22, height: 22)
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    context.fillEllipse(in: addRect)
    
    context.setStrokeColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.75))
    context.setLineWidth(2.0)
    context.move(to: CGPoint(x: addRect.midX, y: addRect.minY + 5.5))
    context.addLine(to: CGPoint(x: addRect.midX, y: addRect.maxY - 5.5))
    context.move(to: CGPoint(x: addRect.minX + 5.5, y: addRect.midY))
    context.addLine(to: CGPoint(x: addRect.maxX - 5.5, y: addRect.midY))
    context.strokePath()
    
    // 3. Right-side action buttons: Pin, Shield, Link
    let iconY = closeRect.minY + 1
    let pinX = cardRect.maxX - 48
    let shieldX = pinX - 36
    let linkX = shieldX - 36
    
    // Draw Pin
    context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.75))
    let pinHead = CGRect(x: pinX, y: iconY + 8, width: 14, height: 9)
    let pinPath = CGPath(roundedRect: pinHead, cornerWidth: 2, cornerHeight: 2, transform: nil)
    context.addPath(pinPath)
    context.fillPath()
    context.setStrokeColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.75))
    context.setLineWidth(2.0)
    context.move(to: CGPoint(x: pinHead.midX, y: pinHead.minY))
    context.addLine(to: CGPoint(x: pinHead.midX, y: iconY - 2))
    context.strokePath()
    
    // Draw Shield
    context.setLineWidth(1.8)
    let shieldRect = CGRect(x: shieldX, y: iconY, width: 16, height: 18)
    context.move(to: CGPoint(x: shieldRect.midX, y: shieldRect.maxY))
    context.addLine(to: CGPoint(x: shieldRect.maxX, y: shieldRect.maxY - 4))
    context.addLine(to: CGPoint(x: shieldRect.maxX, y: shieldRect.minY + 7))
    context.addLine(to: CGPoint(x: shieldRect.midX, y: shieldRect.minY))
    context.addLine(to: CGPoint(x: shieldRect.minX, y: shieldRect.minY + 7))
    context.addLine(to: CGPoint(x: shieldRect.minX, y: shieldRect.maxY - 4))
    context.closePath()
    context.strokePath()
    
    // Draw Link
    let linkRect = CGRect(x: linkX, y: iconY + 2, width: 16, height: 14)
    let linkPath = CGPath(roundedRect: linkRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
    context.addPath(linkPath)
    context.strokePath()
    
    // NO SEPARATOR LINE! Seamless unibody background.
    
    // --- Body Content ---
    let textX = cardRect.minX + 30
    let textWidth = cardRect.width - 60
    
    // Title
    let titleRect = CGRect(x: textX, y: cardRect.minY + 360, width: textWidth, height: 60)
    drawString(
        "Launch Strategy 🚀",
        in: titleRect,
        font: .systemFont(ofSize: 26, weight: .bold),
        color: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
    )
    
    // Paragraph Body
    let bodyRect = CGRect(x: textX, y: cardRect.minY + 200, width: textWidth, height: 160)
    drawString(
        "• Distraction-free desktop stickies\n• 100% local, borderless unibody design\n• Hover to reveal controls smoothly\n• Right-click header for 15 designer themes",
        in: bodyRect,
        font: .systemFont(ofSize: 18, weight: .regular),
        color: NSColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 0.92),
        lineSpacing: 8
    )
    
    // Theme Palette preview swatches
    let swatchY = cardRect.minY + 115
    let swatchColors: [CGColor] = [
        CGColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 1.0), // Sun Yellow
        CGColor(red: 1.0, green: 0.86, blue: 0.89, alpha: 1.0), // Pastel Rose
        CGColor(red: 0.84, green: 0.96, blue: 0.88, alpha: 1.0), // Fresh Mint
        CGColor(red: 0.84, green: 0.92, blue: 1.0, alpha: 1.0),  // Sky Blue
        CGColor(red: 0.92, green: 0.86, blue: 1.0, alpha: 1.0),  // Lavender
        CGColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0), // Charcoal Dark
        CGColor(red: 0.965, green: 0.99, blue: 0.97, alpha: 1.0) // Piccolo
    ]
    
    for (i, c) in swatchColors.enumerated() {
        let swRect = CGRect(x: textX + CGFloat(i * 38), y: swatchY, width: 28, height: 28)
        context.setFillColor(c)
        context.fillEllipse(in: swRect)
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.15))
        context.setLineWidth(1.5)
        context.strokeEllipse(in: swRect)
    }
    
    // Footer Tag Pill
    let pillRect = CGRect(x: textX, y: cardRect.minY + 42, width: 290, height: 34)
    drawRoundedRect(context: context, rect: pillRect, radius: 8, fillColor: CGColor(red: 0, green: 0, blue: 0, alpha: 0.07))
    let pillTextRect = CGRect(x: pillRect.minX + 12, y: pillRect.minY + 3, width: pillRect.width - 24, height: 26)
    drawString(
        "⌘P Pin on Top  •  ⌘L Biometric Lock",
        in: pillTextRect,
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 0.85)
    )
    
    if let cgImage = context.makeImage() {
        let outURL = URL(fileURLWithPath: "/Users/priteshranjan/Documents/StickyNotesMac/docs/screenshots/header_hover.png")
        savePNG(image: cgImage, to: outURL)
        print("Generated header_hover.png successfully (640x640)")
    }
}

// MARK: - 2. Generate image_paste_ocr.png
func generateImagePasteOCRPNG() {
    let width = 640
    let height = 640
    guard let context = createCGContext(width: width, height: height) else { return }
    
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext
    
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    
    let cardRect = CGRect(x: 40, y: 40, width: 560, height: 560)
    let cardRadius: CGFloat = 28
    
    // Seamless unibody Sky Blue background (100% borderless, NO header line!)
    let blueColor = CGColor(red: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
    drawRoundedRect(context: context, rect: cardRect, radius: cardRadius, fillColor: blueColor)
    
    // Header Close & Add
    let headerY = cardRect.maxY - 56
    let closeRect = CGRect(x: cardRect.minX + 26, y: headerY + 12, width: 22, height: 22)
    context.setFillColor(CGColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1.0))
    context.fillEllipse(in: closeRect)
    
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: closeRect.minX + 6.5, y: closeRect.minY + 6.5))
    context.addLine(to: CGPoint(x: closeRect.maxX - 6.5, y: closeRect.maxY - 6.5))
    context.move(to: CGPoint(x: closeRect.minX + 6.5, y: closeRect.maxY - 6.5))
    context.addLine(to: CGPoint(x: closeRect.maxX - 6.5, y: closeRect.minY + 6.5))
    context.strokePath()
    
    let addRect = CGRect(x: closeRect.maxX + 14, y: closeRect.minY, width: 22, height: 22)
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    context.fillEllipse(in: addRect)
    
    // NO SEPARATOR LINE! Seamless unibody background.
    
    let textX = cardRect.minX + 30
    let textWidth = cardRect.width - 60
    
    // Attachment Strip Card
    let attachRect = CGRect(x: textX, y: cardRect.minY + 390, width: textWidth, height: 85)
    drawRoundedRect(context: context, rect: attachRect, radius: 12, fillColor: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
    
    // Thumbnail preview box
    let thumbRect = CGRect(x: attachRect.minX + 12, y: attachRect.minY + 10, width: 95, height: 65)
    drawRoundedRect(context: context, rect: thumbRect, radius: 8, fillColor: CGColor(red: 0.18, green: 0.42, blue: 0.85, alpha: 0.85))
    
    // Inner diagram graphic inside thumbnail
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
    context.setLineWidth(1.5)
    context.stroke(CGRect(x: thumbRect.minX + 16, y: thumbRect.minY + 22, width: 24, height: 20))
    context.stroke(CGRect(x: thumbRect.maxX - 40, y: thumbRect.minY + 22, width: 24, height: 20))
    context.move(to: CGPoint(x: thumbRect.minX + 40, y: thumbRect.minY + 32))
    context.addLine(to: CGPoint(x: thumbRect.maxX - 40, y: thumbRect.minY + 32))
    context.strokePath()
    
    // Attachment label
    let attachLabelRect = CGRect(x: thumbRect.maxX + 16, y: attachRect.minY + 38, width: 320, height: 24)
    drawString(
        "architecture_diagram.png",
        in: attachLabelRect,
        font: .systemFont(ofSize: 15, weight: .semibold),
        color: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0)
    )
    let attachSubRect = CGRect(x: thumbRect.maxX + 16, y: attachRect.minY + 14, width: 320, height: 20)
    drawString(
        "Attached image • Click to view in Preview",
        in: attachSubRect,
        font: .systemFont(ofSize: 12, weight: .regular),
        color: NSColor(red: 0.25, green: 0.30, blue: 0.38, alpha: 0.75)
    )
    
    // Title / Extracted OCR Heading
    let titleRect = CGRect(x: textX, y: cardRect.minY + 310, width: textWidth, height: 50)
    drawString(
        "Architecture Specs ⚡",
        in: titleRect,
        font: .systemFont(ofSize: 24, weight: .bold),
        color: NSColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1.0)
    )
    
    // Extracted OCR Bullet Content
    let bodyRect = CGRect(x: textX, y: cardRect.minY + 140, width: textWidth, height: 160)
    drawString(
        "• 100% Offline & Local-First\n• On-Device Apple Vision OCR\n• Zero Network Telemetry & Cloud Calls\n• Reinstall-Safe Atomic Storage",
        in: bodyRect,
        font: .systemFont(ofSize: 18, weight: .regular),
        color: NSColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 0.95),
        lineSpacing: 8
    )
    
    // OCR Framework Status Pill
    let badgeRect = CGRect(x: textX, y: cardRect.minY + 45, width: 320, height: 36)
    drawRoundedRect(context: context, rect: badgeRect, radius: 8, fillColor: CGColor(red: 0.15, green: 0.40, blue: 0.85, alpha: 0.14))
    let badgeTextRect = CGRect(x: badgeRect.minX + 12, y: badgeRect.minY + 3, width: badgeRect.width - 24, height: 26)
    drawString(
        " Apple Vision Framework • Neural Engine",
        in: badgeTextRect,
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: NSColor(red: 0.10, green: 0.30, blue: 0.70, alpha: 1.0)
    )
    
    if let cgImage = context.makeImage() {
        let outURL = URL(fileURLWithPath: "/Users/priteshranjan/Documents/StickyNotesMac/docs/screenshots/image_paste_ocr.png")
        savePNG(image: cgImage, to: outURL)
        print("Generated image_paste_ocr.png successfully (640x640)")
    }
}

generateHeaderHoverPNG()
generateImagePasteOCRPNG()
