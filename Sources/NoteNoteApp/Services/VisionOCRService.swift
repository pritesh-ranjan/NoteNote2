import AppKit
import Vision

public final class VisionOCRService: @unchecked Sendable {
    public static let shared = VisionOCRService()
    
    private init() {}
    
    /// Recognizes text from an NSImage using Apple's Vision framework.
    /// Runs asynchronously on a background queue and invokes completion on the main thread.
    public func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    AppLogger.error("Vision text recognition failed", error: error)
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(fullText.isEmpty ? nil : fullText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                AppLogger.error("Failed to perform VNImageRequestHandler", error: error)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
