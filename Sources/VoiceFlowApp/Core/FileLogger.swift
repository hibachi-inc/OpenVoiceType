import Foundation

enum FileLogger {
    private static let maxSize: UInt64 = 1_024_000 // 1MB
    private static let logURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/OpenVoiceText", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("coordinator.log")
    }()

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let fh = try? FileHandle(forWritingTo: logURL) {
            defer { fh.closeFile() }
            let size = fh.seekToEndOfFile()
            if size > maxSize {
                fh.truncateFile(atOffset: 0)
            }
            fh.write(data)
        } else {
            try? data.write(to: logURL)
        }
    }
}
