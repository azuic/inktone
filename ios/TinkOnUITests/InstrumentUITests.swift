import XCTest

final class InstrumentUITests: XCTestCase {
    private var padCount: Int { UIDevice.current.userInterfaceIdiom == .pad ? 12 : 8 }
    func testReviewWalkthrough() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(app.buttons["generateButton"].waitForExistence(timeout: 10))
        app.buttons["Settings and help"].tap()
        app.buttons["Use offline synth"].tap()
        app.buttons["Close settings"].tap()
        print("TINKON_REVIEW_APP_READY")
        Thread.sleep(forTimeInterval: 1)
        captureReview("01-instrument", in: app)
        if app.buttons["Clear sketch"].isEnabled { app.buttons["Clear sketch"].tap() }
        app.buttons["generateButton"].tap()
        let emptyMessage = app.staticTexts["statusMessage"].label
        XCTAssertTrue(emptyMessage.contains("nothing sketched") || emptyMessage.contains("draw, then"),
                      "An empty sketch keeps drawing guidance visible")
        captureReview("02-empty-feedback", in: app)

        let inks = ["blue ink, resonant tone", "yellow ink, grainy texture",
                    "orange ink, metallic impact", "pink ink, deep sub drone"]
        let paper = app.otherElements["Sketch paper"]
        for index in 0..<padCount {
            app.buttons[inks[index % inks.count]].tap()
            drawReviewStroke(on: paper, from: CGVector(dx: 0.15, dy: 0.2 + Double(index % 4) * 0.14),
                             to: CGVector(dx: 0.82, dy: 0.72 - Double(index % 4) * 0.12))
            if index == 2 {
                drawReviewStroke(on: paper, from: CGVector(dx: 0.82, dy: 0.48), to: CGVector(dx: 0.45, dy: 0.18))
            }
            app.buttons["generateButton"].tap()
            let ready = NSPredicate(format: "enabled == true")
            expectation(for: ready, evaluatedWith: app.buttons["generateButton"])
            waitForExpectations(timeout: 10)
        }
        app.buttons["pad\(padCount)"].tap()
        XCTAssertTrue(app.buttons["pad\(padCount)"].label.contains("selected"))
        app.buttons[inks[0]].tap()
        drawReviewStroke(on: paper, from: CGVector(dx: 0.18, dy: 0.25), to: CGVector(dx: 0.74, dy: 0.68))
        drawReviewStroke(on: paper, from: CGVector(dx: 0.74, dy: 0.68), to: CGVector(dx: 0.86, dy: 0.28))
        captureReview("03-populated-instrument", in: app)
        let pitch = app.sliders["Pad pitch"]
        pitch.adjust(toNormalizedSliderPosition: 0.75)
        XCTAssertEqual(pitch.value as? String, "6 semitones")
        captureReview("04-pitch", in: app)
        pitch.adjust(toNormalizedSliderPosition: 0.5)
        app.buttons["transportButton"].tap()
        for slot in [1, 3, padCount - 1, padCount] { app.buttons["pad\(slot)"].tap() }
        app.buttons["Increase tempo"].tap()
        captureReview("05-sequencer-playing", in: app)
        app.buttons["transportButton"].tap()

