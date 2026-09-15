import Foundation

public final class AppLogger {
    public static let shared = AppLogger()
    
    private let queue = DispatchQueue(label: "com.notenote.logger", qos: .utility)
    private var fileHandles: [FileHandle] = []
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()
    
    private init() {
        setupLogFiles()
    }
    
    private func setupLogFiles() {
        var targets: [URL] = []
        
        // 1. App Support Directory: ~/Library/Application Support/NoteNote/notenote.log
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appendingPathComponent("NoteNote", isDirectory: true)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            targets.append(appDir.appendingPathComponent("notenote.log"))
        }
        
        // 2. Project Root Directory: /Users/priteshranjan/Documents/StickyNotesMac/notenote.log
        let projectRoot = URL(fileURLWithPath: "/Users/priteshranjan/Documents/StickyNotesMac")
        if FileManager.default.fileExists(atPath: projectRoot.path) {
            targets.append(projectRoot.appendingPathComponent("notenote.log"))
        }
        
        for url in targets {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                fileHandles.append(handle)
            }
        }
    }
    
    public func log(_ message: String, level: String = "INFO", file: String = #file, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let formatted = "[\(timestamp)] [\(level)] [\(filename):\(line)] \(message)\n"
        
        // Also print to standard output
        print(formatted, terminator: "")
        
        queue.async { [weak self] in
            guard let self = self, let data = formatted.data(using: .utf8) else { return }
            for handle in self.fileHandles {
                handle.write(data)
            }
        }
    }
    
    public static func info(_ message: String, file: String = #file, line: Int = #line) {
        shared.log(message, level: "INFO", file: file, line: line)
    }
    
    public static func debug(_ message: String, file: String = #file, line: Int = #line) {
        shared.log(message, level: "DEBUG", file: file, line: line)
    }
    
    public static func warning(_ message: String, file: String = #file, line: Int = #line) {
        shared.log(message, level: "WARN", file: file, line: line)
    }
    
    public static func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line) {
        let fullMessage = error != nil ? "\(message) - Error: \(error!.localizedDescription)" : message
        shared.log(fullMessage, level: "ERROR", file: file, line: line)
    }
}
