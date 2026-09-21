import Foundation
import IOBluetooth

public enum RFCOMMConnectionEvent: Sendable {
    case opened
    case closed
    case dataReceived([UInt8])
    case failed(String)
}

protocol HeadphonesConnection: AnyObject {
    var onEvent: ((RFCOMMConnectionEvent) -> Void)? { get set }
    func connect(toDeviceAddress address: String)
    func disconnect()
    func write(_ bytes: [UInt8])
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
public final class RFCOMMConnection: NSObject, HeadphonesConnection {
    public static let serviceUUIDv1 = "96CC203E-5068-46AD-B32D-E316F5E069BA"
    public static let serviceUUIDv2 = "956C7B26-D49A-4BA8-B03F-B17D393CB6E2"

    public var onEvent: ((RFCOMMConnectionEvent) -> Void)?

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    /// Guards the one-shot retry when a channel open fails outright.
    private var didRetryChannelOpen = false
    private var attemptID = UUID()

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
        // Prefer the registry's own object for this address: it carries the paired-device
        // state, where a freshly constructed one starts blank.
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice],
           let match = paired.first(where: { $0.addressString?.caseInsensitiveCompare(address) == .orderedSame }) {
            return match
        }
        return IOBluetoothDevice(addressString: address)
    }

    // MARK: - Connect

    public func connect(toDeviceAddress address: String) {
        let open = { [self] in
            attemptID = UUID()
            guard let device = Self.device(forAddress: address) else {
                onEvent?(.failed("Could not resolve Bluetooth address \(address)"))
                return
            }
            self.device = device
            self.didRetryChannelOpen = false

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
        if Thread.isMainThread {
            open()
        } else {
            DispatchQueue.main.async(execute: open)
        }
    }

    public func disconnect() {
        let close = { [self] in
            attemptID = UUID()
            // Detach before closing: `close()` is asynchronous, and a channel still tearing
            // down would otherwise fire `rfcommChannelClosed` after the next connect has
            // begun, knocking the fresh session straight back to "disconnected".
            channel?.setDelegate(nil)
            _ = channel?.close()
            channel = nil
            device = nil
        }
        // Termination must close the channel before the main run loop stops.
        if Thread.isMainThread {
            close()
        } else {
            DispatchQueue.main.sync(execute: close)
        }
    }

    public func write(_ bytes: [UInt8]) {
        let write = { [self] in
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
        if Thread.isMainThread {
            write()
        } else {
            DispatchQueue.main.async(execute: write)
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

        // Deliberately the unfiltered query: the `uuids:` overload reports success and
        // then never calls `sdpQueryComplete`, so a connection that has to fall back to
        // live discovery hangs forever instead of failing.
        let result = device.performSDPQuery(self)
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
            // The headset serves one control channel at a time; just after a reconnect the
            // previous one can still be tearing down. Worth one more try before giving up.
            guard !didRetryChannelOpen else {
                onEvent?(.failed(Self.channelOpenError(openStatus)))
                return
            }
            didRetryChannelOpen = true
            let attempt = attemptID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.attemptID == attempt, self.device === device else { return }
                self.openChannel(device: device, record: record)
            }
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

    static func channelOpenError(_ status: IOReturn) -> String {
        "Couldn't open the headphone controls (code \(status)). Another device may be using the headphones. Close Sony Sound Connect on your phone, then try again."
    }
}

// MARK: - IOBluetoothDevice async callbacks (informal delegate, matched by selector)

extension RFCOMMConnection {
    @objc func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        // Callbacks for a device we've moved on from belong to an abandoned attempt.
        guard let device, device === self.device else { return }
        guard status == kIOReturnSuccess else {
            onEvent?(.failed("Failed to connect to headphones (code \(status))"))
            return
        }
        beginServiceDiscovery(on: device)
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard let device, device === self.device else { return }
        guard status == kIOReturnSuccess else {
            onEvent?(.failed("Service discovery failed (code \(status)). Make sure the headphones are connected as an audio device first."))
            return
        }
        if let record = serviceRecord(on: device, uuidString: Self.serviceUUIDv2)
            ?? serviceRecord(on: device, uuidString: Self.serviceUUIDv1) {
            openChannel(device: device, record: record)
        } else if (device.services as? [IOBluetoothSDPServiceRecord])?.isEmpty ?? true {
            // Discovery "succeeded" but returned no services at all -- not even the audio
            // profiles the headset is demonstrably using. That is what a missing Bluetooth
            // privilege looks like from in here: the calls are accepted and quietly dropped.
            onEvent?(.failed("macOS reported no Bluetooth services for these headphones. Check that XM6 Control is enabled under System Settings \u{2192} Privacy & Security \u{2192} Bluetooth."))
        } else {
            onEvent?(.failed("Couldn't find the Sony control service on this device."))
        }
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate

extension RFCOMMConnection: IOBluetoothRFCOMMChannelDelegate {
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard rfcommChannel === channel else { return } // stale channel from an old attempt
        guard error == kIOReturnSuccess else {
            onEvent?(.failed(Self.channelOpenError(error)))
            return
        }
        // Opening the ACL/RFCOMM link too fast after pairing/wake can cause the very
        // first write to be silently dropped by the headset; give it a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, rfcommChannel === self.channel else { return }
            self.onEvent?(.opened)
        }
    }

    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer, rfcommChannel === channel else { return }
        let bytes = Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        onEvent?(.dataReceived(bytes))
    }

    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        guard rfcommChannel === channel else { return } // stale channel from an old attempt
        channel = nil
        onEvent?(.closed)
    }
}
