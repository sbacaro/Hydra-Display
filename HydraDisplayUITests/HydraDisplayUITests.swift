//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

import XCTest

@MainActor
final class HydraDisplayUITests: XCTestCase {

    nonisolated override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func testAppLaunchesWithMainWindow() {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10),
                      "The main window should appear at launch.")
    }

    func testSidebarShowsCoreSections() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Arrangement & Mirroring"].exists)
    }

    func testNavigateToArrangement() {
        let app = launchApp()
        let arrangement = app.staticTexts["Arrangement & Mirroring"]
        XCTAssertTrue(arrangement.waitForExistence(timeout: 10))
        arrangement.click()
        // The arrangement pane has a "Mirroring" section header.
        XCTAssertTrue(app.staticTexts["Mirroring"].waitForExistence(timeout: 5))
    }

    func testOpenAndCancelCreateSheet() {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))

        // The toolbar "+" button is labelled "New Virtual Display".
        let newButton = app.buttons["New Virtual Display"].firstMatch
        if newButton.waitForExistence(timeout: 5) {
            newButton.click()
            // The creation sheet exposes a "Create Display" button.
            let create = app.buttons["Create Display"]
            XCTAssertTrue(create.waitForExistence(timeout: 5),
                          "The create-display sheet should appear.")
            // Cancel to leave app state untouched.
            app.buttons["Cancel"].firstMatch.click()
        }
    }
}
