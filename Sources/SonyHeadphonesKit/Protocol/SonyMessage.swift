import Foundation

/// The outer frame type byte of a Sony MDR-protocol message.
///
/// Verified against Gadgetbridge's `MessageType.java` (the only actively-maintained,
/// hardware-tested open-source implementation of this protocol).
public enum SonyMessageType: UInt8, Equatable, Sendable {
    case ack = 0x01
    case command1 = 0x0c
    case command2 = 0x0e

    public init?(code: UInt8) {
        self.init(rawValue: code)
    }
}

/// A single framed message in Sony's proprietary RFCOMM control protocol used by the
/// "Sony | Sound Connect" / "Sony | Headphones Connect" companion apps.
///
/// Wire format (all multi-byte integers big-endian):
/// `HEADER(0x3e) [TYPE SEQ LEN(4) PAYLOAD(N) CHECKSUM]-escaped TRAILER(0x3c)`
///
/// Byte-for-byte verified against Gadgetbridge's `Message.java`, which is the only
/// implementation of this protocol that is actively tested against real hardware.
public struct SonyMessage: Equatable, Sendable {
    public static let header: UInt8 = 0x3e
    public static let trailer: UInt8 = 0x3c
    public static let escapeMarker: UInt8 = 0x3d
    /// Escaped bytes are ANDed with this mask (clears bit 4), and restored by ORing with its complement.
    public static let escapeMask: UInt8 = 0b1110_1111

    public let type: SonyMessageType
    public let sequenceNumber: UInt8
    public let payload: [UInt8]

    public init(type: SonyMessageType, sequenceNumber: UInt8, payload: [UInt8]) {
        self.type = type
        self.sequenceNumber = sequenceNumber
        self.payload = payload
    }

    /// Encodes this message to the raw bytes ready to write to the RFCOMM channel.
    public func encode() -> [UInt8] {
        var body: [UInt8] = [type.rawValue, sequenceNumber]
        let length = UInt32(payload.count)
        body.append(UInt8((length >> 24) & 0xff))
        body.append(UInt8((length >> 16) & 0xff))
        body.append(UInt8((length >> 8) & 0xff))
        body.append(UInt8(length & 0xff))
        body.append(contentsOf: payload)

        let checksum = Self.checksum(body)

        var framed: [UInt8] = [Self.header]
        framed.append(contentsOf: Self.escape(body))
        framed.append(contentsOf: Self.escape([checksum]))
        framed.append(Self.trailer)
        return framed
    }

    /// Decodes a complete raw frame, `rawFrame[0] == header` and `rawFrame.last == trailer`.
    /// Returns `nil` if the frame is malformed or fails its checksum.
    public static func decode(rawFrame: [UInt8]) -> SonyMessage? {
        guard rawFrame.count >= 2, rawFrame.first == header, rawFrame.last == trailer else {
            return nil
        }

        let unescaped = unescape(rawFrame)
        // header(1) + type(1) + seq(1) + length(4) + checksum(1) + trailer(1) = 9 bytes minimum
        guard unescaped.count >= 9 else { return nil }

        let checksumByte = unescaped[unescaped.count - 2]
        let expectedChecksum = checksum(Array(unescaped[1..<(unescaped.count - 2)]))
        guard checksumByte == expectedChecksum else { return nil }

        guard let type = SonyMessageType(code: unescaped[1]) else { return nil }
        let sequenceNumber = unescaped[2]

        let length = (UInt32(unescaped[3]) << 24)
            | (UInt32(unescaped[4]) << 16)
            | (UInt32(unescaped[5]) << 8)
            | UInt32(unescaped[6])

        guard Int(length) == unescaped.count - 9 else { return nil }

        let payload = Array(unescaped[7..<(7 + Int(length))])
        return SonyMessage(type: type, sequenceNumber: sequenceNumber, payload: payload)
    }

    static func escape(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        for b in bytes {
            if b == header || b == trailer || b == escapeMarker {
                out.append(escapeMarker)
                out.append(b & escapeMask)
            } else {
                out.append(b)
            }
        }
        return out
    }

    static func unescape(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if bytes[i] == escapeMarker {
                i += 1
                guard i < bytes.count else { break }
                out.append(bytes[i] | ~escapeMask)
            } else {
                out.append(bytes[i])
            }
            i += 1
        }
        return out
    }

    static func checksum(_ bytes: [UInt8]) -> UInt8 {
        var sum: UInt32 = 0
        for b in bytes { sum &+= UInt32(b) }
        return UInt8(sum & 0xff)
    }
}
