# ios-avatar -- iOS/iPadOS Voice Agent with Lip-Synced Avatar

A SwiftUI app that boots a voice agent with a real-time, lip-synced Expression avatar on iPhone or iPad. Includes the `HardwareCheck.evaluate()` gate to refuse under-spec devices at launch, and `UIViewRepresentable` hosting for the avatar renderer.

## Prerequisites

- Xcode 26+ (development on Mac)
- Apple Developer account in good standing
- iOS 26+ / iPadOS 26+ target device:
  - iPhone 16 Pro or later (A18 Pro+)
  - iPad Pro M4 or later (16 GB)
- Apple-approved memory entitlements (see below)
- A `BITHUMAN_API_KEY` -- avatar mode is metered at **2 credits per active minute**

### Unsupported devices

The following devices are explicitly refused by `HardwareCheck.evaluate()`:

- iPhone 15 Pro and earlier
- iPhone 16 / 16 Plus (non-Pro A18) -- thermal throttle
- iPad Air M2 / M3 -- thermal throttle
- iPad Pro M1 / M2 -- bandwidth-limited

### Memory entitlements (REQUIRED)

Without these entitlements, iOS will terminate the app mid-conversation when memory exceeds the ~3 GB default ceiling (around 30 seconds into a live turn).

**Request approval BEFORE you start development** -- Apple takes 1-3 business days.

1. Go to developer.apple.com -> Account -> Membership -> Request Additional Capabilities.
2. Request both:
   - `com.apple.developer.kernel.increased-memory-limit`
   - `com.apple.developer.kernel.extended-virtual-addressing`
3. Apple replies via email. The provisioning profile updates automatically once approved.

The entitlements are included in `Sources/Info.plist`.

### Get an API key

1. Sign in at [bithuman.ai](https://www.bithuman.ai) -> Developer -> API Keys.
2. In Xcode: Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables -> add `BITHUMAN_API_KEY`.

Never hardcode the key in source. For production, fetch it from your backend or Keychain.

## Run

1. Open this directory in Xcode (File -> Open -> select the folder containing `Package.swift`).
2. Set the `BITHUMAN_API_KEY` environment variable in the scheme.
3. Select a physical device (iPhone 16 Pro or iPad Pro M4+).
4. Build and run.

This example cannot run in the Simulator -- it requires real Apple Silicon hardware for on-device inference.

## TestFlight checklist

Before submitting to TestFlight:

- [ ] Run on a physical reference device (iPhone 16 Pro or iPad Pro M4+). Confirm the engine sustains 25 FPS during a 60-second conversation.
- [ ] Run on an under-spec device (iPhone 15 Pro or iPad Air). Confirm `UnsupportedDeviceView` appears at launch.
- [ ] Verify both memory entitlements are granted by Apple (provisioning profile updated after approval).
- [ ] Verify mic + speech permissions flow correctly on first `chat.start()`.
- [ ] Memory profile in Instruments -- `phys_footprint` reads large during turns (4-6 GB) but most is compressed MALLOC pool. Watch that iOS "available" memory stays well above zero.
- [ ] App Store compatibility list explicitly states iPhone 16 Pro and later.

## Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest -- targets iOS 26.0, depends on `bitHumanKit` |
| `Sources/main.swift` | SwiftUI `@main` app with hardware gate, `AvatarLifecycle`, `AvatarHost` (UIViewRepresentable), and views |
| `Sources/Info.plist` | Privacy strings (mic, speech recognition) and memory entitlements |

## Docs

- [Swift SDK quickstart](https://docs.bithuman.ai/sdks/swift)
- [iOS / iPadOS guide](https://docs.bithuman.ai/sdks/swift)
