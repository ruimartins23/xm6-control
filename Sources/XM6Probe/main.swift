import Foundation
import SonyHeadphonesKit

// XM6Probe: connect to the paired WH-1000XM6, send raw payloads, print every reply.
//
// Usage: xm6probe "f6 05" "28 05 01 00" "26 05"
//   Each argument is a hex payload, sent ~1.5s apart after the handshake.
//   All inbound messages are printed for ~4s after the last send, then exit.
//   Prefix an argument with "t2:" to send it on the second message table (0x0e).

func parseHex(_ s: String) -> (SonyMessageType, [UInt8])? {
    var body = s
    var type = SonyMessageType.command1
    if body.hasPrefix("t2:") {
        type = .command2
        body = String(body.dropFirst(3))
    }
    let bytes = body.split(separator: " ").compactMap { UInt8($0, radix: 16) }
    guard !bytes.isEmpty else { return nil }
    return (type, bytes)
}

func hexString(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

let payloads = CommandLine.arguments.dropFirst().compactMap(parseHex)
guard !payloads.isEmpty else {
    print("usage: xm6probe \"f6 05\" \"t2:36 02\" ...")
    exit(1)
}

Task { @MainActor in
    let controller = HeadphonesController()
    controller.rawMessageHandler = { type, payload in
        let table = type == .command2 ? "T2" : "T1"
        print("RX[\(table)] \(hexString(payload))")
    }
    controller.autoConnect()

    for _ in 0..<50 { // wait up to 10s for the handshake
        try? await Task.sleep(nanoseconds: 200_000_000)
        if controller.connectionState == .connected { break }
    }
    guard controller.connectionState == .connected else {
        print("ERROR: could not connect (\(controller.connectionState))")
        exit(2)
    }
    print("connected; letting initial state queries drain...")
    try? await Task.sleep(nanoseconds: 3_000_000_000)

    for (type, payload) in payloads {
        let table = type == .command2 ? "T2" : "T1"
        print("TX[\(table)] \(hexString(payload))")
        controller.sendRaw(payload, type: type)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    try? await Task.sleep(nanoseconds: 4_000_000_000)
    controller.disconnect()
    exit(0)
}

dispatchMain()
