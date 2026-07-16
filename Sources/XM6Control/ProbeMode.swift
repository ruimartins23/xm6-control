import Foundation
import AppKit
import SonyHeadphonesKit

/// Hidden developer mode: `open "XM6 Control.app" --args --probe "f6 05" "26 05"`
/// connects, sends each raw hex payload ~1.5s apart, records every inbound message
/// to `~/Library/Application Support/XM6 Control/probe.log`, then quits.
/// Prefix a payload with "t2:" to send it on the second message table (0x0e).
/// Runs inside the app (not a bare CLI) so the Bluetooth privacy grant applies.
@MainActor
enum ProbeMode {
    private(set) static var active = false
    private static var controller: HeadphonesController?

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--probe") else { return }
        active = true

        let payloads: [(SonyMessageType, [UInt8])] = args[(flagIndex + 1)...].compactMap { raw in
            var body = raw
            var type = SonyMessageType.command1
            if body.hasPrefix("t2:") {
                type = .command2
                body = String(body.dropFirst(3))
            }
            let bytes = body.split(separator: " ").compactMap { UInt8($0, radix: 16) }
            return bytes.isEmpty ? nil : (type, bytes)
        }

        let logURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("XM6 Control/probe.log")
        try? "=== probe \(Date()) ===\n".data(using: .utf8)?.write(to: logURL)

        func emit(_ line: String) {
            if let handle = try? FileHandle(forWritingTo: logURL),
               let data = (line + "\n").data(using: .utf8) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }

        func hex(_ bytes: [UInt8]) -> String {
            bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        }

        let probe = HeadphonesController()
        controller = probe
        probe.rawMessageHandler = { type, payload in
            emit("RX[\(type == .command2 ? "T2" : "T1")] \(hex(payload))")
        }

        Task { @MainActor in
            probe.autoConnect()
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if probe.connectionState == .connected { break }
            }
            guard probe.connectionState == .connected else {
                emit("ERROR: could not connect (\(probe.connectionState))")
                exit(2)
            }
            emit("connected; draining initial queries...")
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            for (type, payload) in payloads {
                emit("TX[\(type == .command2 ? "T2" : "T1")] \(hex(payload))")
                probe.sendRaw(payload, type: type)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }

            try? await Task.sleep(nanoseconds: 4_000_000_000)
            emit("done")
            probe.disconnect()
            exit(0)
        }
    }
}
