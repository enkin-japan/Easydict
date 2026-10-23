//
//  BuiltinDictionary.swift
//  Easydict
//
//  Slim build: word lookup over the bundled dictionaries, shared by the Built-in Dictionary
//  service, word splitting (EnglishWordChecker) and query-type detection.
//

import Foundation

// MARK: - BuiltinDictionary

enum BuiltinDictionary {
    // MARK: Internal

    /// A JMdict entry found for the query, possibly through a conjugated form.
    struct JapaneseMatch: Sendable {
        let entry: JapaneseDictionaryEntry
        /// The dictionary form looked up, e.g. `食べる` for the query `食べなかった`.
        let lookupText: String
        /// Whether the query was a conjugated form of `lookupText`.
        let isDeinflected: Bool
    }

    static let maxJapaneseMatches = 5

    /// English entries for `word`, followed by the entries of its dictionary form when `word`
    /// is an inflection (`went` → `went`, `go`; `running` → `run` if not listed itself).
    static func englishEntries(_ word: String) -> [EnglishDictionaryEntry] {
        let store = BuiltinDictionaryStore.shared
        var entries = store.englishEntries(word)
        let lemmas = entries.isEmpty
            ? store.englishLemmas(ofForm: word)
            : entries.compactMap(\.lemma)
        for lemma in lemmas where !entries.contains(where: { $0.word == lemma }) {
            entries += store.englishEntries(lemma).filter { $0.word.lowercased() == lemma.lowercased() }
        }
        return entries
    }

    /// Whether `word` is a single English dictionary word, or nil while the dictionary is not
    /// open yet (opening then starts in the background, so callers can fall back meanwhile).
    static func isEnglishWord(_ word: String) -> Bool? {
        let store = BuiltinDictionaryStore.shared
        guard store.isReady else {
            store.prepareInBackground()
            return nil
        }
        return !store.englishEntries(word).isEmpty || !store.englishLemmas(ofForm: word).isEmpty
    }

    /// JMdict entries for `text`, trying its dictionary forms when it is conjugated. Exact
    /// matches come first, then common words, then entries whose main writing or reading is
    /// the looked-up text, then the most specific rules (行った → 行く before 行う), then
    /// fewer steps.
    static func japaneseMatches(_ text: String) -> [JapaneseMatch] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxJapaneseLength else { return [] }

        let store = BuiltinDictionaryStore.shared
        var matches: [(match: JapaneseMatch, candidate: JapaneseDeinflector.Candidate)] = []
        var seenIDs = Set<Int>()
        for candidate in JapaneseDeinflector.candidates(for: text) {
            var lookups = [(candidate.text, candidate.wordClass)]
            // する verbs are listed as nouns marked `vs` (勉強した → 勉強する → 勉強).
            if candidate.wordClass.contains(.suru), candidate.text.hasSuffix("する"),
               candidate.text.count > 2 {
                lookups.append((String(candidate.text.dropLast(2)), .suru))
            }

            for (lookupText, wordClass) in lookups {
                for entry in store.japaneseEntries(lookupText) where !seenIDs.contains(entry.id) {
                    guard candidate.steps == 0 || wordClass.matches(partsOfSpeech: entry.partsOfSpeech)
                    else { continue }
                    seenIDs.insert(entry.id)
                    let match = JapaneseMatch(
                        entry: entry, lookupText: lookupText, isDeinflected: candidate.steps > 0
                    )
                    matches.append((match, candidate))
                }
            }
        }

        let prefersWriting = text.contains { $0.isKanji }
        // はし should list 橋, 箸 and 端 before 嘴, whose main reading is くちばし.
        func isHeadwordMatch(_ match: JapaneseMatch) -> Bool {
            let key = BuiltinDictionaryStore.normalizedJapaneseKey(match.lookupText)
            let heads = [match.entry.visibleWritings.first?.text, match.entry.visibleReadings.first?.text]
            return heads.contains { $0.map(BuiltinDictionaryStore.normalizedJapaneseKey) == key }
        }
        return matches.sorted { lhs, rhs in
            let (lhsExact, rhsExact) = (lhs.candidate.steps == 0, rhs.candidate.steps == 0)
            if lhsExact != rhsExact { return lhsExact }
            if lhs.match.entry.isCommon != rhs.match.entry.isCommon { return lhs.match.entry.isCommon }
            let (lhsHead, rhsHead) = (isHeadwordMatch(lhs.match), isHeadwordMatch(rhs.match))
            if lhsHead != rhsHead { return lhsHead }
            if lhs.candidate.specificity != rhs.candidate.specificity {
                return lhs.candidate.specificity > rhs.candidate.specificity
            }
            if lhs.candidate.steps != rhs.candidate.steps { return lhs.candidate.steps < rhs.candidate.steps }
            if prefersWriting, lhs.match.entry.matchedReading != rhs.match.entry.matchedReading {
                return !lhs.match.entry.matchedReading
            }
            return false
        }
        .prefix(maxJapaneseMatches)
        .map(\.match)
    }

    /// Whether `text` is a single Japanese word (or a conjugated form of one) in JMdict.
    /// False while the dictionary is not open yet; opening then starts in the background.
    static func isJapaneseWord(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxJapaneseLength,
              !text.contains(where: { $0.isWhitespace || $0.isPunctuation }),
              text.contains(where: { $0.isKanji || $0.isKana })
        else { return false }

        let store = BuiltinDictionaryStore.shared
        guard store.isReady else {
            store.prepareInBackground()
            return false
        }
        return !japaneseMatches(text).isEmpty
    }

    // MARK: Private

    /// Longer text is a phrase or sentence, not a dictionary word.
    private static let maxJapaneseLength = 16
}

extension Character {
    /// Hiragana, katakana (including the prolonged sound mark) or half-width katakana.
    var isKana: Bool {
        unicodeScalars.allSatisfy {
            (0x3041 ... 0x309F).contains($0.value) || (0x30A0 ... 0x30FF).contains($0.value)
                || (0xFF66 ... 0xFF9F).contains($0.value)
        }
    }
}
