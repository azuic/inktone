# Tink-on iOS release

## Release state

**Current update:** Version 1.1 is live on the [App Store](https://apps.apple.com/us/app/tink-on/id6822096857). Version **1.1.1 (14)** uses the four-ink sketch icon, with updated iPhone, product page header and search artwork. See [the release package](../ios/AppStoreRelease/1.1.1-build13/README.md) for the signed archive and upload status. The older notes below describe prior releases.

**October 15 current upload:** Version 1.0 (11) uploaded successfully through Xcode Organizer after signed archiving. Includes all latest UI changes: iPad layout/ink sizes, shaded full-pad dot artwork, square spaced sequencer steps, and bordered tempo controls. Archive: `ios/build/TinkOn-build11.xcarchive`. Processing, TestFlight assignment, and release build selection are not yet confirmed; build 9 remains the last confirmed selection. See `ios/AppStoreRelease/README.md` for details. The October 13 notes below are historical.

**October 13 current release:** Build 10 passed seven unit tests, the iPhone UI flow and signed archiving. Upload is waiting for the Mac to be unlocked. At the user's request, new installs select AI + SYNTH. A first-use prompt explains the data and recipients before any AI request; Use AI grants permission, while Use Offline Synth generates locally and remembers that choice. Existing source preferences, including build 7 local-only kits, are preserved. Selecting SYNTH clears saved AI permission. AI sends a derived description and duration and falls back to local synthesis on service failure. Build 9 remains uploaded and selected until build 10 is ready.

The AI-enabled listing, review notes and licensed-content answer are saved. The user approved the updated privacy label: unlinked user content for functionality and other purposes; linked request diagnostics for functionality; no tracking. Both declarations are published. Free pricing, 175-storefront availability and automatic release remain configured. The support/privacy pages are live. Apple's Add for Review validation lists only the required iPhone medium and 13-inch iPad screenshots, which the user will upload. Current evidence and remaining work: ../ios/AppStoreRelease/README.md. Public App Store review is not submitted.

## Historical beta preparation

The approved app identity is `com.tinkon.app`, owned by the Zui Chen developer team (`9PFHA8HVMX`). Version **1.0, build 1** was uploaded successfully to App Store Connect on October 12, 2026 at 3:48 p.m. Pacific. The latest version is **1.0, build 5**, uploaded at 4:47 p.m. Pacific on the same date. Processing is complete and all five builds show **Testing** in the **Personal Testing** internal group. The owner's account is the only tester; App Store Connect confirms build 1 is installed, and build 5, including the black app icon, is available to update in TestFlight. Build **1.0 (5)** has been submitted for external Beta App Review and shows **Waiting for Review**. A public invitation link is configured, but testers cannot join until Apple approves the build. The app has not been submitted for public App Store review. Simulator verification does not establish real-device audio latency or App Store approval.

## Verified on October 12, 2026

- Xcode 26.3 with the iOS 26.2 SDK successfully built the app and created a signed arm64 release archive.
- App Store export succeeded using the team's cloud-managed Apple Distribution certificate. The package is `ios/build/AppStore/TinkOn.ipa` (version 1.0, build 1).
- The extracted App Store package passed local strict code-signature verification against the macOS trust store.
- The final bundle ID `com.tinkon.app` was provisioned successfully for the existing developer team. The rebuilt archive and exported package both use that ID, with a matching Store provisioning profile and verified code signature.
- Five unit tests passed: feature mapping, four synth voices and pitch, pixel previews, kit/audio restoration, and stereo 44.1 kHz → mono 48 kHz conversion and trimming.
- The iPhone 17 Pro simulator UI flow passed: sketch, generation, pad playback, live recording, app termination/restoration and WAV sharing.
- After the UI review, GENERATE became an inset rounded key and Settings was rebuilt with the instrument's panels, monospaced labels and sound-source keys. The iPhone flow passed again, Settings selection/dismissal was checked in the simulator, and the signed archive and App Store package were refreshed.
- Build 2 moves WAV sharing beside Settings, uses a square black brand mark, gives utility controls the web app's bordered chip style, and places ink selection, undo and clear in a vertical strip beside the board. Drawing and dots cover the full rectangular board; the bottom safe-area gap and extra bottom inset are removed. The existing iPhone drawing → generation → playback → restoration → sharing UI test passed, and the layout and Settings were visually checked. The signed `ios/build/TinkOn-build2.xcarchive` uploaded successfully at 4:09 p.m. Pacific on October 12, 2026; Processing finished and build 2 was added to Personal Testing. App Store Connect confirms **1 Tester ∙ 2 Builds**, with **1.0 (2)** showing **Testing**. Build-specific layout testing notes were saved.
- Build 3 removes borders from Share, Settings and the tempo −/+ icons while retaining 44-point touch targets. The sequencer has horizontal and vertical internal insets so PLAY clears its frame, plus 12 points of clearance below the section so its bottom frame and steps remain visible. The sketch board still fills its available space. The existing iPhone UI flow passed and the complete section was visually checked. The signed archive is `ios/build/TinkOn-build3.xcarchive`; upload succeeded at 4:32 p.m. Pacific on October 12, 2026. Processing completed and build 3 was added to Personal Testing. The group confirms **1 Tester ∙ 3 Builds**, with **1.0 (3)** showing **Testing**. Build-specific testing notes were saved.
- Build 4 groups the tempo −/+ buttons together at the right, after the BPM readout. The + icon aligns with DEL above it; both icons retain borderless 44-point touch targets. The BPM value stays on one line. Simulator build and visual checks passed, and tapping + then − changed 120 → 125 → 120. The final signed archive is `ios/build/TinkOn-build4.xcarchive`; upload succeeded at 4:41 p.m. Pacific on October 12, 2026. Processing completed and build 4 was added to Personal Testing. App Store Connect confirms **1 Tester ∙ 4 Builds**, with **1.0 (4)** showing **Testing**. The alignment testing notes were saved.
- Build 5 replaces the colorful app icon with an opaque solid black 1024×1024 icon matching the web favicon. The deterministic AppKit generator and README were updated. The simulator build passed, the installed home-screen icon was visually confirmed black, and the signed archive's compiled iPhone icon was inspected. The signed archive is `ios/build/TinkOn-build5.xcarchive`; upload succeeded at 4:47 p.m. Pacific on October 12, 2026. Processing completed and build 5 was added to Personal Testing. App Store Connect confirms **1 Tester ∙ 5 Builds**, with **1.0 (5)** showing **Testing** and the black icon visible. Icon testing notes were saved.
- iPad automated verification remains incomplete: the fresh iPad Pro simulator failed to launch the test runner and a retry stalled. Verify its landscape, portrait and share-sheet behavior before submitting the universal app.
- Actual provider generation and physical-device latency have not been tested. No iPhone was connected during development. App Store export is local packaging; it does not mean Apple has accepted a submitted build.

The user created the App Store Connect record for `com.tinkon.app` (Apple app ID `6822096857`), and Xcode's upload succeeded against it. Internal setup was completed in the user's signed-in Chrome session. **Personal Testing** contains one tester and builds **1.0 (1)** through **1.0 (5)**, with automatic distribution disabled. Testing notes covering drawing, generation, pads, pitch, looping, restoration and WAV export were saved. The user has installed build 1 and can update to build 5 in TestFlight on their device.

## External beta preparation

The **External Beta** group was created on October 12, 2026 (group ID `e5014328-2bae-481e-8387-a232ec216fbd`). Build **1.0 (5)** was submitted for Beta App Review and shows **Waiting for Review**. The group contains zero testers and one build, with automatic tester notification selected. The beta description, review instructions and testing checklist were saved. **Sign-in required** is unchecked. Review contact is Zui Chen at `hi@zui.ooo`, with the user-provided phone number saved only in App Store Connect. Tester feedback is directed to `hi@zui.ooo`.

The public invitation is [Join Tink-on on TestFlight](https://testflight.apple.com/join/DvcGR4hG), configured as **Open to Anyone**, without an additional tester limit. App Store Connect confirms that testers cannot join through the public link until this group has an approved build.

### Beta description

Tink-on turns a sketch into a playable sound. Choose one of four inks, draw on the dotted board, and generate a sound for an eight-pad sampler. Adjust pitch, record a repeating 16-step beat, and share sounds as WAV files. Your current kit saves on this device.

The local synth works offline. Optional AI sound generation starts disabled and can be enabled in Settings. No account or microphone access is required.

For this beta, please test drawing responsiveness, pad playback, pitch and tempo changes, looping, saved-kit restoration, and WAV sharing. On iPhone, use landscape orientation.

### Beta review instructions

No account, demo credentials, subscription or purchase is required. On iPhone, rotate to landscape. Select an ink in the column beside the board, draw and press GENERATE. Tap a filled pad to play it. Select a pad to adjust PITCH. Press PLAY and tap pads to record into the repeating 16-step loop; press STOP to stop playback. Tap a filled step to erase its recorded hits. Use the Share icon beside Settings to export the selected pad as a WAV through the system share sheet. Close and reopen the app to check automatic kit restoration.

AI generation is optional and starts off. All core features work with the local synth while offline. When enabled in Settings, AI generation sends a derived text prompt and duration to Tink-on's server and ElevenLabs; drawing pixels stay on the device. A failed AI request falls back to the local synth. No microphone permission is used.

Build 1.0 (5) includes the black app icon, borderless header and tempo icons, the full dotted drawing board, and the corrected sequencer layout.

### External testing focus

- Draw with each ink, including near the board edges; check responsiveness and undo/clear.
- Generate and play pads, including overlapping and rapid hits; adjust pitch.
- Record, replay and erase a loop; change tempo using the right-aligned −/+ controls.
- Reopen the app and confirm the saved kit, pitch and beat return.
- Export a WAV through Share and confirm the file plays.
- Check both iPhone landscape orientations and the complete sequencer frame; on iPad also check portrait and sharing.
- Verify the black Home Screen icon. Optional AI can be tested separately with an internet connection.

External distribution is awaiting Beta App Review. The public link above can be shared for testers to join after approval. See [Apple's external testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) and [required test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

## Current release checks

Build 9 remains selected; replace it with signed build 10 after upload. See ../ios/AppStoreRelease/README.md for current upload, privacy, pricing, screenshot and submission state. Historical beta builds 1–6 may expose AI.

Physical-device verification remains necessary for hardware audio latency, silent-switch behavior, headphones, simultaneous pad hits, interruptions and relaunch. Simulator checks do not establish hardware latency.

Increment the build number for future uploads. Organizer uploaded builds 6–9 successfully; command-line account upload failed.

## App Store listing draft

**Name:** Tink-on

**Subtitle:** Sketch a sound. Play a beat.

**Promotional text:** Turn a few lines of ink into an instrument. Draw, generate, and tap your own sounds into a repeating beat.

**Description:**

Sketch a sound with Tink-on, a drawing instrument and eight-pad sampler.

Choose a risograph ink and draw a shape. Its height becomes pitch, its length sets duration, and its speed and corners shape the texture. Generate a sound, play it on a pad, then tap it into a repeating beat.

- Four ink voices: resonant tones, grainy textures, metallic impacts and deep sub drones.
- Eight pads with pixel previews of your drawings.
- Pitch each pad up or down an octave.
- Record a beat into a 16-step loop at 40–240 BPM.
- Return to your current kit after closing the app.
- Share individual sounds as WAV files.

Local synthesis, sequencing and WAV export work offline. Optional AI uses ElevenLabs through Tink-on’s server and requires internet. AI + SYNTH is selected for new installs and asks permission before the first AI request. Use Offline Synth selects local generation. AI failures fall back to local synthesis. No account, ads or microphone access. On iPhone, use landscape orientation.

**Keywords:** sampler,sketch,synth,beat,music,drum,sequencer,sound,draw,instrument

**Launch choices:** Free, automatically release after Apple approves. Copyright: 2026 Zui Chen. Support URL: `https://tinkon.zui.ooo/support.html`. Marketing URL: `https://tinkon.zui.ooo`. Privacy URL: `https://tinkon.zui.ooo/privacy.html`.

**Review notes draft:**

No account or login is required. On iPhone, hold the device in landscape. Select an ink, draw on the paper and press GENERATE to fill a pad. Tap pads to play; press PLAY and tap a pad to record hits into the repeating bar. Tap a filled step to erase its hits. Select a pad to adjust pitch or share a WAV through the share button. The current kit saves automatically.

The final build selects optional AI for new installs and asks permission before the first request. Existing source choices are preserved. Settings discloses the payload, provider retention and possible model improvement and links app-specific support/privacy. Failures use the local synth.

## Submission

- Apply the approved developer contact, copyright owner, public support/privacy URLs and free pricing in App Store Connect.
- Complete the current age-rating questionnaire and content-rights answers in App Store Connect.
- Upload the prepared iPhone and iPad JPEGs from ios/AppStoreRelease/screenshots. They show the SYNTH interface, available by choosing SYNTH in Settings; the user chose to upload them manually.
- Verify VoiceOver labels and large-text behavior in Settings; the instrument controls use compact labels suited to a landscape instrument.
- Submit final build 10 after upload, selection, screenshot upload, verification and listing completion. The user selected automatic release after Apple approves.

## Sources

- [Apple: upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Apple: prepare for app distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: app privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
