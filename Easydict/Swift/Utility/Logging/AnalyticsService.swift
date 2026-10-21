//
//  AnalyticsService.swift
//  Easydict
//
//  Created by tisfeng on 2025/12/22.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation

/// Slim build: analytics and crash reporting (Firebase / Sentry) are removed.
/// The API is kept as no-ops so existing call sites do not need to change.
@objc(EZAnalyticsService)
@objcMembers
final class AnalyticsService: NSObject {
    @objc(setupCrashLogService)
    static func setupCrashService() {}

    static func setCrashEnabled(_ enabled: Bool) {}

    @objc(logEventWithName:parameters:)
    static func logEvent(withName name: String, parameters: [String: Any]?) {}

    @objc(logWindowAppear:)
    static func logWindowAppear(_ windowType: EZWindowType) {}

    @objc(logQueryService:)
    static func logQueryService(_ service: QueryService) {}

    /// Returns a human-readable text length range (still used for local logging).
    static func textLengthRange(_ text: String) -> String {
        let length = text.utf16.count
        if length <= 10 {
            return "1-10"
        } else if length <= 50 {
            return "10-50"
        } else if length <= 200 {
            return "50-200"
        } else if length <= 1000 {
            return "200-1000"
        } else if length <= 5000 {
            return "1000-5000"
        } else {
            return "5000-∞"
        }
    }

    static func logAppInfo() {}
}
