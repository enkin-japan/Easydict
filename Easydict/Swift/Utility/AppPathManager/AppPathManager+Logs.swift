//
//  AppPathManager+Logs.swift
//  Easydict
//
//  Created by Alfred on 2026/09/14.
//

import Foundation

extension AppPathManager {
    /// The root directory for all Easydict-managed logs.
    var logsDirectory: URL {
        appSupportDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    /// The root directory for app and crash logs.
    var appLogDirectory: URL {
        logsDirectory.appendingPathComponent("app", isDirectory: true)
    }

    /// The previous CocoaLumberjack-compatible log root.
    var legacyAppLogDirectory: URL {
        cachesDirectory.appendingPathComponent("MMLogs", isDirectory: true)
    }
}
