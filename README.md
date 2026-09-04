# StarPlay for iPhone

StarPlay is the iOS side of a local screen-mirroring system. On iOS 27 it uses Apple's ScreenCaptureKit system content-sharing flow to capture the complete iPhone display; on earlier supported systems it uses the system ReplayKit broadcast flow. Both paths encode video with VideoToolbox, advertise the phone over Bonjour, and send a low-latency H.264 stream to a future Windows receiver.

This repository intentionally contains no Windows executable, Windows receiver, OBS plugin, installer, or Windows protocol implementation.

## What is included

- A SwiftUI iPhone application with a commercial-style dark interface.
- A first-launch permission explanation and a status-driven home screen.
- A system `RPSystemBroadcastPickerView` configured for this app's Broadcast Upload Extension.
- A Broadcast Upload Extension that receives ReplayKit screen sample buffers.
- Hardware H.264 encoding with keyframes, bounded TCP back pressure, and frame skipping when the receiver cannot keep up.
- Bonjour service advertisement using `_starplay._tcp`.
- Optional host-app discovery of a future Windows receiver using `_starplay-receiver._tcp`.
- Shared App Group state for showing extension status in the host app.
- Orientation metadata and orientation-change messages.
- The exact receiver-facing wire format described below.
- App icon artwork in `StarPlay/Resources/Assets.xcassets`.
- `bitrise.yml` matching the requested unsigned IPA workflow.

## Apple architecture

The project follows the newest Apple path when it is available and retains a real compatibility path for the requested Bitrise stack:

- On iOS 27 and an SDK that includes the new ScreenCaptureKit iOS APIs, the app presents Apple's `SCContentSharingPicker` with no active selection. The iOS system picker supplies the full-display `SCContentFilter`, which feeds an `SCStream` in the app process. `VideoStreamSession` owns the local Bonjour listener and video pipeline, and the system `screen-capture` background mode lets the stream continue while the app is not frontmost.
- On iOS 17 through iOS 26, or when building with the supplied Xcode 26.5 stack before the iOS 27 SDK is present, the app uses `RPSystemBroadcastPickerView` and the Broadcast Upload Extension. ReplayKit launches `SampleHandler` in a separate process and provides full-device `CMSampleBuffer` values after the user confirms the system broadcast.

A normal iOS application cannot read the complete device screen through the old in-process `RPScreenRecorder` capture API; that API is for in-app capture. The modern iOS 27 replacement is ScreenCaptureKit's system content-sharing picker and `SCStream`. The fallback Broadcast Upload Extension is kept so the exact requested Bitrise 26.5 archive remains buildable and useful on earlier iOS versions.

Both paths call the same `VideoStreamSession`. The network listener, H.264 encoder, wire protocol, orientation handling, and bounded back-pressure logic are not duplicated. In the modern path they run in the host app. In the fallback path they run in the extension, while the host app observes status through the App Group state store and uses a Darwin notification to request a clean stop. This avoids sharing a live socket across processes.

The sender pipeline is:

1. Start a TCP `NWListener`.
2. Advertise the listener as `_starplay._tcp` with TXT metadata.
3. Accept one Windows receiver connection at a time.
4. Validate the receiver hello message.
5. Resize only when necessary with `VTPixelTransferSession`.
6. Encode NV12 frames using a hardware-backed H.264 `VTCompressionSession`.
7. Convert VideoToolbox's AVCC NAL units to Annex-B NAL units.
8. Send a stream header, codec configuration, orientation events, and video frames.
9. Keep at most one unsent frame so network congestion does not create a growing latency queue. A dropped pending frame requests a new keyframe.

No video is uploaded to a cloud service. The version 1 protocol is local TCP only and does not enable microphone or application audio transmission. The audio sample branches are intentionally observed and recorded in shared status so a later AAC or Opus track can be added without changing the video framing. `StreamHello.audioAvailable` is false and the audio transport is marked `reserved`.

