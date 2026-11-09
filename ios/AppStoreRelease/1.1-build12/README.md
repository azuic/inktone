# Tink-on 1.1 (12) release preparation

Bundle ID: `com.tinkon.app` · Apple app ID: `6822096857` · Team: `9PFHA8HVMX`.

Version 1.0 is live on the [App Store](https://apps.apple.com/us/app/tink-on/id6822096857). Apple's public lookup reports its release at `2026-10-31T19:13:49Z`. This package prepares the 1.1 update.

## Build and signing

- Signed archive: `../../build/TinkOn-1.1-build12.xcarchive`.
- App Store IPA: `../../build/AppStore-1.1-build12/TinkOn.ipa` (715,527 bytes).
- IPA SHA-256: `a44c1f8f967b568050bd24fd944c3257200e30bd1fbde5e18bfb568878341606`.
- The archive and exported IPA passed strict code-signature verification. The IPA uses the existing Apple Distribution identity and App Store provisioning profile, with `get-task-allow` false.
- Version 1.1, build 12, iPhone + iPad, arm64, minimum iOS 17, built with the iOS 26.2 SDK.
- The approved black icon with the white pixel wave is an opaque 1024×1024 RGB PNG. `AppIcon-1024.png` is the store asset reference; the compiled icon is included in the archive.
- Presentation fixtures and development secrets are excluded from the app bundle. `source-manifest.json` records the shipping source and icon hashes.

The command-line export could not use Xcode's account and selected an incompatible cached profile. Export through Xcode Organizer succeeded with its existing signed-in team. No new account or distribution identity was created.

## Included changes

- Eight pads in a 4×2 grid on iPhone; twelve pads in a 4×3 grid on iPad.
- Existing eight-pad kits expand without losing sounds, pitches or recorded steps. iPhone generation, playback and step indicators use its eight visible slots; saved extra slots remain intact.
- The sketch and pad drawing fields share proportions and fill their available space.
- Ink selection below the sketch, a larger prompt area, compact GENERATE face, flat black pitch thumb, consistent corners and utility controls.
- Settings and AI consent use the instrument's visual system; their reading text scales and remains scrollable.
- New black pixel-wave app icon.

## Store copy

- `metadata.en-US.json`: description, subtitle, promotional text, keywords, URLs and review notes. All fields pass their character limits.
- `whats-new.txt`: user-facing update notes.
- `review-notes.txt`: review instructions, source selection, AI permission and local fallback.
- `testflight-notes.txt`: testing focus.

The description now distinguishes eight iPhone pads from twelve iPad pads. It preserves the existing AI consent, local fallback and privacy disclosures. The public support and privacy URLs both returned HTTP 200. The bundled privacy manifest is unchanged: no tracking; existing AI-derived content and request-diagnostic declarations remain in place.

## Screenshots and verification

Current files and dimensions are listed in `screenshot-manifest.json`. Screenshots are actual native Simulator captures, with orientation normalized and opaque JPEG exports at the original resolution. The first instrument image in each required device slot is the suggested lead image. The SYNTH mode shown is available from Settings.

Apple currently requires iPhone Dynamic Island medium screenshots and 13-inch iPad screenshots for this universal app: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). The iPhone exports are 2622×1206; the iPad exports target 2752×2064 landscape and 2064×2752 portrait.

All 17 automated release checks passed: nine unit tests and four UI tests on iPhone, plus four UI tests on the 13-inch iPad. These cover kit migration, all voices, pixel previews, pitch, source/consent choices, large text, rotation, generation, recording, relaunch persistence and WAV export. The initial fresh iPad session stalled before tests started; restarting only that dedicated simulator allowed the full iPad UI run to pass. `verification.json` contains the final passing summaries.

The live production AI check also passed: a synthetic 0.5-second request returned HTTP 200 with MP3 audio, and the app's native reader decoded finite, non-silent mono PCM at 48 kHz. Evidence: `live-ai-check.json`. The test audio is not bundled in the app.

Simulator checks cover the instrument flow; physical-device audio latency is not established by them.

### Ready-to-upload screenshot files

| File | Slot | Native dimensions |
| --- | --- | --- |
| [01-iphone-instrument.jpg](screenshots/01-iphone-instrument.jpg) | iPhone Dynamic Island medium | 2622 × 1206 |
| [02-iphone-sequencer.jpg](screenshots/02-iphone-sequencer.jpg) | iPhone Dynamic Island medium | 2622 × 1206 |
| [03-iphone-ai-choice.jpg](screenshots/03-iphone-ai-choice.jpg) | iPhone Dynamic Island medium | 2622 × 1206 |
| [04-ipad-13-landscape.jpg](screenshots/04-ipad-13-landscape.jpg) | iPad 13-inch | 2752 × 2064 |
| [05-ipad-13-portrait.jpg](screenshots/05-ipad-13-portrait.jpg) | iPad 13-inch | 2064 × 2752 |
| [06-ipad-13-ai-choice.jpg](screenshots/06-ipad-13-ai-choice.jpg) | iPad 13-inch | 2752 × 2064 |

`release-preview.png` is a contact sheet for review, not a store-upload image. `presentation-kit.json` is an optional local fixture and is excluded from the shipping app. `ExportOptions.plist` records the options used by the successful Organizer export.

## App Store Connect handoff

As of November 2, 2026, Connect confirms version 1.0 (11) is live. The 1.1 draft is created and saved with the prepared description, promotional text, release notes and reviewer instructions. Xcode Organizer successfully uploaded version 1.1 (12). Apple processing completed successfully, and build 12 is attached to the saved 1.1 draft. Evidence: `app-store-connect-state.json`, `upload-complete.png` and `build-12-attached.jpg`.

The user requested keeping the existing screenshot previews. The inherited iPhone and iPad screenshots remain; the six local captures are review artifacts and are not being uploaded.

1. Preserve the existing screenshots, pricing, availability, privacy and content-rights configuration. The inherited release setting is automatic release after approval.
2. Submit for App Review only when the user approves submission. No review submission or public release has occurred.

[Apple's upload instructions](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
