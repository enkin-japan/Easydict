//
//  BuiltinDictionaryService.swift
//  Easydict
//
//  Slim build: offline Japanese and English word lookup in the bundled dictionaries
//  (JMdict with pitch accents and kanji, ECDICT), with pronunciation buttons.
//

import AppKit
import Foundation

// MARK: - BuiltinDictionaryService

@objc(EZBuiltinDictionaryService)
@objcMembers
class BuiltinDictionaryService: QueryService, @unchecked Sendable {
    // MARK: Lifecycle

    required init() {
        super.init()
        // Services are created when query windows load; extract the database early so the
        // first lookup and word splitting do not wait for it.
        BuiltinDictionaryStore.shared.prepareInBackground()
    }

    // MARK: Internal

    override func serviceType() -> ServiceType {
        .builtinDictionary
    }

    override func name() -> String {
        NSLocalizedString("service.builtin_dictionary.name", comment: "")
    }

    override func apiKeyRequirement() -> ServiceAPIKeyRequirement {
        .none
    }

    override func supportedQueryType() -> EZQueryTextType {
        [.dictionary, .sentence, .translation]
    }

    override func intelligentQueryTextType() -> EZQueryTextType {
        [.dictionary]
    }

    override func supportLanguagesDictionary() -> MMOrderedDictionary {
        let ordered = MMOrderedDictionary()
        for lang in EZLanguageManager.shared().allLanguages {
            ordered.setObject(lang as NSString, forKey: lang as NSString)
        }
        return ordered
    }

    @nonobjc
    override func translate(
        _ text: String,
        from: Language,
        to: Language
    ) async throws
        -> QueryResult {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // The store blocks while it opens, so look up off the calling task's thread.
        let html = await Task.detached(priority: .userInitiated) {
            Self.lookupHTML(query, language: from)
        }.value

        guard let html else {
            throw QueryError(type: .noResult)
        }
        result?.htmlString = html
        return result ?? QueryResult()
    }

    // MARK: Private

    /// Longest English phrase looked up, in words (ECDICT keeps short phrases only).
    private static let maxEnglishWords = 3

    private static func lookupHTML(_ query: String, language _: Language) -> String? {
        guard !query.isEmpty else { return nil }

        // Kanji-only text may be detected as Chinese; it is still worth a Japanese lookup.
        if query.contains(where: { $0.isKana || $0.isKanji }) {
            let matches = BuiltinDictionary.japaneseMatches(query)
            if !matches.isEmpty {
                return BuiltinDictionaryHTML.page(japanese: matches, query: query)
            }
        }

        let isEnglishLike = query.allSatisfy { $0.isASCII && ($0.isLetter || " '-.".contains($0)) }
        let wordCount = query.split(separator: " ").count
        if isEnglishLike, query.contains(where: \.isLetter), wordCount <= maxEnglishWords {
            let entries = BuiltinDictionary.englishEntries(query)
            if !entries.isEmpty {
                return BuiltinDictionaryHTML.page(english: entries, query: query)
            }
        }
        return nil
    }
}
