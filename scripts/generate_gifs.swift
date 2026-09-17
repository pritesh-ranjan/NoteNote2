import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Color Palette & Helpers
struct ThemeColor {
    let name: String
    let bg: NSColor
    let text: NSColor
    let headerBorder: NSColor
}

let colors: [ThemeColor] = [
    ThemeColor(name: "Sunny Yellow", bg: NSColor(red: 1.00, green: 0.95, blue: 0.65, alpha: 1.0), text: NSColor(red: 0.20, green: 0.18, blue: 0.05, alpha: 1.0), headerBorder: NSColor(red: 0.90, green: 0.85, blue: 0.55, alpha: 0.4)),
    ThemeColor(name: "Blush Pink", bg: NSColor(red: 1.00, green: 0.84, blue: 0.88, alpha: 1.0), text: NSColor(red: 0.25, green: 0.08, blue: 0.12, alpha: 1.0), headerBorder: NSColor(red: 0.90, green: 0.74, blue: 0.78, alpha: 0.4)),
    ThemeColor(name: "Mint", bg: NSColor(red: 0.83, green: 0.96, blue: 0.87, alpha: 1.0), text: NSColor(red: 0.08, green: 0.25, blue: 0.12, alpha: 1.0), headerBorder: NSColor(red: 0.73, green: 0.86, blue: 0.77, alpha: 0.4)),
    ThemeColor(name: "Lavender", bg: NSColor(red: 0.91, green: 0.86, blue: 0.99, alpha: 1.0), text: NSColor(red: 0.18, green: 0.08, blue: 0.28, alpha: 1.0), headerBorder: NSColor(red: 0.81, green: 0.76, blue: 0.89, alpha: 0.4)),
    ThemeColor(name: "Charcoal", bg: NSColor(red: 0.14, green: 0.15, blue: 0.16, alpha: 1.0), text: NSColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0), headerBorder: NSColor(red: 0.25, green: 0.26, blue: 0.28, alpha: 0.6)),
    ThemeColor(name: "Sky", bg: NSColor(red: 0.82, green: 0.92, blue: 0.99, alpha: 1.0), text: NSColor(red: 0.06, green: 0.18, blue: 0.30, alpha: 1.0), headerBorder: NSColor(red: 0.72, green: 0.82, blue: 0.89, alpha: 0.4)),
    ThemeColor(name: "Peach", bg: NSColor(red: 1.00, green: 0.88, blue: 0.78, alpha: 1.0), text: NSColor(red: 0.28, green: 0.14, blue: 0.05, alpha: 1.0), headerBorder: NSColor(red: 0.90, green: 0.78, blue: 0.68, alpha: 0.4))
]

func drawCursor(at point: NSPoint, isClicking: Bool = false) {
    let path = NSBezierPath()
    path.move(to: point)
    path.line(to: NSPoint(x: point.x + 0, y: point.y - 18))
    path.line(to: NSPoint(x: point.x + 5, y: point.y - 14))
    path.line(to: NSPoint(x: point.x + 9, y: point.y - 21))
    path.line(to: NSPoint(x: point.x + 12, y: point.y - 19))
    path.line(to: NSPoint(x: point.x + 8, y: point.y - 12))
    path.line(to: NSPoint(x: point.x + 14, y: point.y - 12))
    path.close()
    
    NSGraphicsContext.saveGraphicsState()
    if isClicking {
        let clickCircle = NSBezierPath(ovalIn: NSRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
        NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.4).setFill()
        clickCircle.fill()
    }
    
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 1, height: -2)
    shadow.shadowBlurRadius = 3
    shadow.set()
    
    NSColor.black.setFill()
    path.fill()
    
    NSColor.white.setStroke()
    path.lineWidth = 1.4
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func exportGIF(frames: [CGImage], delays: [Double], to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
        print("Failed to create destination for \(url)")
        return
    }
    
    let fileProps: [String: Any] = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: 0
        ]
    ]
    CGImageDestinationSetProperties(destination, fileProps as CFDictionary)
    
    for (i, img) in frames.enumerated() {
        let delay = i < delays.count ? delays[i] : 0.12
        let frameProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: delay
            ]
        ]
        CGImageDestinationAddImage(destination, img, frameProps as CFDictionary)
    }
    
    if CGImageDestinationFinalize(destination) {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        print("✅ Created \(url.lastPathComponent) (\(bytes / 1024) KB, \(frames.count) frames)")
    } else {
        print("❌ Failed to finalize GIF at \(url)")
    }
}

func createCanvas(size: NSSize) -> (NSBitmapImageRep, NSGraphicsContext) {
    let scale: CGFloat = 2.0
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    return (rep, ctx)
}

// Draw macOS App Window Backdrop
func drawDesktopBackground(size: NSSize) {
    // Elegant dark desktop gradient
    let grad = NSGradient(starting: NSColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0),
                          ending: NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1.0))!
    grad.draw(in: NSRect(origin: .zero, size: size), angle: -45)
    
    // Subtle desktop grid dots
    NSColor(white: 1.0, alpha: 0.04).setFill()
    let step: CGFloat = 24
    var x: CGFloat = 12
    while x < size.width {
        var y: CGFloat = 12
        while y < size.height {
            NSRect(x: x, y: y, width: 1.5, height: 1.5).fill()
            y += step
        }
        x += step
    }
}

