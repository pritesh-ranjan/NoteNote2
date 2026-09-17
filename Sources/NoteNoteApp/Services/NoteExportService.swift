import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public final class NoteExportService {
    public static let shared = NoteExportService()
    
    private init() {}
    
    private func sanitizedFileName(for note: NoteModel) -> String {
        let title = note.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return clean.isEmpty ? "Untitled Note" : clean
    }
    
    // MARK: - Export to PDF
    public func exportToPDF(note: NoteModel, window: NSWindow? = nil) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as PDF"
        savePanel.nameFieldStringValue = "\(sanitizedFileName(for: note)).pdf"
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let targetURL = savePanel.url else { return }
            self?.generatePDFFile(for: note, to: targetURL)
        }
        
        if let window = window {
            savePanel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            savePanel.begin(completionHandler: completion)
        }
    }
    
    private func generatePDFFile(for note: NoteModel, to url: URL) {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - (margin * 2)
        
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            AppLogger.error("Failed to create PDF context for note '\(note.displayTitle)'")
            return
        }
        
        context.beginPage(mediaBox: &pageRect)
        
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        var currentY: CGFloat = pageHeight - margin
        
        // 1. Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let titleString = NSAttributedString(string: note.displayTitle, attributes: titleAttrs)
        let titleRect = titleString.boundingRect(with: CGSize(width: contentWidth, height: 100), options: .usesLineFragmentOrigin)
        currentY -= titleRect.height
        titleString.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: titleRect.height))
        currentY -= 6
        
        // 2. Date
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let dateString = NSAttributedString(
            string: "Created: \(note.createdAt.formatted(date: .long, time: .shortened))",
            attributes: dateAttrs
        )
        currentY -= 14
        dateString.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 14))
        currentY -= 10
        
        // 3. Separator line
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: currentY))
        context.strokePath()
        currentY -= 16
        
        // 4. Attached Images (Thumbnails)
        if !note.imageAttachments.isEmpty {
            let thumbSize: CGFloat = 64
            let spacing: CGFloat = 8
            var currentX = margin
            
            for filename in note.imageAttachments {
                let imgURL = NotesStore.shared.attachmentURL(for: note.id, filename: filename)
                if let img = NSImage(contentsOf: imgURL) {
                    let imgRect = CGRect(x: currentX, y: currentY - thumbSize, width: thumbSize, height: thumbSize)
                    img.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    
                    // Subtle border around image
                    context.setStrokeColor(NSColor.black.withAlphaComponent(0.15).cgColor)
                    context.setLineWidth(0.8)
                    context.stroke(imgRect)
                    
                    currentX += thumbSize + spacing
                    if currentX + thumbSize > pageWidth - margin {
                        break
                    }
                }
            }
            currentY -= (thumbSize + 16)
        }
        
        // 5. Note Content
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 4.0
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paraStyle
        ]
        let bodyString = NSAttributedString(string: note.content.isEmpty ? "No content" : note.content, attributes: bodyAttrs)
        let bodyHeight = max(20, currentY - margin - 30)
        let bodyRect = CGRect(x: margin, y: margin + 24, width: contentWidth, height: bodyHeight)
        bodyString.draw(in: bodyRect)
        
        // 6. Footer
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let footer = NSAttributedString(string: "NoteNote for Mac", attributes: footerAttrs)
        footer.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: 14))
        
        NSGraphicsContext.restoreGraphicsState()
        
        context.endPage()
        context.closePDF()
        
        AppLogger.info("Exported note '\(note.displayTitle)' to PDF at \(url.path)")
    }
    
    // MARK: - Export to Markdown
    public func exportToMarkdown(note: NoteModel, window: NSWindow? = nil) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Markdown"
        savePanel.nameFieldStringValue = "\(sanitizedFileName(for: note)).md"
        if let mdType = UTType(filenameExtension: "md") {
            savePanel.allowedContentTypes = [mdType, .plainText]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }
        savePanel.canCreateDirectories = true
        
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let targetURL = savePanel.url else { return }
            let markdownContent = """
            # \(note.displayTitle)
            
            \(note.content)
            
            ---
            *Exported from NoteNote on \(Date().formatted())*
            """
            
            do {
                try markdownContent.write(to: targetURL, atomically: true, encoding: .utf8)
                AppLogger.info("Exported note '\(note.displayTitle)' to Markdown at \(targetURL.path)")
            } catch {
                AppLogger.error("Failed to write Markdown export", error: error)
            }
        }
        
        if let window = window {
            savePanel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            savePanel.begin(completionHandler: completion)
        }
    }
    
    // MARK: - Export to Plain Text
    public func exportToPlainText(note: NoteModel, window: NSWindow? = nil) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Note as Plain Text"
        savePanel.nameFieldStringValue = "\(sanitizedFileName(for: note)).txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let targetURL = savePanel.url else { return }
            let textContent = "\(note.displayTitle)\n\n\(note.content)"
            
            do {
                try textContent.write(to: targetURL, atomically: true, encoding: .utf8)
                AppLogger.info("Exported note '\(note.displayTitle)' to Plain Text at \(targetURL.path)")
            } catch {
                AppLogger.error("Failed to write Plain Text export", error: error)
            }
        }
        
        if let window = window {
            savePanel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            savePanel.begin(completionHandler: completion)
        }
    }
}
