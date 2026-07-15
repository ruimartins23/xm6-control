import Foundation

/// Appends a hex dump of every frame sent/received to
/// `~/Library/Application Support/XM6 Control/protocol.log`, so protocol issues on
/// real hardware (features the reference implementations never verified on XM6) can
/// be diagnosed from a session transcript instead of guesswork.
final class ProtocolLog {
    /// When false (the default), nothing is written -- zero disk I/O in steady state.
    var isEnabled = false

    private let url: URL?
    private let formatter: DateFormatter

    init() {
        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let dir = base?.appendingPathComponent("XM6 Control", isDirectory: true) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("protocol.log")
        } else {
            url = nil
        }
    }

    func startSession(deviceName: String?) {
        guard isEnabled, let url else { return }
        // Rotate only when the log gets big; never truncate on reconnect, otherwise
        // an auto-reconnect wipes the evidence the log exists to preserve.
        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
           size > 2_000_000 {
            try? FileManager.default.removeItem(at: url)
        }
        appendLine("=== session \(Date()) device=\(deviceName ?? "?") ===\n")
    }

    func log(_ direction: String, _ bytes: [UInt8], note: String = "") {
        guard isEnabled else { return }
        let hex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        appendLine("\(formatter.string(from: Date())) \(direction) \(hex)\(note.isEmpty ? "" : "  // \(note)")\n")
    }

    private func appendLine(_ line: String) {
        guard let url, let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}
