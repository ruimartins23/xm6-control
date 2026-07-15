import Foundation
import IOBluetooth

public enum RFCOMMConnectionEvent: Sendable {
    case opened
    case closed
    case dataReceived([UInt8])
    case failed(String)
}

/// A short description of a paired classic-Bluetooth device, for UI display / manual
/// device selection. Deliberately doesn't carry the `IOBluetoothDevice` itself so it can
/// cross to SwiftUI without any Objective-C bridging concerns.
public struct PairedDeviceInfo: Identifiable, Equatable, Sendable {
    public let id: String // Bluetooth address string
    public let name: String
}

/// Opens and manages a classic-Bluetooth RFCOMM channel to a paired Sony headset,
/// using the same UUID-based SDP discovery Gadgetbridge uses (see `SonyHeadphonesSupport.java`):
/// look up the vendor service UUID on the already-paired device, read back the RFCOMM
/// channel ID from the SDP record, then open that channel directly. There is no fixed
/// channel number -- it's assigned by the headset and must be discovered per-connection.
public final class RFCOMMConnection: NSObject {
    public static let serviceUUIDv1 = "96CC203E-5068-46AD-B32D-E316F5E069BA"
    public static let serviceUUIDv2 = "956C7B26-D49A-4BA8-B03F-B17D393CB6E2"

    public var onEvent: ((RFCOMMConnectionEvent) -> Void)?

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var didOpen = false

    public override init() {
        super.init()
    }

    // MARK: - Discovery

    public static func pairedDevices() -> [PairedDeviceInfo] {
        guard let raw = IOBluetoothDevice.pairedDevices() else { return [] }
        return raw.compactMap { obj in
            guard let device = obj as? IOBluetoothDevice, let address = device.addressString else { return nil }
            let name = device.name ?? device.nameOrAddress ?? address
            return PairedDeviceInfo(id: address, name: name)
        }
    }

    public static func findLikelyXM6() -> PairedDeviceInfo? {
        pairedDevices().first { $0.name.localizedCaseInsensitiveContains("WH-1000XM6") }
    }

    private static func device(forAddress address: String) -> IOBluetoothDevice? {
        IOBluetoothDevice(addressString: address)
    }

    // MARK: - Connect

    public func connect(toDeviceAddress address: String) {
        DispatchQueue.main.async { [self] in
            guard let device = Self.device(forAddress: address) else {
                onEvent?(.failed("Could not resolve Bluetooth address \(address)"))
                return
            }
            self.device = device
            self.didOpen = false

            if device.isConnected() {
                beginServiceDiscovery(on: device)
            } else {
                let result = device.openConnection(self)
                if result != kIOReturnSuccess {
                    onEvent?(.failed("Failed to open Bluetooth connection (code \(result))"))
                }
                // else: wait for connectionComplete(_:status:) delegate callback
            }
        }
    }

    public func disconnect() {
        DispatchQueue.main.async { [self] in
            _ = channel?.close()
            channel = nil
            device = nil
        }
    }

    public func write(_ bytes: [UInt8]) {
        DispatchQueue.main.async { [self] in
            guard let channel else {
                onEvent?(.failed("Tried to write with no open channel"))
                return
            }
            var mutableBytes = bytes
            let result = mutableBytes.withUnsafeMutableBytes { rawBuffer -> IOReturn in
                guard let base = rawBuffer.baseAddress else { return kIOReturnBadArgument }
                return channel.writeSync(base, length: UInt16(rawBuffer.count))
            }
            if result != kIOReturnSuccess {
                onEvent?(.failed("Write failed (code \(result))"))
            }
        }
    }

    // MARK: - Service discovery

    private func beginServiceDiscovery(on device: IOBluetoothDevice) {
        // Prefer a cached SDP record from prior pairing (fast path); fall back to a
        // live SDP query if the vendor service hasn't been cached yet.
        if let record = serviceRecord(on: device, uuidString: Self.serviceUUIDv2)
            ?? serviceRecord(on: device, uuidString: Self.serviceUUIDv1) {
            openChannel(device: device, record: record)
            return
        }

        guard let v1 = Self.sdpUUID(Self.serviceUUIDv1), let v2 = Self.sdpUUID(Self.serviceUUIDv2) else {
            onEvent?(.failed("Internal error constructing service UUIDs"))
            return
        }
        let result = device.performSDPQuery(self, uuids: [v1, v2])
        if result != kIOReturnSuccess {
            onEvent?(.failed("SDP query failed to start (code \(result))"))
        }
    }

    private func serviceRecord(on device: IOBluetoothDevice, uuidString: String) -> IOBluetoothSDPServiceRecord? {
        guard let uuid = Self.sdpUUID(uuidString) else { return nil }
        return device.getServiceRecord(for: uuid)
    }

    private func openChannel(device: IOBluetoothDevice, record: IOBluetoothSDPServiceRecord) {
        var channelID: BluetoothRFCOMMChannelID = 0
        let status = record.getRFCOMMChannelID(&channelID)
        guard status == kIOReturnSuccess else {
            onEvent?(.failed("Sony control service not found. Make sure the headphones are connected as an audio device first, then try again."))
            return
        }

        var newChannel: IOBluetoothRFCOMMChannel?
        let openStatus = device.openRFCOMMChannelAsync(&newChannel, withChannelID: channelID, delegate: self)
        if openStatus != kIOReturnSuccess {
            onEvent?(.failed("Failed to open RFCOMM channel (code \(openStatus))"))
            return
        }
        self.channel = newChannel
    }

    private static func sdpUUID(_ uuidString: String) -> IOBluetoothSDPUUID? {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        var bytes = uuid.uuid
        return withUnsafeBytes(of: &bytes) { raw in
            IOBluetoothSDPUUID(bytes: raw.baseAddress, length: raw.count)
        }
    }
}

// MARK: - IOBluetoothDevice async callbacks (informal delegate, matched by selector)

extension RFCOMMConnection {
    @objc func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard status == kIOReturnSuccess, let device else {
            onEvent?(.failed("Failed to connect to headphones (code \(status))"))
            return
        }
        beginServiceDiscovery(on: device)
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard status == kIOReturnSuccess, let device else {
            onEvent?(.failed("Service discovery failed (code \(status)). Make sure the headphones are connected as an audio device first."))
            return
        }
        if let record = serviceRecord(on: device, uuidString: Self.serviceUUIDv2)
            ?? serviceRecord(on: device, uuidString: Self.serviceUUIDv1) {
            openChannel(device: device, record: record)
        } else {
            onEvent?(.failed("Couldn't find the Sony control service on this device."))
        }
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate

extension RFCOMMConnection: IOBluetoothRFCOMMChannelDelegate {
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard error == kIOReturnSuccess else {
            onEvent?(.failed("RFCOMM channel failed to open (code \(error))"))
            return
        }
        didOpen = true
        // Opening the ACL/RFCOMM link too fast after pairing/wake can cause the very
        // first write to be silently dropped by the headset; give it a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onEvent?(.opened)
        }
    }

    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer else { return }
        let bytes = Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        onEvent?(.dataReceived(bytes))
    }

    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        channel = nil
        onEvent?(.closed)
    }
}
