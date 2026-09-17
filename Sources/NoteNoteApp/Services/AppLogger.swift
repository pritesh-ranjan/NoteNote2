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
        // Standard macOS App Support: ~/Library/Application Support/NoteNote/notenote.log
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let appDir = appSupport.appendingPathComponent("NoteNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let logFileURL = appDir.appendingPathComponent("notenote.log")
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            fileHandles.append(handle)
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
