import Foundation

/// Reassembles `SonyMessage` frames from a byte stream that may arrive fragmented
/// across multiple RFCOMM reads.
///
/// Safe to scan for a literal, unescaped `trailer` byte: the encoder always escapes
/// any occurrence of header/trailer/escape-marker bytes inside the frame body, and the
/// escaped replacement values (0x2e/0x2c/0x2d) can never collide with the real
/// delimiters, so the first unescaped trailer byte found after a header always ends
/// that frame.
public final class FrameParser {
    private var buffer: [UInt8] = []

    /// Ceiling on the reassembly buffer. A header byte with no trailer ever following
    /// (a truncated or corrupt stream) would otherwise make the buffer grow for the
    /// lifetime of the connection, since an incomplete frame is deliberately kept for
    /// the next read. Real frames are a handful of bytes; the largest observed is the
    /// multipoint device list at well under 1 KB.
    private static let maxBufferedBytes = 8192

    public init() {}

    public func reset() {
        buffer.removeAll()
    }

    public func feed(_ data: [UInt8]) -> [SonyMessage] {
        buffer.append(contentsOf: data)
        var messages: [SonyMessage] = []

        while true {
            guard let startIndex = buffer.firstIndex(of: SonyMessage.header) else {
                buffer.removeAll()
                break
            }
            if startIndex > 0 {
                buffer.removeFirst(startIndex)
            }
            guard buffer.count > 1 else { break }

            var trailerIndex: Int?
            for i in 1..<buffer.count where buffer[i] == SonyMessage.trailer {
                trailerIndex = i
                break
            }
            guard let end = trailerIndex else {
                // Incomplete frame: keep it for the next read, unless it has grown
                // past anything this protocol can legitimately produce, in which case
                // the stream is desynchronised and holding the bytes helps nothing.
                if buffer.count > Self.maxBufferedBytes {
                    buffer.removeAll()
                }
                break
            }

            let frame = Array(buffer[0...end])
            if let message = SonyMessage.decode(rawFrame: frame) {
                messages.append(message)
            }
            buffer.removeFirst(end + 1)
        }

        return messages
    }
}