func drawStickyShadow(rect: NSRect, radius: CGFloat = 16) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - 1. GENERATE HEADER HOVER & MENU GIF
func generateHeaderHoverGIF() {
    print("🎨 Generating 1. Header Hover & Menu GIF...")
    let canvasSize = NSSize(width: 600, height: 640)
    let noteRect = NSRect(x: 75, y: 70, width: 450, height: 500)
    var frames: [CGImage] = []
    var delays: [Double] = []
    
    let totalFrames = 28
    for f in 0..<totalFrames {
        let (rep, ctx) = createCanvas(size: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        drawDesktopBackground(size: canvasSize)
        drawStickyShadow(rect: noteRect)
        
        // Note color: transitions to Lavender at frame 16, to Mint at frame 21, back to Yellow at frame 26
        var currentColor = colors[0] // Yellow
        if f >= 16 && f < 21 {
            currentColor = colors[3] // Lavender
        } else if f >= 21 && f < 26 {
            currentColor = colors[2] // Mint
        }
        
        // Note Body
        let notePath = NSBezierPath(roundedRect: noteRect, xRadius: 16, yRadius: 16)
        currentColor.bg.setFill()
        notePath.fill()
        
        // Header Border
        let headerH: CGFloat = 40
        let headerRect = NSRect(x: noteRect.minX, y: noteRect.maxY - headerH, width: noteRect.width, height: headerH)
        currentColor.headerBorder.setFill()
        NSRect(x: noteRect.minX, y: headerRect.minY, width: noteRect.width, height: 1).fill()
        
        // Header Buttons Alpha:
        // Frames 0-3: 0.0 (hidden)
        // Frames 4-7: fade in 0.2 -> 1.0
        // Frames 8-24: 1.0
        // Frames 25-27: fade out 0.8 -> 0.0
        var buttonAlpha: CGFloat = 0.0
        if f >= 4 && f < 8 {
            buttonAlpha = CGFloat(f - 3) / 4.0
        } else if f >= 8 && f < 25 {
            buttonAlpha = 1.0
        } else if f >= 25 {
            buttonAlpha = max(0.0, 1.0 - CGFloat(f - 24) / 3.0)
        }
        
        // Left Window Buttons (Close Red, Plus)
        let closeCenter = NSPoint(x: noteRect.minX + 22, y: headerRect.midY)
        let plusCenter = NSPoint(x: noteRect.minX + 44, y: headerRect.midY)
        
        if buttonAlpha > 0.0 {
            NSGraphicsContext.saveGraphicsState()
            // Close button
            let closeBtn = NSBezierPath(ovalIn: NSRect(x: closeCenter.x - 6, y: closeCenter.y - 6, width: 12, height: 12))
            NSColor.systemRed.withAlphaComponent(buttonAlpha).setFill()
            closeBtn.fill()
            
            // Plus button
            let plusBtn = NSBezierPath(ovalIn: NSRect(x: plusCenter.x - 6, y: plusCenter.y - 6, width: 12, height: 12))
            NSColor(white: 0.0, alpha: 0.12 * buttonAlpha).setFill()
            plusBtn.fill()
            
            // Plus cross
            let plusP = NSBezierPath()
            plusP.move(to: NSPoint(x: plusCenter.x - 3, y: plusCenter.y))
            plusP.line(to: NSPoint(x: plusCenter.x + 3, y: plusCenter.y))
            plusP.move(to: NSPoint(x: plusCenter.x, y: plusCenter.y - 3))
            plusP.line(to: NSPoint(x: plusCenter.x, y: plusCenter.y + 3))
            currentColor.text.withAlphaComponent(0.7 * buttonAlpha).setStroke()
            plusP.lineWidth = 1.2
            plusP.stroke()
            
            // Right Action Buttons (Palette, Pin, Lock)
            let rightBtns: [(x: CGFloat, sym: String)] = [
                (noteRect.maxX - 24, "pin"),
                (noteRect.maxX - 48, "lock"),
                (noteRect.maxX - 72, "paintpalette")
            ]
            for btn in rightBtns {
                let p = NSBezierPath(ovalIn: NSRect(x: btn.x - 8, y: headerRect.midY - 8, width: 16, height: 16))
                NSColor(white: 0.0, alpha: 0.08 * buttonAlpha).setFill()
                p.fill()
                
                let iconStr = btn.sym == "pin" ? "📌" : (btn.sym == "lock" ? "🔒" : "🎨")
                let attr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.labelColor.withAlphaComponent(buttonAlpha)
                ]
                let s = NSAttributedString(string: iconStr, attributes: attr)
                s.draw(at: NSPoint(x: btn.x - 5, y: headerRect.midY - 5))
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Note Content
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: currentColor.text
        ]
        NSAttributedString(string: "Project Launch Notes 🚀", attributes: titleAttr)
            .draw(at: NSPoint(x: noteRect.minX + 22, y: noteRect.maxY - 80))
            
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: currentColor.text.withAlphaComponent(0.85)
        ]
        let bodyText = "Hover over note to reveal quick actions.\nRight-click header to choose from 15 themes\nand adjust live window opacity."
        bodyText.draw(in: NSRect(x: noteRect.minX + 22, y: noteRect.minY + 280, width: noteRect.width - 44, height: 80), withAttributes: bodyAttr)
        
        // Floating Palette Menu
        // Appears at frames 11 to 24
        var menuAlpha: CGFloat = 0.0
        if f >= 11 && f < 14 {
            menuAlpha = CGFloat(f - 10) / 3.0
        } else if f >= 14 && f < 25 {
            menuAlpha = 1.0
        }
        
        if menuAlpha > 0.0 {
            let menuW: CGFloat = 280
            let menuH: CGFloat = 120
            let menuRect = NSRect(x: noteRect.maxX - menuW - 10, y: headerRect.minY - menuH - 8, width: menuW, height: menuH)
            
            NSGraphicsContext.saveGraphicsState()
            let mShadow = NSShadow()
            mShadow.shadowColor = NSColor.black.withAlphaComponent(0.35 * menuAlpha)
            mShadow.shadowOffset = NSSize(width: 0, height: -6)
            mShadow.shadowBlurRadius = 16
            mShadow.set()
            
            let mPath = NSBezierPath(roundedRect: menuRect, xRadius: 12, yRadius: 12)
            NSColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 0.95 * menuAlpha).setFill()
            mPath.fill()
            
            NSColor(white: 1.0, alpha: 0.15 * menuAlpha).setStroke()
            mPath.lineWidth = 1.0
            mPath.stroke()
            
            // Header: "COLOR • [NAME]"
            let activeName = (f >= 21) ? "MINT" : ((f >= 16) ? "LAVENDER" : "SUNNY YELLOW")
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor(white: 0.8, alpha: menuAlpha)
            ]
            NSAttributedString(string: "COLOR • \(activeName)", attributes: labelAttr)
                .draw(at: NSPoint(x: menuRect.minX + 14, y: menuRect.maxY - 24))
                
            // Draw Color Swatches (Row 1 & Row 2)
            let circleSize: CGFloat = 20
            let spacing: CGFloat = 9
            for (idx, col) in colors.enumerated() {
                let isRow1 = idx < 4
                let colIdx = isRow1 ? idx : (idx - 4)
                let cx = menuRect.minX + 16 + CGFloat(colIdx) * (circleSize + spacing)
                let cy = isRow1 ? (menuRect.maxY - 52) : (menuRect.maxY - 80)
                let cRect = NSRect(x: cx, y: cy, width: circleSize, height: circleSize)
                
                col.bg.withAlphaComponent(menuAlpha).setFill()
                NSBezierPath(ovalIn: cRect).fill()
                
                // Highlight active swatch
                if col.name.uppercased().contains(activeName) {
                    let ring = NSBezierPath(ovalIn: cRect.insetBy(dx: -2.5, dy: -2.5))
                    NSColor.white.withAlphaComponent(menuAlpha).setStroke()
                    ring.lineWidth = 2.0
                    ring.stroke()
                }
            }
            
            // Opacity slider bar
            let sliderRect = NSRect(x: menuRect.minX + 16, y: menuRect.minY + 12, width: menuRect.width - 32, height: 6)
            let sliderTrack = NSBezierPath(roundedRect: sliderRect, xRadius: 3, yRadius: 3)
            NSColor(white: 1.0, alpha: 0.2 * menuAlpha).setFill()
            sliderTrack.fill()
            
            // Slider filled part & knob
            let filledW = sliderRect.width * 0.85
            let filledTrack = NSBezierPath(roundedRect: NSRect(x: sliderRect.minX, y: sliderRect.minY, width: filledW, height: 6), xRadius: 3, yRadius: 3)
            NSColor.systemBlue.withAlphaComponent(menuAlpha).setFill()
            filledTrack.fill()
            
            let knobRect = NSRect(x: sliderRect.minX + filledW - 6, y: sliderRect.minY - 4, width: 14, height: 14)
            NSColor.white.withAlphaComponent(menuAlpha).setFill()
            NSBezierPath(ovalIn: knobRect).fill()
            
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Animate Cursor
        var cursorPos = NSPoint(x: 40, y: 150)
        var clicking = false
        if f >= 4 && f < 8 {
            cursorPos = NSPoint(x: noteRect.maxX - 70, y: headerRect.midY)
        } else if f >= 8 && f < 12 {
            cursorPos = NSPoint(x: noteRect.maxX - 72, y: headerRect.midY)
            if f >= 10 { clicking = true }
        } else if f >= 12 && f < 16 {
            cursorPos = NSPoint(x: noteRect.maxX - 160, y: headerRect.minY - 40)
        } else if f >= 16 && f < 21 {
            cursorPos = NSPoint(x: noteRect.maxX - 180, y: headerRect.minY - 50)
            if f == 17 { clicking = true }
        } else if f >= 21 && f < 25 {
            cursorPos = NSPoint(x: noteRect.maxX - 210, y: headerRect.minY - 50)
            if f == 22 { clicking = true }
        } else if f >= 25 {
            cursorPos = NSPoint(x: 30, y: 120)
        }
        
        drawCursor(at: cursorPos, isClicking: clicking)
        
        NSGraphicsContext.restoreGraphicsState()
        frames.append(rep.cgImage!)
        
        // Delays
        let d: Double = (f == 17 || f == 22) ? 0.35 : ((f == 11 || f == 27) ? 0.4 : 0.11)
        delays.append(d)
    }
    
    exportGIF(frames: frames, delays: delays, to: URL(fileURLWithPath: "docs/screenshots/header_hover.gif"))
}