        app.buttons["Settings and help"].tap()
        XCTAssertTrue(app.buttons["Close settings"].waitForExistence(timeout: 5))
        captureReview("06-settings", in: app)
        let settings = app.scrollViews.firstMatch
        let privacy = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "TINK-ON PRIVACY POLICY")).firstMatch
        for _ in 0..<4 {
            if privacy.exists && privacy.isHittable { break }
            settings.swipeUp()
        }
        XCTAssertTrue(privacy.isHittable)
        captureReview("07-help-and-privacy", in: app)
        for _ in 0..<4 {
            if app.buttons["Enable optional AI generation"].isHittable { break }
            settings.swipeDown()
        }
        app.buttons["Enable optional AI generation"].tap()
        XCTAssertEqual(app.buttons["Enable optional AI generation"].value as? String, "Selected")
        app.buttons["Close settings"].tap()
        app.buttons["generateButton"].tap()
        let consent = app.descendants(matching: .any)["aiConsentPanel"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        captureReview("08-ai-consent", in: app)
        consent.buttons["Use Offline Synth"].tap()
        XCTAssertFalse(consent.exists)
        let replacedVisiblePad = NSPredicate { _, _ in
            app.buttons["pad\(self.padCount)"].label.contains("resonant tone")
        }
        expectation(for: replacedVisiblePad, evaluatedWith: app)
        waitForExpectations(timeout: 10)

        app.buttons["Share selected pad as WAV"].tap()
        let save = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        let shareReady = save.waitForExistence(timeout: 15)
        captureReview("11-wav-share", in: app)
        XCTAssertTrue(shareReady, "The exported WAV must reach the system share menu")
        print("TINKON_REVIEW_LANDSCAPE_COMPLETE")
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["generateButton"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .portrait : .landscapeRight
        assertDrawingProportions(in: app)
        captureReview("09-rotated-instrument", in: app)
        app.buttons["Settings and help"].tap()
        captureReview("10-rotated-settings", in: app)
        app.buttons["Close settings"].tap()
    }

    private func drawReviewStroke(on paper: XCUIElement, from: CGVector, to: CGVector) {
        paper.coordinate(withNormalizedOffset: from).press(forDuration: 0.05,
            thenDragTo: paper.coordinate(withNormalizedOffset: to))
    }

    private func captureReview(_ name: String, in app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "review-\(name)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDrawingProportionsAcrossLayouts() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(app.buttons["generateButton"].waitForExistence(timeout: 10))
        app.buttons["Settings and help"].tap()
        app.buttons["Use offline synth"].tap()
        app.buttons["Close settings"].tap()
        let paper = app.otherElements["Sketch paper"]
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)))
        app.buttons["generateButton"].tap()
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: app.buttons["Share selected pad as WAV"])
        waitForExpectations(timeout: 10)
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)))
        let pitch = app.sliders["Pad pitch"]
        XCTAssertTrue(pitch.isHittable)
        pitch.adjust(toNormalizedSliderPosition: 0)
        let leftEdge = pitch.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let minimumThumb = leftEdge.withOffset(CGVector(dx: 12, dy: 0))
        minimumThumb.press(forDuration: 0.05, thenDragTo: leftEdge)
        XCTAssertEqual(pitch.value as? String, "-12 semitones")
        minimumThumb.press(forDuration: 0.05,
            thenDragTo: pitch.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)))
        XCTAssertEqual(pitch.value as? String, "12 semitones")
        pitch.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertEqual(pitch.value as? String, "0 semitones")
        assertDrawingProportions(in: app)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Matching drawing areas — landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .portrait : .landscapeRight
        assertDrawingProportions(in: app)
        let rotated = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        rotated.name = "Matching drawing areas — rotated"
        rotated.lifetime = .keepAlways
        add(rotated)
    }

    private func assertDrawingProportions(in app: XCUIApplication) {
        let settled = NSPredicate { _, _ in
            let canvas = app.otherElements["Sketch paper"].frame
            guard canvas.height > 0, canvas.width > 0 else { return false }
            let ratio = canvas.width / canvas.height
            return (1...self.padCount).allSatisfy { slot in
                let pad = app.buttons["pad\(slot)"].frame
                let height = pad.height - 17
                return height > 0 && abs(pad.width / height - ratio) < 0.02
            }
        }
        expectation(for: settled, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let canvas = app.otherElements["Sketch paper"].frame
        XCTAssertFalse(app.buttons["pad\(padCount + 1)"].exists, "The bank must end at the device's pad count")
        XCTAssertEqual(canvas.minY, app.buttons["Settings and help"].frame.maxY + 1, accuracy: 1,
                       "The sketch starts at the header, without letterboxing")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let gridTop = app.buttons["pad1"].frame.minY
            let gridBottom = app.buttons["pad12"].frame.maxY
            XCTAssertEqual(gridBottom, app.sliders["Pad pitch"].frame.minY - 7, accuracy: 2,
                           "The iPad grid fills the area above the pitch strip")
            if app.frame.width > app.frame.height {
                XCTAssertEqual(gridTop, canvas.minY + 9, accuracy: 2)
            }
        }
        XCTAssertEqual(app.buttons["generateButton"].frame.maxX, app.buttons["Clear sketch"].frame.maxX, accuracy: 1)
        if app.frame.height > app.frame.width {
            XCTAssertEqual(canvas.width, app.frame.width, accuracy: 1)
            XCTAssertEqual(canvas.minX, app.frame.minX, accuracy: 1)
        }
        let inks = ["blue ink, resonant tone", "yellow ink, grainy texture",
                    "orange ink, metallic impact", "pink ink, deep sub drone"]
        let rowY = app.buttons[inks[0]].frame.midY
        for label in inks {
            let ink = app.buttons[label]
            XCTAssertTrue(ink.isHittable)
            XCTAssertEqual(ink.frame.midY, rowY, accuracy: 1)
            XCTAssertGreaterThanOrEqual(ink.frame.minY, canvas.maxY - 1)
            XCTAssertLessThanOrEqual(ink.frame.maxY, app.buttons["generateButton"].frame.minY)
            XCTAssertGreaterThanOrEqual(ink.frame.width, 44)
            XCTAssertGreaterThanOrEqual(ink.frame.height, 44)
        }
        XCTAssertGreaterThanOrEqual(app.buttons["Undo last stroke"].frame.minY, canvas.maxY - 1)
        XCTAssertGreaterThanOrEqual(app.buttons["Clear sketch"].frame.minY, canvas.maxY - 1)
        XCTAssertGreaterThanOrEqual(app.buttons["generateButton"].frame.midY - canvas.maxY, 40)
        XCTAssertGreaterThanOrEqual(app.staticTexts["statusMessage"].frame.minY, canvas.maxY)
        for slot in 1...padCount {
            let pad = app.buttons["pad\(slot)"].frame
            // The drawing field fills the pad above its separate 17pt label strip.
            let artworkHeight = pad.height - 17
            XCTAssertEqual(pad.width / artworkHeight, canvas.width / canvas.height, accuracy: 0.02)
            XCTAssertTrue(app.buttons["pad\(slot)"].isHittable)
            XCTAssertGreaterThanOrEqual(pad.width, 44)
            XCTAssertGreaterThanOrEqual(pad.height, 44)
        }
    }

    func testConsentLayoutAndLargeText() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["generateButton"].waitForExistence(timeout: 10))
        app.buttons["Settings and help"].tap()
        app.buttons["Use offline synth"].tap()
        app.buttons["Enable optional AI generation"].tap()
        app.buttons["Close settings"].tap()
        let paper = app.otherElements["Sketch paper"]
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)))
        app.buttons["generateButton"].tap()
        let consent = app.descendants(matching: .any)["aiConsentPanel"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        XCTAssertTrue(consent.buttons["Use AI"].isHittable)
        XCTAssertTrue(consent.buttons["Use Offline Synth"].isHittable)
        XCTAssertFalse(app.buttons["generateButton"].isEnabled, "The modal blocks the instrument controls")
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "AI chooser — largest accessibility text, landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        let disclosure = consent.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ElevenLabs")).firstMatch
        let initialY = disclosure.frame.minY
        let scroll = consent.scrollViews.firstMatch
        XCTAssertTrue(scroll.exists, "Large text keeps the disclosure in a scrollable region")
        scroll.swipeUp()
        XCTAssertLessThan(disclosure.frame.minY, initialY, "The full disclosure remains reachable")
        let scrolled = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        scrolled.name = "AI chooser — scrolled disclosure"
        scrolled.lifetime = .keepAlways
        add(scrolled)
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .portrait : .landscapeRight
        XCTAssertTrue(consent.buttons["Use Offline Synth"].waitForExistence(timeout: 5))
        XCTAssertTrue(consent.buttons["Use AI"].isHittable)
        let rotated = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        rotated.name = "AI chooser — largest accessibility text, rotated"
        rotated.lifetime = .keepAlways
        add(rotated)
        consent.buttons["Use Offline Synth"].tap()
        XCTAssertFalse(consent.exists)
        XCTAssertTrue(app.staticTexts["PROMPT · SYNTH"].exists)
        app.buttons["Settings and help"].tap()
        let explanation = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "SYNTH works offline.")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(explanation.frame.height, 50, "Settings text responds to accessibility sizing")
        captureReview("12-large-text-settings", in: app)
        let originalY = explanation.frame.minY
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertLessThan(explanation.frame.minY, originalY)
        captureReview("13-large-text-settings-scrolled", in: app)
        app.buttons["Close settings"].tap()
    }

    func testSketchGeneratePlayPersistAndShare() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(app.buttons["generateButton"].waitForExistence(timeout: 10))
        // Keep this offline flow independent of a restored AI preference or provider quota.
        app.buttons["Settings and help"].tap()
        app.buttons["Use offline synth"].tap()
        app.buttons["Close settings"].tap()
        XCTAssertTrue(app.staticTexts["PROMPT · SYNTH"].exists)
        // Delete the previous test's first pad if the simulator retained a kit.
        let pad = app.buttons["pad1"]
        pad.tap()
        let delete = app.buttons["Delete selected pad"]
        if delete.isEnabled { delete.tap() }
        let paper = app.otherElements["Sketch paper"]
        XCTAssertTrue(paper.exists)
        paper.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: paper.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7)))
        app.buttons["Settings and help"].tap()
        app.buttons["Enable optional AI generation"].tap()
        app.buttons["Close settings"].tap()
        app.buttons["generateButton"].tap()
        let consent = app.descendants(matching: .any)["aiConsentPanel"]
        XCTAssertTrue(consent.waitForExistence(timeout: 5))
        XCTAssertTrue(consent.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ElevenLabs")).firstMatch.exists)
        XCTAssertTrue(consent.buttons["Use AI"].isHittable)
        XCTAssertTrue(consent.buttons["Use Offline Synth"].isHittable)
        let chooserScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        chooserScreenshot.name = "Compact AI sound chooser"
        chooserScreenshot.lifetime = .keepAlways
        add(chooserScreenshot)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(consent.buttons["Use Offline Synth"].waitForExistence(timeout: 5))
            XCTAssertTrue(consent.buttons["Use AI"].isHittable)
            let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            portrait.name = "Compact AI sound chooser — portrait"
            portrait.lifetime = .keepAlways
            add(portrait)
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        consent.buttons["Use Offline Synth"].tap()
        XCTAssertFalse(consent.exists)
        XCTAssertTrue(app.staticTexts["PROMPT · SYNTH"].exists)
        XCTAssertTrue(pad.waitForExistence(timeout: 5))
        let share = app.buttons["Share selected pad as WAV"]
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: share)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(share.isEnabled)
        app.buttons["transportButton"].tap()
        XCTAssertEqual(app.buttons["transportButton"].label, "STOP")
        pad.tap()
        app.buttons["transportButton"].tap()
        XCTAssertEqual(app.buttons["transportButton"].label, "PLAY")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Tink-on instrument"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["PROMPT · SYNTH"].exists, "Keep the user's offline choice after relaunch")
        pad.tap()
        XCTAssertTrue(share.isEnabled, "Generated pad must survive app termination")
        share.tap()
        XCTAssertTrue(app.cells["Save to Files"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["LP.CaptionBar.BottomCaption"].label.contains("Audio"))
    }
}
