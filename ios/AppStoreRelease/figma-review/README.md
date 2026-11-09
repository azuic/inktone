# App Store screenshot review drafts

October 15, sequencer revision: square step faces with wider gaps and visible outlines; tempo −/+ now use the bordered panel key style. Preview hits are exactly steps 1, 2, 5, 9, and 10. Simulator build succeeded; iPhone/iPad layouts were visually checked and tempo changes verified at 120 → 125 → 120 BPM. Figma frames now use `../screenshots/13-iphone-square-steps.png` and `../screenshots/12-ipad-square-steps.png`. Latest review renders: `11-iphone-square-steps-preview.png` and `12-ipad-square-steps-preview.png`. A fresh release archive/upload is still needed for these source changes.

October 15: refreshed both current Figma frames with actual app captures using loose blue/yellow freehand strokes inspired by the web reference. The presentation kit also has varied hand-drawn pad sketches, including mixed-ink examples showing the gray-tone mapping. iPhone source: `../screenshots/11-iphone-landscape-freehand.png` (2622 × 1206); iPad source: `../screenshots/10-ipad-portrait-freehand.png` (2064 × 2752). Latest review renders: `09-iphone-freehand-preview.png` and `10-ipad-freehand-preview.png`. The fixture generator compiles and validates the kit. No shipping behavior was changed in this screenshot refresh.

October 14: pad illustrations now use coverage-based transparency and a stroke-length-ranked gray ramp matching the web renderer. Full rectangular dot spacing is retained. All eight unit tests pass. The portrait Figma image now uses the real Simulator capture `../screenshots/09-ipad-portrait-web-tones.png`; latest review preview is `08-ipad-web-tones-preview.png`. These source edits still require a fresh release archive before distribution.

October 14: iPad regular-width ink circles increased from 21 to 40 points; compact layouts retain 21 points. Build and Simulator selection/visual checks passed. The portrait Figma image now uses `../screenshots/08-ipad-portrait-large-colors.png`; current review preview is `07-ipad-large-colors-preview.png`.

Latest pad artwork update: the 13×13 grid uses independent horizontal and vertical spacing across each pad's full rectangular artwork bounds, with square dots and a reserved label strip. Removed the centered square artwork constraint. Build passed and the real portrait Simulator capture `../screenshots/07-ipad-portrait-full-pad-dots.png` now fills Figma node `1:23`. Current preview: `06-ipad-full-pad-dots-preview.png`. A new release archive is still required for these source edits.

**Current selection: portrait iPad (`1:13`).** At the user's correction, restored the vertical layout and updated its image with `../screenshots/06-ipad-portrait-expanded-pads.png`. The wider color toolbar and expanded pad grid are retained. Landscape frame `5:2` is hidden as a previous draft. Current review preview: `05-ipad-portrait-updated-preview.png`.

The landscape iPad frame `5:2` was refreshed with `../screenshots/05-ipad-landscape-expanded-pads.png` after rebuilding the actual app: regular-width layouts use an 80-point ink toolbar, and the two pad rows fill the available panel height. Pad artwork retains square proportions. Simulator build and color/pad selection checks passed. `04-ipad-expanded-preview.png` is the current Figma review preview. These source changes postdate the archived build 10 and require a fresh release archive before distribution; the portrait draft remains an earlier comparison.

Added a landscape iPad draft on October 13, 2026: [Figma frame 5:2](https://www.figma.com/design/Hv3pSpwIWaXa5Zym6T3FAQ?node-id=5-2), 2752 × 2064, with editable headline and branding. Uses the real landscape Simulator export `../screenshots/04-ipad-13-landscape.png`; the original portrait draft is retained for comparison. Figma rendering was visually checked. `03-ipad-landscape-preview.png` is a 1600 × 1200 review preview; export the Figma frame at 1× for full resolution.

Prepared October 13, 2026. Both layouts are now in [Tink-on — App Store Screenshots](https://www.figma.com/design/Hv3pSpwIWaXa5Zym6T3FAQ), on the “App Store • Review” page (0:1). Rendered and visually checked in Figma.

Figma frame IDs: iPhone `1:2`, iPad `1:13`. Headlines and brand elements are editable native Figma layers, using IBM Plex Mono Bold (Menlo was unavailable in the connector). Real app screenshots are separate image fills. Both frames have PNG export settings at 1×, preserving their full dimensions.

| Layout | Dimensions | Export | Layout source |
| --- | --- | --- | --- |
| iPhone, landscape | 2622 × 1206 | 01-iphone-landscape.png | 01-iphone-landscape.svg |
| iPad, portrait | 2064 × 2752 | 02-ipad-portrait.png | 02-ipad-portrait.svg |

Both PNGs are opaque RGB at the required App Store dimensions. The SVGs contain separate headline, logo and ink-color elements plus an embedded real app screenshot. The full application interface is preserved, with no invented controls or altered app text. Only the outer corners are clipped to the layout frame.

The source images are the existing build 7 Simulator exports. They show SYNTH mode, which remains available in build 10. These are review drafts, not newly captured AI-mode screens. Neither draft has been uploaded to App Store Connect.

Design: the app's light gray surface, black square brand mark, monospaced headline, and four ink colors. The app occupies most of each frame. The headline is “Sketch a sound. Play a beat.”

`index.html` previews the original local drafts. `create_layouts.py` recreates those self-contained SVGs from the original screenshots. Figma is the editable review version; export its frames after design approval. Neither Figma layout has been uploaded to App Store Connect.