// MARK: - 2. GENERATE MARKDOWN & CHECKLIST GIF
func generateMarkdownChecklistGIF() {
    print("🎨 Generating 2. Markdown & Checklist GIF...")
    let canvasSize = NSSize(width: 640, height: 640)
    let noteRect = NSRect(x: 95, y: 70, width: 450, height: 500)
    var frames: [CGImage] = []
    var delays: [Double] = []
    
    let totalFrames = 28
    for f in 0..<totalFrames {
        let (rep, ctx) = createCanvas(size: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        drawDesktopBackground(size: canvasSize)
        drawStickyShadow(rect: noteRect)
        
        let currentColor = colors[0] // Yellow
        let notePath = NSBezierPath(roundedRect: noteRect, xRadius: 16, yRadius: 16)
        currentColor.bg.setFill()
        notePath.fill()
        
        // Header
        let headerH: CGFloat = 40
        let headerRect = NSRect(x: noteRect.minX, y: noteRect.maxY - headerH, width: noteRect.width, height: headerH)
        currentColor.headerBorder.setFill()
        NSRect(x: noteRect.minX, y: headerRect.minY, width: noteRect.width, height: 1).fill()
        
        // Window Controls
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: noteRect.minX + 16, y: headerRect.midY - 5, width: 10, height: 10)).fill()
        NSColor(white: 0.0, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: NSRect(x: noteRect.minX + 34, y: headerRect.midY - 5, width: 10, height: 10)).fill()
        
        // Markdown Title `# Sprint Release Checklist`
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: currentColor.text
        ]
        NSAttributedString(string: "Sprint Release Checklist 🚀", attributes: titleAttr)
            .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.maxY - 85))
            
        // Subheading `## Deliverables`
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: currentColor.text.withAlphaComponent(0.85)
        ]
        NSAttributedString(string: "## Core Deliverables", attributes: subAttr)
            .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.maxY - 120))
            
        // Checkboxes states based on frame:
        // Item 1 checked at f >= 8
        // Item 2 checked at f >= 16
        // Item 3 checked at f >= 23
        let item1Checked = f >= 8
        let item2Checked = f >= 16
        let item3Checked = f >= 23
        
        let checklistItems: [(text: String, checked: Bool, y: CGFloat)] = [
            ("Wireframe onboarding user flow", item1Checked, noteRect.maxY - 165),
            ("Build Apple Vision OCR engine", item2Checked, noteRect.maxY - 205),
            ("Verify code signing persistence", item3Checked, noteRect.maxY - 245)
        ]
        
        for item in checklistItems {
            let boxRect = NSRect(x: noteRect.minX + 24, y: item.y, width: 18, height: 18)
            let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
            
            if item.checked {
                NSColor.systemBlue.setFill()
                boxPath.fill()
                
                // Draw checkmark
                let checkP = NSBezierPath()
                checkP.move(to: NSPoint(x: boxRect.minX + 4, y: boxRect.minY + 9))
                checkP.line(to: NSPoint(x: boxRect.minX + 8, y: boxRect.minY + 5))
                checkP.line(to: NSPoint(x: boxRect.minX + 14, y: boxRect.minY + 13))
                NSColor.white.setStroke()
                checkP.lineWidth = 2.0
                checkP.lineCapStyle = .round
                checkP.stroke()
            } else {
                NSColor.white.withAlphaComponent(0.9).setFill()
                boxPath.fill()
                currentColor.text.withAlphaComponent(0.3).setStroke()
                boxPath.lineWidth = 1.2
                boxPath.stroke()
            }
            
            let itemAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: item.checked ? currentColor.text.withAlphaComponent(0.45) : currentColor.text,
                .strikethroughStyle: item.checked ? NSUnderlineStyle.single.rawValue : 0
            ]
            NSAttributedString(string: item.text, attributes: itemAttr)
                .draw(at: NSPoint(x: boxRect.maxX + 10, y: item.y - 1))
        }
        
        // Markdown Code Block chip
        let codeY = noteRect.maxY - 310
        let codeLabel = NSAttributedString(string: "Run command: `scripts/build_app.sh`", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: currentColor.text
        ])
        
        let chipRect = NSRect(x: noteRect.minX + 24, y: codeY, width: 280, height: 26)
        NSColor(white: 0.0, alpha: 0.07).setFill()
        NSBezierPath(roundedRect: chipRect, xRadius: 6, yRadius: 6).fill()
        codeLabel.draw(at: NSPoint(x: chipRect.minX + 10, y: chipRect.minY + 5))
        
        // Footer Progress Counter
        let completedCount = (item1Checked ? 1 : 0) + (item2Checked ? 1 : 0) + (item3Checked ? 1 : 0)
        let percent = Int((Double(completedCount) / 3.0) * 100)
        let statusText = completedCount == 3 ? "Tasks: 3/3 completed (100%) 🎉 All done!" : "Tasks: \(completedCount)/3 completed (\(percent)%)"
        
        let statusAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: completedCount == 3 ? NSColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1.0) : currentColor.text.withAlphaComponent(0.65)
        ]
        NSAttributedString(string: statusText, attributes: statusAttr)
            .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.minY + 20))
            
        // Cursor Movement & Clicks
        var cursorPos = NSPoint(x: 50, y: 180)
        var clicking = false
        if f >= 4 && f < 10 {
            cursorPos = NSPoint(x: noteRect.minX + 32, y: checklistItems[0].y + 9)
            if f == 7 || f == 8 { clicking = true }
        } else if f >= 10 && f < 18 {
            cursorPos = NSPoint(x: noteRect.minX + 32, y: checklistItems[1].y + 9)
            if f == 15 || f == 16 { clicking = true }
        } else if f >= 18 && f < 25 {
            cursorPos = NSPoint(x: noteRect.minX + 32, y: checklistItems[2].y + 9)
            if f == 22 || f == 23 { clicking = true }
        } else if f >= 25 {
            cursorPos = NSPoint(x: noteRect.minX + 160, y: noteRect.minY + 25)
        }
        
        drawCursor(at: cursorPos, isClicking: clicking)
        
        NSGraphicsContext.restoreGraphicsState()
        frames.append(rep.cgImage!)
        
        let d: Double = (f == 8 || f == 16 || f == 23) ? 0.35 : ((f == 27) ? 0.8 : 0.11)
        delays.append(d)
    }
    
    exportGIF(frames: frames, delays: delays, to: URL(fileURLWithPath: "docs/screenshots/markdown_support.gif"))
}