## Permissions and Apple restrictions

The host app declares `NSLocalNetworkUsageDescription` and the Bonjour service types it uses. The first Bonjour browse or local connection causes iOS to show the Local Network permission prompt. If access is denied, the Settings action in the app opens the app's settings page.

Screen capture consent is system controlled. On iOS 27, the app presents `SCContentSharingPicker`, requests the declared screen-capture purpose, and starts `SCStream` only after the user chooses the display. On earlier systems, the user taps Start mirroring and accepts the ReplayKit system broadcast confirmation. StarPlay does not bypass consent, call private APIs, or attempt to capture the screen with an unsupported API. The app cannot programmatically start a full-device broadcast. The Stop mirroring action stops an iOS 27 `SCStream` directly or requests the compatibility extension to call Apple's `finishBroadcastWithError`; Control Center remains the system fallback for the legacy path.

The host declares the iOS 27 `screen-capture` background mode for the modern ScreenCaptureKit stream. The compatibility path is launched and managed by ReplayKit for the active broadcast. The user must stop broadcasting when it is no longer needed. iOS may terminate a stream or extension for resource pressure or a network failure; StarPlay reports a failed or disconnected state and the user can start again.

StarPlay does not request camera or microphone access in this phase. The picker hides microphone capture, and this release only publishes video. If microphone or application audio is enabled in a later release, add the appropriate privacy description and an explicit user control before sending audio.

Apple's current iOS 27 documentation recommends ScreenCaptureKit's `SCContentSharingPicker` and `SCStream` for screen streaming and requires `NSScreenCaptureUsageDescription`. Because the requested Bitrise stack is Xcode 26.5, the project also contains a conditional ReplayKit Broadcast Upload Extension fallback for iOS 17 through iOS 26. The two paths share the same sender pipeline, and the project targets iOS 17.0 or later. The legacy path uses the current system broadcast picker rather than the older activity-controller flow.

## Project layout

```text
StarPlay/
  App/                         SwiftUI app and presentation state
  Shared/                      App Group models, wire protocol, encoder, scaler, sender
  BroadcastExtension/          ReplayKit compatibility handler
  Resources/Assets.xcassets/   App icon and launch color
  Info.plist                   Host privacy and orientation declarations
  StarPlay.entitlements        Host App Group entitlement
StarPlay.xcodeproj/             App and Broadcast Upload Extension targets
bitrise.yml                     Unsigned archive workflow
```

The Xcode project and scheme are intentionally named `StarPlay` to match the requested Bitrise environment. The visible application name is `StarPlay`.

## Build locally

1. Open `StarPlay.xcodeproj` in Xcode 26 or newer. Xcode 27 or newer is required to compile and run the iOS 27 ScreenCaptureKit path; Xcode 26.5 builds the compatibility path supplied for this repository.
2. Select the `StarPlay` scheme and an iPhone device. ScreenCaptureKit and ReplayKit system capture are not functional in the iOS Simulator.
3. In Signing & Capabilities, select a development team for both `StarPlay` and `StarPlayBroadcast`.
4. Enable the App Groups capability on both targets and use exactly `group.com.c0derz.starplay`, or replace the identifier consistently in `AppConstants.swift` and both entitlements files.
5. Keep the extension bundle identifier as `com.c0derz.starplay.broadcast`, or update `AppConstants.broadcastExtensionBundleIdentifier` to match it.
6. Build and install on a physical iPhone.
7. Run the app, allow Local Network access, start the future receiver on the same Wi-Fi network, and tap Start mirroring. Accept the system screen broadcast prompt.

The supplied Bitrise workflow performs an unsigned archive for compilation and packages the resulting app as `StarPlay.ipa`. An unsigned IPA cannot be installed on a normal iPhone. Device testing and distribution require an Apple Developer team, matching provisioning profiles, and correctly signed application-group entitlements. The workflow is suitable for validating that the project archives on the requested `osx-xcode-26.5` stack; configure signing in Bitrise for a deployable IPA.

