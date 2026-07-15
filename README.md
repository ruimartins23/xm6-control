# XM6 Control

**A native macOS app for the Sony WH-1000XM6** — control noise cancelling, ambient sound, equalizer, listening modes, and multipoint directly from your Mac. No Sony app required, no Electron, no cloud: just Swift, SwiftUI, and a direct Bluetooth connection to your headphones.

> Sony ships its Sound Connect companion app for iOS and Android — but not for macOS. This project fills that gap with a first-class Mac experience: a Liquid Glass interface, a menu bar panel, and a floating desktop widget, all speaking Sony's native headphone protocol over Bluetooth RFCOMM.

---

## Features

| Feature | Status |
|---|---|
| Noise Cancelling / Ambient Sound / Off | ✅ with ambient level slider (0–20) and Focus on Voice |
| Listening Mode (Standard / Background Music / Cinema) | ✅ including BGM room size (My Room / Living Room / Cafe) |
| Equalizer presets (Off, Heavy, Clear, Hard, Soft, Custom) | ✅ XM6-native preset codes |
| Battery level + charging status | ✅ live updates |
| Multipoint device list with names | ✅ shows all connected devices |
| Playback source switching ("Play here") | ✅ one click |
| Speak-to-Chat (sensitivity + resume timing) | ✅ |
| Wearing detection (pause when taken off) | ✅ |
| Automatic power off | ✅ |
| Menu bar quick controls | ✅ full control without opening the app |
| Floating desktop widget | ✅ draggable, all-Spaces, remembers position |
| Runs in background (no Dock icon) | ✅ pure menu-bar app |

The app is **event-driven**: 0% CPU at idle, no polling, negligible battery impact.

## Requirements

- macOS 13+ (Liquid Glass styling on macOS 26+, graceful fallback below)
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode not required
- A Sony WH-1000XM6 paired in **System Settings → Bluetooth**

## Build & Run

```sh
git clone <this-repo>
cd xm6-control
./Scripts/build_app.sh
open ".build/XM6 Control.app"
```

That's it. The script builds with SwiftPM, packages a double-clickable `.app`, generates the app icon, and signs the bundle. Drag `XM6 Control.app` to `/Applications` if you want it permanent, and add it to **System Settings → General → Login Items** to start it at login.

On first launch macOS asks for Bluetooth permission — click **Allow**. Make sure the headphones are powered on and connected as an audio device before hitting **Try Again** if the first connection races.

### Avoiding permission re-prompts across rebuilds

Ad-hoc-signed apps get a new identity every build, so macOS re-asks for Bluetooth each rebuild. To fix this permanently, create a self-signed signing certificate once:

1. **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: `XM6Dev` · Identity Type: *Self-Signed Root* · Certificate Type: **Code Signing**
3. Rebuild — the script detects `XM6Dev` automatically and uses it from then on.

### Custom hero image

The dashboard header shows original vector artwork by default. To display a photo of your own headphones instead, save it as `headphones.png` (real PNG, not WebP) in either:

- `Sources/XM6Control/Resources/` — bundled at next build, or
- `~/Library/Application Support/XM6 Control/` — picked up at next launch, no rebuild.

## Architecture

Two SwiftPM targets, cleanly separated:

```
Sources/
├── SonyHeadphonesKit/          # Protocol + transport library (no UI)
│   ├── Protocol/
│   │   ├── SonyMessage.swift   #   Frame encode/decode, escaping, checksum
│   │   ├── FrameParser.swift   #   Streaming frame reassembly
│   │   ├── Opcodes.swift       #   Command opcode tables (both message tables)
│   │   ├── Commands.swift      #   Payload builders + validating decoders
│   │   └── HeadphonesEvent.swift # Typed events from raw payloads
│   ├── Models/                 #   AmbientSoundState, EqualizerPreset, ...
│   ├── RFCOMMConnection.swift  #   IOBluetooth RFCOMM channel management
│   ├── HeadphonesController.swift # Session orchestration, ACK/sequence, state
│   └── ProtocolLog.swift       #   Optional hex-dump debug log
└── XM6Control/                 # SwiftUI app
    ├── XM6ControlApp.swift     #   Main window + menu bar extra + desktop widget
    └── Views/                  #   Dashboard cards, compact controls, widget
```

### Protocol notes

The XM6 speaks Sony's proprietary MDR protocol over RFCOMM (service UUID `96CC203E-5068-46ad-B32D-E316F5E069BA`): framed messages with an alternating sequence bit, per-frame ACKs, and two independent opcode tables. The XM6 generation moved several features to new command families relative to older 1000X models — the equalizer answers a different inquired type, wearing detection moved to the SYSTEM family, and multipoint management lives on the second message table. All command layouts used here were verified against a live WH-1000XM6 (firmware 3.x) via the built-in protocol log.

Enable **Debug logging** at the bottom of the main window to capture a hex transcript of every frame at `~/Library/Application Support/XM6 Control/protocol.log` — invaluable for adding features or supporting new firmware.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Couldn't find a paired WH-1000XM6" | Pair the headphones in System Settings → Bluetooth first |
| Connect fails immediately | Make sure the headphones show as *Connected* (audio) in the Bluetooth menu, then Try Again |
| Bluetooth permission prompt after rebuild | Expected with ad-hoc signing — see the `XM6Dev` certificate setup above |
| A card shows "state not reported" | That query wasn't answered; controls still work. Enable debug logging and open an issue with the log |
| Menu bar icon missing | The app may not be running — launch it again; it lives only in the menu bar (no Dock icon) |

## Acknowledgements

This project stands on the shoulders of the open-source Sony reverse-engineering community:

- [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) — the most battle-tested implementation of the Sony MDR protocol
- [SonyHeadphonesClient](https://github.com/Plutoberth/SonyHeadphonesClient) and the [mos9527 fork](https://github.com/mos9527/SonyHeadphonesClient) — whose XM6 support documented the new-generation command families

## Disclaimer

This is an independent open-source project. It is not affiliated with, endorsed by, or supported by Sony. "Sony", "WH-1000XM6", and "Sound Connect" are trademarks of Sony Group Corporation. Use at your own risk.

## License

[MIT](LICENSE)
