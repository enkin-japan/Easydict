//
//  AppPathManager+Cache.swift
//  Easydict
//
//  Created by Alfred on 2026/09/14.
//

import Foundation

extension AppPathManager {
    /// The root directory for app-managed disposable data.
    var cacheDirectory: URL {
        appSupportDirectory.appendingPathComponent("cache", isDirectory: true)
    }

    var mdictMetadataCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("mdict-metadata", isDirectory: true)
    }

    /// The previous MDict metadata cache location.
    var legacyMDictMetadataCacheDirectory: URL {
        appSupportDirectory.appendingPathComponent("mdict-metadata-cache", isDirectory: true)
    }
}
