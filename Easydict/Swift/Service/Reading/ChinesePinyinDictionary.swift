//
//  ChinesePinyinDictionary.swift
//  Easydict
//
//  Slim build: phrase and character pinyin tables from mozillazg/phrase-pinyin-data
//  and mozillazg/pinyin-data (MIT). Loaded lazily on first use and immutable afterwards.
//

import Foundation

// MARK: - ChinesePinyinDictionary

final class ChinesePinyinDictionary: Sendable {
    // MARK: Lifecycle

    private init() {
        self.phrases = ReadingTable(resourceName: "zh-phrases")
        self.characters = ReadingTable(resourceName: "zh-characters")
    }

    // MARK: Internal

    static let shared = ChinesePinyinDictionary()

    /// Longest phrase (in characters) worth trying during maximum matching. Idioms and set
    /// phrases rarely exceed this; longer dictionary entries are full sentences.
    let maxPhraseLength = 12

    /// Tone-marked syllables for a multi-character phrase, one per character.
    func syllables(forPhrase phrase: String) -> [String]? {
        phrases.values(for: phrase).first?.split(separator: " ").map(String.init)
    }

    /// The most common reading of a single character.
    func defaultReading(of character: Character) -> String? {
        characters.values(for: String(character)).first
    }

    // MARK: Private

    private let phrases: ReadingTable
    private let characters: ReadingTable
}