## Receiver discovery and connection contract

The iPhone sender advertises from the host app on iOS 27 and from the Broadcast Upload Extension on the ReplayKit fallback path:

- Service type: `_starplay._tcp`
- Transport: TCP
- TXT `role=iphone`
- TXT `protocol=1`
- TXT `video=h264`
- TXT `format=annex-b`
- TXT `audio=reserved`

The receiver should browse `_starplay._tcp`, resolve the service endpoint, open TCP, and send its first framed packet as a `controlJSON` packet containing:

```json
{
  "type": "receiverHello",
  "protocolVersion": 1,
  "role": "windows-receiver",
  "deviceName": "OBS workstation",
  "requestedVideoCodec": "h264"
}
```

`pairingCode` is an optional field reserved for a future user-approved pairing flow. Protocol version 1 is intentionally local-network scoped; a future version can add TLS or a pairing challenge without redesigning the capture pipeline.

Every packet is length-prefixed:

```text
uint32 big-endian payload length
uint8  packet kind
bytes  packet body
```

The length includes the packet-kind byte. Packet kinds are:

| Kind | Value | Body |
| --- | ---: | --- |
| `controlJSON` | `0x01` | UTF-8 JSON control message |
| `videoConfiguration` | `0x02` | UTF-8 JSON `VideoConfiguration` |
| `videoFrame` | `0x03` | `int64` big-endian presentation time in microseconds, `uint8` flags, `uint32` width, `uint32` height, Annex-B H.264 NAL units |
| `ping` | `0x04` | Empty |
| `pong` | `0x05` | Empty |
| `goodbye` | `0x06` | Empty |

The video-frame flags use bit 0 for a keyframe. A `videoConfiguration` packet contains `codec=h264`, `format=annex-b`, width, height, frame rate, bitrate, orientation, and base64 SPS/PPS values. The receiver should create or recreate its decoder when this packet arrives, prepend SPS/PPS to a keyframe when required by its decoder, and render frame timestamps in order. The receiver should consume `orientationChanged` JSON control messages and use the supplied orientation rather than rotating pixels blindly.

A receiver can send either a `ping` packet or a `controlJSON` packet with `{"type":"ping"}` and receives a `pong` packet. Sending `{"type":"stop"}` as `controlJSON` requests the iPhone broadcast to end cleanly. The iPhone accepts one receiver. A second connection is rejected while the first is active; reconnect after the first TCP connection closes.

To provide an OBS source later, the Windows phase will need to browse Bonjour, implement the framing and H.264 Annex-B decoder, convert the decoded frames to a desktop texture or video frame, honor orientation changes, expose connection and reconnect state, and publish that decoded frame through an OBS capture-source plugin or a virtual camera/output layer. None of those Windows components are part of this phase.

## Official Apple documentation consulted

- [ReplayKit](https://developer.apple.com/documentation/replaykit)
- [RPSystemBroadcastPickerView](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview)
- [RPBroadcastSampleHandler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler)
- [RPSampleBufferType](https://developer.apple.com/documentation/replaykit/rpsamplebuffertype)
- [RPVideoSampleOrientationKey](https://developer.apple.com/documentation/replaykit/rpvideosampleorientationkey)
- [Bonjour](https://developer.apple.com/documentation/network/bonjour)
- [NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [NWConnection](https://developer.apple.com/documentation/network/nwconnection)
- [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser)
- [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor)
- [NWTXTRecord](https://developer.apple.com/documentation/network/nwtxtrecord)
- [NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription)
- [NSBonjourServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices)
- [Video Toolbox](https://developer.apple.com/documentation/videotoolbox)
- [VTCompressionSessionCreate](https://developer.apple.com/documentation/videotoolbox/1428285-vtcompressionsessioncreate)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) for the platform distinction described above
