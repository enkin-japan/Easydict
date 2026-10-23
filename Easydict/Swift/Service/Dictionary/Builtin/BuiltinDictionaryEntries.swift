//
//  BuiltinDictionaryEntries.swift
//  Easydict
//
//  Slim build: rows of the bundled dictionary database. Japanese and kanji rows are stored
//  as compact JSON; the field names are those written by scripts/builtin-dict/generate.py.
//

import Foundation

// MARK: - EnglishDictionaryEntry

/// An ECDICT entry.
struct EnglishDictionaryEntry: Sendable {
    // MARK: Internal

    /// One `exchange` item, e.g. the past tense `ran` of `run`.
    struct Inflection: Sendable {
        let code: String
        let form: String
    }

    let word: String
    /// IPA without slashes, mostly British, e.g. `rʌn`. May be empty.
    let phonetic: String
    /// Chinese translation, one part of speech per line, e.g. `n. 跑\nv. 跑；运转`.
    let translation: String
    /// English definition (mostly WordNet), only for words with frequency data.
    let definition: String
    let partOfSpeech: String
    /// Collins star rating, 0 to 5.
    let collins: Int
    let isOxford3000: Bool
    /// Space-separated exam tags, e.g. `zk gk cet4`.
    let tags: String
    let bncRank: Int
    let frequencyRank: Int
    let exchange: String

    /// Inflected forms of this word (`p`, `d`, `i`, `3`, `r`, `t`, `s` codes).
    var inflections: [Inflection] {
        exchangeItems.filter { !["0", "1"].contains($0.code) && $0.form != word }
    }

    /// The dictionary form this word is an inflection of, e.g. `go` for `went`.
    var lemma: String? {
        exchangeItems.first { $0.code == "0" }?.form.nilIfEmpty.flatMap { $0 == word ? nil : $0 }
    }

    /// How this word inflects its lemma, as `exchange` codes, e.g. `["p", "d"]` for `went`.
    var lemmaInflectionCodes: [String] {
        guard let codes = exchangeItems.first(where: { $0.code == "1" })?.form else { return [] }
        return codes.map(String.init)
    }

    // MARK: Private

    private var exchangeItems: [Inflection] {
        exchange.split(separator: "/").compactMap { item in
            let parts = item.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return Inflection(code: String(parts[0]), form: String(parts[1]))
        }
    }
}

// MARK: - JapaneseDictionaryEntry

/// A JMdict entry with Kanjium pitch accents attached to its readings.
struct JapaneseDictionaryEntry: Sendable {
    // MARK: Lifecycle

    init?(id: Int, isCommon: Bool, json: String, matchedReading: Bool) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        else { return nil }

        self.id = id
        self.isCommon = isCommon
        self.matchedReading = matchedReading
        self.writings = (object["k"] as? [[Any]] ?? []).map { item in
            Writing(
                text: item.first as? String ?? "",
                isCommon: (item[safe: 1] as? Int ?? 0) > 0,
                tags: item[safe: 2] as? [String] ?? []
            )
        }
        self.readings = (object["r"] as? [[Any]] ?? []).map { item in
            Reading(
                text: item.first as? String ?? "",
                isCommon: (item[safe: 1] as? Int ?? 0) > 0,
                accent: (item[safe: 2] as? String)?.nilIfEmpty,
                appliesToWritings: item[safe: 3] as? [String] ?? ["*"],
                tags: item[safe: 4] as? [String] ?? []
            )
        }
        self.senses = (object["s"] as? [[String: Any]] ?? []).map { item in
            Sense(
                partsOfSpeech: item["p"] as? [String] ?? [],
                glosses: item["g"] as? [String] ?? [],
                misc: item["m"] as? [String] ?? [],
                fields: item["f"] as? [String] ?? [],
                dialects: item["d"] as? [String] ?? [],
                info: item["i"] as? [String] ?? [],
                appliesToWritings: item["ak"] as? [String] ?? ["*"],
                appliesToReadings: item["ar"] as? [String] ?? ["*"],
                examples: (item["x"] as? [[String]] ?? []).compactMap { pair in
                    pair.count == 2 ? Example(japanese: pair[0], english: pair[1]) : nil
                }
            )
        }
    }

    // MARK: Internal

    struct Writing: Sendable {
        let text: String
        let isCommon: Bool
        /// JMdict tags such as `rK` (rarely used kanji form) or `sK` (search-only form).
        let tags: [String]
    }

    struct Reading: Sendable {
        let text: String
        let isCommon: Bool
        /// Kanjium accent, e.g. `0`, `0,2` or `(副)1,(形動)0`.
        let accent: String?
        /// The writings this reading belongs to, or `["*"]` for all of them.
        let appliesToWritings: [String]
        let tags: [String]

        func applies(to writing: String?) -> Bool {
            guard let writing else { return true }
            return appliesToWritings == ["*"] || appliesToWritings.contains(writing)
        }
    }

    struct Example: Sendable {
        let japanese: String
        let english: String
    }

    struct Sense: Sendable {
        let partsOfSpeech: [String]
        let glosses: [String]
        let misc: [String]
        let fields: [String]
        let dialects: [String]
        let info: [String]
        let appliesToWritings: [String]
        let appliesToReadings: [String]
        let examples: [Example]
    }

    let id: Int
    let isCommon: Bool
    /// Whether the lookup key matched a reading rather than a written form.
    let matchedReading: Bool
    let writings: [Writing]
    let readings: [Reading]
    let senses: [Sense]

    var partsOfSpeech: Set<String> {
        Set(senses.flatMap(\.partsOfSpeech))
    }

    /// Writings to show, without search-only forms.
    var visibleWritings: [Writing] {
        writings.filter { !$0.tags.contains("sK") }
    }

    /// Readings to show, without search-only forms.
    var visibleReadings: [Reading] {
        readings.filter { !$0.tags.contains("sk") }
    }
}

// MARK: - KanjiDictionaryEntry

/// A KANJIDIC2 character.
struct KanjiDictionaryEntry: Sendable {
    // MARK: Lifecycle

    init?(literal: String, json: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        else { return nil }

        self.literal = literal
        self.onReadings = object["on"] as? [String] ?? []
        self.kunReadings = object["kun"] as? [String] ?? []
        self.pinyin = object["py"] as? [String] ?? []
        self.meanings = object["m"] as? [String] ?? []
        self.grade = object["g"] as? Int
        self.jlptLevel = object["j"] as? Int
        self.frequencyRank = object["f"] as? Int
        self.strokeCount = object["s"] as? Int
    }

    // MARK: Internal

    let literal: String
    /// Katakana, e.g. `ショク`.
    let onReadings: [String]
    /// Hiragana with `.` before okurigana, e.g. `た.べる`.
    let kunReadings: [String]
    /// Numbered pinyin, e.g. `shi2`.
    let pinyin: [String]
    let meanings: [String]
    let grade: Int?
    /// Old (pre-2010) JLPT level, 1 to 4.
    let jlptLevel: Int?
    let frequencyRank: Int?
    let strokeCount: Int?
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