// MARK: - 3. GENERATE IMAGE PASTE & VISION OCR GIF
func generateImagePasteOCRGIF() {
    print("🎨 Generating 3. Image Paste & Vision OCR GIF...")
    let canvasSize = NSSize(width: 640, height: 640)
    let noteRect = NSRect(x: 95, y: 70, width: 450, height: 500)
    var frames: [CGImage] = []
    var delays: [Double] = []
    
    let totalFrames = 28
    for f in 0..<totalFrames {
        let (rep, ctx) = createCanvas(size: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        drawDesktopBackground(size: canvasSize)
        drawStickyShadow(rect: noteRect)
        
        let currentColor = colors[5] // Sky
        let notePath = NSBezierPath(roundedRect: noteRect, xRadius: 16, yRadius: 16)
        currentColor.bg.setFill()
        notePath.fill()
        
        // Header
        let headerH: CGFloat = 40
        let headerRect = NSRect(x: noteRect.minX, y: noteRect.maxY - headerH, width: noteRect.width, height: headerH)
        currentColor.headerBorder.setFill()
        NSRect(x: noteRect.minX, y: headerRect.minY, width: noteRect.width, height: 1).fill()
        
        // Note Title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: currentColor.text
        ]
        NSAttributedString(string: "Design Spec Notes 📐", attributes: titleAttr)
            .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.maxY - 85))
            
        // Initial text
        let promptAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: currentColor.text.withAlphaComponent(0.65)
        ]
        
        // If before paste (f < 5)
        if f < 5 {
            NSAttributedString(string: "Paste or drag an image here...\n(Press ⌘V to trigger native action menu)", attributes: promptAttr)
                .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.maxY - 130))
        }
        
        // Show Image Paste Action Menu between frames 6 and 18
        var menuAlpha: CGFloat = 0.0
        if f >= 6 && f < 9 {
            menuAlpha = CGFloat(f - 5) / 3.0
        } else if f >= 9 && f < 18 {
            menuAlpha = 1.0
        }
        
        if menuAlpha > 0.0 {
            let menuW: CGFloat = 260
            let menuH: CGFloat = 110
            let menuRect = NSRect(x: noteRect.midX - menuW/2, y: noteRect.midY - menuH/2, width: menuW, height: menuH)
            
            NSGraphicsContext.saveGraphicsState()
            let mShadow = NSShadow()
            mShadow.shadowColor = NSColor.black.withAlphaComponent(0.35 * menuAlpha)
            mShadow.shadowOffset = NSSize(width: 0, height: -6)
            mShadow.shadowBlurRadius = 18
            mShadow.set()
            
            let mPath = NSBezierPath(roundedRect: menuRect, xRadius: 10, yRadius: 10)
            NSColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 0.96 * menuAlpha).setFill()
            mPath.fill()
            
            NSColor(white: 1.0, alpha: 0.15 * menuAlpha).setStroke()
            mPath.lineWidth = 1.0
            mPath.stroke()
            
            // Header: "🖼️ Image Detected"
            let hAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor(white: 0.75, alpha: menuAlpha)
            ]
            NSAttributedString(string: "🖼️  Image Detected (Clipboard)", attributes: hAttr)
                .draw(at: NSPoint(x: menuRect.minX + 12, y: menuRect.maxY - 24))
                
            // Separator
            NSColor(white: 1.0, alpha: 0.1 * menuAlpha).setFill()
            NSRect(x: menuRect.minX, y: menuRect.maxY - 32, width: menuRect.width, height: 1).fill()
            
            // Item 1: Paste Image
            let isItem1Hover = (f >= 8 && f < 11)
            let item1Rect = NSRect(x: menuRect.minX + 6, y: menuRect.maxY - 64, width: menuRect.width - 12, height: 26)
            if isItem1Hover {
                NSColor.systemBlue.withAlphaComponent(menuAlpha).setFill()
                NSBezierPath(roundedRect: item1Rect, xRadius: 5, yRadius: 5).fill()
            }
            let item1Attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isItem1Hover ? NSColor.white : NSColor(white: 0.9, alpha: menuAlpha)
            ]
            NSAttributedString(string: "📷  Paste Image", attributes: item1Attr)
                .draw(at: NSPoint(x: item1Rect.minX + 8, y: item1Rect.minY + 5))
                
            // Item 2: Paste Image Text (Vision OCR)
            let isItem2Hover = (f >= 11 && f < 18)
            let item2Rect = NSRect(x: menuRect.minX + 6, y: menuRect.maxY - 96, width: menuRect.width - 12, height: 26)
            if isItem2Hover {
                NSColor.systemBlue.withAlphaComponent(menuAlpha).setFill()
                NSBezierPath(roundedRect: item2Rect, xRadius: 5, yRadius: 5).fill()
            }
            let item2Attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: isItem2Hover ? NSColor.white : NSColor(white: 0.9, alpha: menuAlpha)
            ]
            NSAttributedString(string: "✨  Paste Image Text (Vision OCR)", attributes: item2Attr)
                .draw(at: NSPoint(x: item2Rect.minX + 8, y: item2Rect.minY + 5))
                
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // After OCR Click (f >= 18): Text appears and Attachment Thumbnail strip appears
        if f >= 18 {
            let ocrTitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: currentColor.text
            ]
            NSAttributedString(string: "## Vision OCR Result ⚡", attributes: ocrTitleAttr)
                .draw(at: NSPoint(x: noteRect.minX + 24, y: noteRect.maxY - 130))
                
            let ocrText = "• Architecture: 100% Local-First Offline\n• Privacy: Zero Cloud Telemetry\n• Storage: ~/Library/Application Support/\n• Performance: Native Swift & AppKit"
            let ocrAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
                .foregroundColor: currentColor.text.withAlphaComponent(0.9)
            ]
            ocrText.draw(in: NSRect(x: noteRect.minX + 24, y: noteRect.minY + 160, width: noteRect.width - 48, height: 140), withAttributes: ocrAttr)
            
            // Bottom Attachment Strip
            let stripRect = NSRect(x: noteRect.minX + 16, y: noteRect.minY + 16, width: noteRect.width - 32, height: 50)
            NSColor(white: 0.0, alpha: 0.06).setFill()
            NSBezierPath(roundedRect: stripRect, xRadius: 8, yRadius: 8).fill()
            
            // Thumbnail image preview
            let thumbRect = NSRect(x: stripRect.minX + 8, y: stripRect.minY + 7, width: 36, height: 36)
            NSColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.3).setFill()
            NSBezierPath(roundedRect: thumbRect, xRadius: 4, yRadius: 4).fill()
            
            let thumbIcon = NSAttributedString(string: "🖼️", attributes: [.font: NSFont.systemFont(ofSize: 18)])
            thumbIcon.draw(at: NSPoint(x: thumbRect.minX + 8, y: thumbRect.minY + 7))
            
            let thumbTitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: currentColor.text
            ]
            NSAttributedString(string: "screenshot_specs.png", attributes: thumbTitleAttr)
                .draw(at: NSPoint(x: thumbRect.maxX + 10, y: stripRect.minY + 25))
                
            let thumbSubAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: currentColor.text.withAlphaComponent(0.6)
            ]
            NSAttributedString(string: "144 KB • Click to open in Preview", attributes: thumbSubAttr)
                .draw(at: NSPoint(x: thumbRect.maxX + 10, y: stripRect.minY + 10))
        }
        
        // Animate Cursor
        var cursorPos = NSPoint(x: 80, y: 200)
        var clicking = false
        if f >= 5 && f < 11 {
            cursorPos = NSPoint(x: noteRect.midX + 20, y: noteRect.midY + 15)
        } else if f >= 11 && f < 18 {
            cursorPos = NSPoint(x: noteRect.midX + 40, y: noteRect.midY - 20)
            if f >= 15 { clicking = true }
        } else if f >= 18 && f < 24 {
            cursorPos = NSPoint(x: noteRect.minX + 150, y: noteRect.minY + 40)
            if f >= 21 { clicking = true }
        } else {
            cursorPos = NSPoint(x: 40, y: 100)
        }
        
        drawCursor(at: cursorPos, isClicking: clicking)
        
        NSGraphicsContext.restoreGraphicsState()
        frames.append(rep.cgImage!)
        
        let d: Double = (f == 16) ? 0.4 : ((f == 27) ? 0.8 : 0.11)
        delays.append(d)
    }
    
    exportGIF(frames: frames, delays: delays, to: URL(fileURLWithPath: "docs/screenshots/image_paste_ocr.gif"))
}

