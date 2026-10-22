//
//  JapaneseFuriganaDictionary.swift
//  Easydict
//
//  Slim build: per-kanji furigana for JMdict words, from Doublevil/JmdictFurigana (MIT),
//  derived from JMdict (EDRDG, CC BY-SA 4.0). Loaded lazily on first use.
//

import Foundation

// MARK: - FuriganaEntry

struct FuriganaEntry: Sendable {
    /// Whole-word reading in hiragana, e.g. `とりあつかい`.
    let reading: String
    /// Kana attached to character ranges, e.g. `0:と;2:あつか` or `0-1:ふつか`.
    let furigana: String

    /// Ruby segments for `surface`, or nil if the furigana does not fit it.
    func segments(for surface: String) -> [RubySegment]? {
        let characters = Array(surface)
        var parts: [(range: ClosedRange<Int>, kana: String)] = []
        for part in furigana.split(separator: ";") {
            let pair = part.split(separator: ":", maxSplits: 1)
            guard pair.count == 2 else { return nil }
            let bounds = pair[0].split(separator: "-").compactMap { Int($0) }
            guard let lower = bounds.first, let upper = bounds.last, bounds.count <= 2,
                  lower <= upper, upper < characters.count
            else { return nil }
            parts.append((lower ... upper, String(pair[1])))
        }

        var segments: [RubySegment] = []
        var cursor = 0
        for part in parts.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            guard part.range.lowerBound >= cursor else { return nil }
            if part.range.lowerBound > cursor {
                segments.append(RubySegment(base: String(characters[cursor ..< part.range.lowerBound]), reading: nil))
            }
            segments.append(RubySegment(base: String(characters[part.range]), reading: part.kana))
            cursor = part.range.upperBound + 1
        }
        if cursor < characters.count {
            segments.append(RubySegment(base: String(characters[cursor...]), reading: nil))
        }
        return segments
    }
}

// MARK: - JapaneseFuriganaDictionary

final class JapaneseFuriganaDictionary: Sendable {
    // MARK: Lifecycle

    private init() {
        self.table = ReadingTable(resourceName: "ja-furigana")
    }

    // MARK: Internal

    static let shared = JapaneseFuriganaDictionary()

    /// All dictionary readings of `surface`, most common first (JMdict order).
    func entries(for surface: String) -> [FuriganaEntry] {
        table.values(for: surface).compactMap { value in
            let fields = value.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2 else { return nil }
            return FuriganaEntry(reading: String(fields[0]), furigana: String(fields[1]))
        }
    }

    /// The entry whose reading matches `reading`, treating the tokenizer's `ō`
    /// (always rendered as おう) as matching either おう or おお.
    func entry(for surface: String, reading: String) -> FuriganaEntry? {
        let candidates = entries(for: surface)
        if let exact = candidates.first(where: { $0.reading == reading }) {
            return exact
        }
        let key = Self.foldingLongO(reading)
        return candidates.first { Self.foldingLongO($0.reading) == key }
    }

    // MARK: Private

    /// Kana whose vowel is "o"; a following お or う lengthens it.
    private static let oRowKana: Set<Character> = Set("おこごそぞとどのほぼぽもよょろを")

    /// Rows of `headword\treading\tfurigana`, several per headword when it has more readings.
    private let table: ReadingTable

    /// Rewrites a long "o" written with お (おおきい, とおり) as う so both spellings compare equal.
    private static func foldingLongO(_ reading: String) -> String {
        var result = ""
        var previous: Character?
        for character in reading {
            if character == "お", let previous, oRowKana.contains(previous) {
                result.append("う")
            } else {
                result.append(character)
            }
            previous = character
        }
        return result
    }
}
