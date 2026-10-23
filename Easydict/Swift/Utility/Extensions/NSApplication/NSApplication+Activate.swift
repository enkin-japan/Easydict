//
//  NSApplication+Activate.swift
//  Easydict
//
//  Created by tisfeng on 2025/8/27.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit

extension NSApplication {
    /// Convenience method to activate the application
    ///
    /// - Note: Since new API `activate()` on macOS 14.0 not working as expected, it doesn't bring app to front, so use old API for now.
    func activateApp() {
        logInfo("Activating application")
        activate(ignoringOtherApps: true)
    }
}