// MARK: - 4. GENERATE SPOTLIGHT SEARCH HUD GIF
func generateSpotlightSearchGIF() {
    print("🎨 Generating 4. Spotlight Search GIF...")
    let canvasSize = NSSize(width: 800, height: 550)
    var frames: [CGImage] = []
    var delays: [Double] = []
    
    let totalFrames = 30
    for f in 0..<totalFrames {
        let (rep, ctx) = createCanvas(size: canvasSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        drawDesktopBackground(size: canvasSize)
        
        // Background note partially visible on left
        let bgNoteRect = NSRect(x: 40, y: 60, width: 260, height: 320)
        drawStickyShadow(rect: bgNoteRect, radius: 14)
        colors[1].bg.setFill() // Pink
        NSBezierPath(roundedRect: bgNoteRect, xRadius: 14, yRadius: 14).fill()
        NSAttributedString(string: "Marketing Drafts", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: colors[1].text
        ]).draw(at: NSPoint(x: bgNoteRect.minX + 16, y: bgNoteRect.maxY - 45))
        
        // Active Target note on right
        let targetNoteRect = NSRect(x: 500, y: 80, width: 260, height: 320)
        drawStickyShadow(rect: targetNoteRect, radius: 14)
        colors[0].bg.setFill() // Yellow
        NSBezierPath(roundedRect: targetNoteRect, xRadius: 14, yRadius: 14).fill()
        NSAttributedString(string: "Sprint Goals 🚀", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: colors[0].text
        ]).draw(at: NSPoint(x: targetNoteRect.minX + 16, y: targetNoteRect.maxY - 45))
        
        // If f >= 26: Target note pops forward with glowing focus ring!
        if f >= 26 {
            NSGraphicsContext.saveGraphicsState()
            let ring = NSBezierPath(roundedRect: targetNoteRect.insetBy(dx: -4, dy: -4), xRadius: 18, yRadius: 18)
            NSColor.systemBlue.setStroke()
            ring.lineWidth = 3.5
            ring.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Spotlight Search HUD in center
        // Appears at f >= 3, disappears at f >= 25
        var hudAlpha: CGFloat = 0.0
        if f >= 3 && f < 6 {
            hudAlpha = CGFloat(f - 2) / 3.0
        } else if f >= 6 && f < 25 {
            hudAlpha = 1.0
        } else if f >= 25 && f < 27 {
            hudAlpha = 1.0 - CGFloat(f - 24) / 2.0
        }
        
        if hudAlpha > 0.0 {
            let hudW: CGFloat = 460
            let hudH: CGFloat = 260
            let hudRect = NSRect(x: canvasSize.width/2 - hudW/2, y: canvasSize.height/2 - hudH/2 + 30, width: hudW, height: hudH)
            
            NSGraphicsContext.saveGraphicsState()
            let hShadow = NSShadow()
            hShadow.shadowColor = NSColor.black.withAlphaComponent(0.5 * hudAlpha)
            hShadow.shadowOffset = NSSize(width: 0, height: -10)
            hShadow.shadowBlurRadius = 30
            hShadow.set()
            
            let hPath = NSBezierPath(roundedRect: hudRect, xRadius: 16, yRadius: 16)
            NSColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 0.96 * hudAlpha).setFill()
            hPath.fill()
            
            NSColor(white: 1.0, alpha: 0.18 * hudAlpha).setStroke()
            hPath.lineWidth = 1.2
            hPath.stroke()
            
            // Search Bar
            let searchBarRect = NSRect(x: hudRect.minX + 16, y: hudRect.maxY - 56, width: hudRect.width - 32, height: 38)
            NSColor(white: 1.0, alpha: 0.08 * hudAlpha).setFill()
            NSBezierPath(roundedRect: searchBarRect, xRadius: 10, yRadius: 10).fill()
            
            // Magnifying Glass
            let glassAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor(white: 0.6, alpha: hudAlpha)
            ]
            NSAttributedString(string: "🔍", attributes: glassAttr)
                .draw(at: NSPoint(x: searchBarRect.minX + 10, y: searchBarRect.minY + 9))
                
            // Typed text simulation:
            // f 0-6: ""
            // f 7-9: "S"
            // f 10-12: "Sp"
            // f 13-25: "Sprint"
            var query = ""
            if f >= 7 && f < 10 { query = "S" }
            else if f >= 10 && f < 13 { query = "Sp" }
            else if f >= 13 { query = "Sprint" }
            
            let inputAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(hudAlpha)
            ]
            NSAttributedString(string: query, attributes: inputAttr)
                .draw(at: NSPoint(x: searchBarRect.minX + 38, y: searchBarRect.minY + 10))
                
            // Blinking cursor in search bar
            if f % 4 < 2 && f < 20 {
                let textW = (query as NSString).size(withAttributes: inputAttr).width
                let curBar = NSRect(x: searchBarRect.minX + 39 + textW, y: searchBarRect.minY + 9, width: 2, height: 18)
                NSColor.systemBlue.withAlphaComponent(hudAlpha).setFill()
                curBar.fill()
            }
            
            // Search Results List
            let resultY1 = searchBarRect.minY - 60
            let resultY2 = resultY1 - 54
            
            // Item 1: Sprint Goals (Selected at f >= 17)
            let isItem1Selected = (f >= 17)
            let item1Rect = NSRect(x: hudRect.minX + 16, y: resultY1, width: hudRect.width - 32, height: 48)
            if isItem1Selected {
                NSColor.systemBlue.withAlphaComponent(0.9 * hudAlpha).setFill()
            } else {
                NSColor(white: 1.0, alpha: 0.05 * hudAlpha).setFill()
            }
            NSBezierPath(roundedRect: item1Rect, xRadius: 8, yRadius: 8).fill()
            
            // Item 1 swatch
            NSColor(red: 1.00, green: 0.95, blue: 0.65, alpha: hudAlpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: item1Rect.minX + 12, y: item1Rect.minY + 16, width: 16, height: 16)).fill()
            
            let i1TitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: isItem1Selected ? NSColor.white : NSColor(white: 0.95, alpha: hudAlpha)
            ]
            NSAttributedString(string: "Sprint Goals 🚀", attributes: i1TitleAttr)
                .draw(at: NSPoint(x: item1Rect.minX + 36, y: item1Rect.minY + 24))
                
            let i1SubAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: isItem1Selected ? NSColor(white: 0.9, alpha: hudAlpha) : NSColor(white: 0.55, alpha: hudAlpha)
            ]
            NSAttributedString(string: "3 checklist items • #launch • Updated today", attributes: i1SubAttr)
                .draw(at: NSPoint(x: item1Rect.minX + 36, y: item1Rect.minY + 8))
                
            // Item 2: Sprint Retrospective
            let item2Rect = NSRect(x: hudRect.minX + 16, y: resultY2, width: hudRect.width - 32, height: 48)
            NSColor(white: 1.0, alpha: 0.05 * hudAlpha).setFill()
            NSBezierPath(roundedRect: item2Rect, xRadius: 8, yRadius: 8).fill()
            
            NSColor(red: 0.83, green: 0.96, blue: 0.87, alpha: hudAlpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: item2Rect.minX + 12, y: item2Rect.minY + 16, width: 16, height: 16)).fill()
            
            let i2TitleAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor(white: 0.95, alpha: hudAlpha)
            ]
            NSAttributedString(string: "Sprint Retrospective & Notes", attributes: i2TitleAttr)
                .draw(at: NSPoint(x: item2Rect.minX + 36, y: item2Rect.minY + 24))
                
            let i2SubAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor(white: 0.55, alpha: hudAlpha)
            ]
            NSAttributedString(string: "Linked to Xcode • Updated yesterday", attributes: i2SubAttr)
                .draw(at: NSPoint(x: item2Rect.minX + 36, y: item2Rect.minY + 8))
                
            // Shortcut Hint Bar
            let hintAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor(white: 0.5, alpha: hudAlpha)
            ]
            NSAttributedString(string: "↑↓ Navigate   ↵ Open Note   esc Dismiss", attributes: hintAttr)
                .draw(at: NSPoint(x: hudRect.minX + 20, y: hudRect.minY + 12))
                
            NSGraphicsContext.restoreGraphicsState()
        }
        
        // Cursor
        var cursorPos = NSPoint(x: 200, y: 150)
        var clicking = false
        if f >= 4 && f < 16 {
            cursorPos = NSPoint(x: 440, y: 340)
        } else if f >= 16 && f < 22 {
            cursorPos = NSPoint(x: 480, y: 260)
        } else if f >= 22 && f < 26 {
            cursorPos = NSPoint(x: 480, y: 260)
            clicking = true
        } else if f >= 26 {
            cursorPos = NSPoint(x: targetNoteRect.midX, y: targetNoteRect.midY)
        }
        drawCursor(at: cursorPos, isClicking: clicking)
        
        NSGraphicsContext.restoreGraphicsState()
        frames.append(rep.cgImage!)
        
        let d: Double = (f == 14 || f == 21) ? 0.35 : ((f == 29) ? 0.8 : 0.11)
        delays.append(d)
    }
    
    exportGIF(frames: frames, delays: delays, to: URL(fileURLWithPath: "docs/screenshots/spotlight_search.gif"))
}

// RUN ALL
generateHeaderHoverGIF()
generateMarkdownChecklistGIF()
generateImagePasteOCRGIF()
generateSpotlightSearchGIF()
print("🎉 All 4 showcase GIFs successfully generated!")
