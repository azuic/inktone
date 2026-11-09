# App Store release package

## Current update — 1.1.1 (14)

Version 1.1 is live. Version 1.1.1 replaces the app icon with the four-ink sketch and uses the new iPhone screenshot, product page header and search results image, and keeps the existing iPad screenshot. See [the 1.1.1 (14) package](1.1.1-build13/README.md) for build and upload status.

The [1.1 (12) package](1.1-build12/README.md) records the instrument refresh, signed IPA, and 17 automated release checks.

## Historical release preparation — 1.0 (11)

Target: Tink-on 1.0 (11), com.tinkon.app, Apple app ID 6822096857.

Launch: Free, automatically release after Apple approves. Copyright Zui Chen; support/privacy contact hi@zui.ooo. The user confirmed an active ElevenLabs Starter subscription and chose to restore optional AI for this release.

## Current upload — October 15, 2026

Build **1.0 (11)** uploaded successfully through Xcode Organizer, which confirmed “App upload complete: TinkOn 1.0 (11) uploaded.” Signed archive: `../build/TinkOn-build11.xcarchive`. Includes AI enabled by default for new kits with first-request consent, the revised iPad layout/larger ink circles, full-pad dot spacing and web-style shading, square outlined sequencer steps with wider gaps, and bordered tempo buttons. The presentation kit is not bundled. Simulator build, visual checks on iPhone/iPad, and tempo interaction passed; the shading revision previously passed all eight unit tests.

App Store Connect processing, TestFlight group assignment, and replacing the selected release build are not yet confirmed. The last confirmed selected release build is 9. Updated Figma review screenshots are documented in `figma-review/README.md`.

## Verified October 13, 2026

- Build 10 selects AI + SYNTH for new installs, asks permission before the first request, and preserves existing source choices. Choosing SYNTH clears saved AI permission. Build 7 kits still load in local mode. Settings and the first-use prompt explain the provider, payload and possible model improvement. Build 10 passed seven unit tests and the iPhone UI flow, including the permission prompt, offline choice and relaunch persistence. The signed archive succeeded; upload is waiting for the Mac to be unlocked.
- Only a derived musical description and duration go through Tink-on's HTTPS server to ElevenLabs. No drawing pixels, touch coordinates, provider key, name, email or Tink-on user/device identifier is sent by the app.
- Network, quota and invalid-audio failures use the local synth. AI responses are validated, decoded, trimmed and saved as local CAF audio. Requests are cancelled on interruptions/backgrounding, keeping the sketch for retry; generation captures its destination pad at start.
- Seven unit tests passed, including build 7 migration, quota/invalid response rejection and cancellation. The full iPhone flow passed, and a separate UI run explicitly selected SYNTH to keep the offline flow independent of a restored AI preference.
- One manual live AI generation in build 8 succeeded through the production endpoint and stored 93,184 bytes of playable CAF audio for a 0.464-second sketch. Hardware audio latency is not established by simulator checks.
- Build 9 uploaded at 3:08 p.m. Pacific and remains selected for version 1.0. The new signed archive is ../build/TinkOn-build10.xcarchive; upload and selection are pending.
- The AI-enabled description and build 10 review notes, Music category, subtitle “Sketch a sound. Play a beat.”, 4+ rating, contacts, URLs and copyright are saved. Sign-in is not required. Content rights is Yes, with necessary rights, based on the paid plan and no bundled provider samples.
- The user approved the revised privacy declaration. Other User Content: unlinked, App Functionality + Other Purposes (possible provider model improvement). Other Diagnostic Data: linked because request logs may include network addresses, App Functionality. Neither is used for tracking. Both answers are published.
- Free pricing and availability in 175 storefronts configured; automatic release selected. Mac and Vision Pro distribution disabled for this iPhone/iPad release.
- Final support/privacy deployment READY: dpl_BUWadMTiQ2NuFDEGmX5snyWcLsz2. https://tinkon.zui.ooo/support.html and https://tinkon.zui.ooo/privacy.html .
- iPad portrait, landscape and WAV sharing previously visually verified.

## Screenshots ready for manual upload

The user will upload screenshots themselves. Automated upload was blocked by browser extension file access. Apple's Add for Review validation reported only these two missing screenshot slots.

| App Store slot | File | Dimensions |
| --- | --- | --- |
| iPhone Dynamic Island, medium | screenshots/03-iphone-17-pro-instrument.jpg | 2622 × 1206 |
| iPad 13-inch | screenshots/02-ipad-13-portrait.jpg | 2064 × 2752 |
| Optional large iPhone | screenshots/01-iphone-17-pro-max-instrument.jpg | 2868 × 1320 |

Real build 7 Simulator exports, inspected and converted to opaque JPEG without resizing. They show the SYNTH instrument layout, which remains available by selecting SYNTH in Settings. Original PNGs retained. The synthetic eight-pad presentation fixture is not bundled in the app.

## Remaining work

1. Confirm build 11 processing and select it for version 1.0; assign it to the internal TestFlight group if testing is needed.
2. User uploads the required JPEGs under App Previews and Screenshots, then saves.
3. Revalidate and submit for public App Store review. No public review submission is confirmed.
4. DSA account status and any regional requirements remain separate account checks; Apple's current version-validation banner listed only screenshots. Do not infer trader status or accept a new agreement. Review phone belongs only in App Store Connect.

Historical builds 6–9 remain uploaded. Build 7 is local-only; build 8 restores AI. Build 11 is uploaded; build 9 is the last confirmed selection for version 1.0.
