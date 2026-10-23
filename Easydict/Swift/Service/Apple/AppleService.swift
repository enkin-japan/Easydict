//
//  AppleService.swift
//  Easydict
//
//  Created by tisfeng on 2024/10/9.
//  Copyright © 2024 izual. All rights reserved.
//

import Foundation
import NaturalLanguage

// MARK: - AppleService

/// Language detection with Apple's NaturalLanguage framework. Not a query service.
@objc(EZAppleService)
public class AppleService: QueryService {
    // MARK: Public

    public override func serviceType() -> ServiceType {
        .apple
    }

    public override func name() -> String {
        NSLocalizedString("apple_translate", comment: "")
    }

    public override func apiKeyRequirement() -> ServiceAPIKeyRequirement {
        .none
    }

    /// Supported languages dictionary
    @objc
    public override func supportLanguagesDictionary() -> MMOrderedDictionary {
        languageMapper.supportedLanguages.toMMOrderedDictionary()
    }

    /// Detect language using Apple's language detection.
    @nonobjc
    public override func detectText(_ text: String) async throws -> Language {
        let language = detectTextSync(text)
        return language
    }

    /// Detect language for Objective-C callers without spinning up a Task.
    @objc
    public override func detectText(
        _ text: String,
        completionHandler: @escaping (Language, Error?) -> ()
    ) {
        completionHandler(detectTextSync(text), nil)
    }

    @objc
    public func detectTextSync(_ text: String) -> Language {
        languageDetector.detectLanguage(text: text)
    }

    /// Convert NLLanguage to Language enum
    @objc
    public func languageEnum(fromAppleLanguage appleLanguage: NLLanguage) -> Language {
        languageMapper.languageEnum(from: appleLanguage)
    }

    // MARK: Internal

    @objc static let shared = AppleService()

    // MARK: Private

    private let languageMapper = AppleLanguageMapper.shared
    private let languageDetector = AppleLanguageDetector(enableDebugLog: true)
}
