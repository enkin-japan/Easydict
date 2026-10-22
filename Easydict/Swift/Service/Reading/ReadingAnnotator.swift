//
//  ReadingAnnotator.swift
//  Easydict
//
//  Slim build: offline reading annotation.
//  - Japanese: CFStringTokenizer word segmentation + per-word reading, checked and aligned
//    per kanji with the bundled JmdictFurigana data → furigana.
//  - Mandarin: forward maximum matching over the bundled phrase pinyin dictionary, falling
//    back to per-character default readings → pinyin with tones.
//  Nothing here touches the network.
//

import Foundation

// MARK: - RubySegment

struct RubySegment: Equatable {
    /// Text as it appears in the source.
    let base: String
    /// Reading to show above `base`; `nil` for plain text (kana, punctuation, Latin…).
    let reading: String?
    /// Mandarin only: the in-context reading differs from the character's default
    /// reading, i.e. this is a polyphonic character read the "other" way here.
    var isContextReading = false
    /// Mandarin only: the default (stand-alone) reading, shown in the note list.
    var defaultReading: String?
}

// MARK: - ReadingAnnotator

enum ReadingAnnotator {
    // MARK: Internal

    // MARK: Japanese

    /// Splits Japanese text into segments, attaching hiragana readings to words that contain kanji.
    static func japanese(_ text: String) -> [RubySegment] {
        let dictionary = JapaneseFuriganaDictionary.shared
        let tokens = mergingSplitKanjiWords(tokenize(text, localeIdentifier: "ja"), dictionary: dictionary)
        return tokens.flatMap { token -> [RubySegment] in
            guard token.isWord, containsKanji(token.surface), let reading = token.reading else {
                return [RubySegment(base: token.surface, reading: nil)]
            }
            return furiganaSegments(surface: token.surface, reading: reading, dictionary: dictionary)
        }
    }

    // MARK: Mandarin

    /// Splits Chinese text into segments with tone-marked pinyin per character, reading
    /// polyphonic characters by the dictionary phrase they belong to.
    static func mandarin(_ text: String) -> [RubySegment] {
        let dictionary = ChinesePinyinDictionary.shared
        let characters = Array(text)
        var segments: [RubySegment] = []
        var index = 0

        while index < characters.count {
            var runEnd = index
            let isHanRun = isHan(characters[index])
            while runEnd < characters.count, isHan(characters[runEnd]) == isHanRun {
                runEnd += 1
            }
            let run = Array(characters[index ..< runEnd])
            index = runEnd

            guard isHanRun else {
                segments.append(RubySegment(base: String(run), reading: nil))
                continue
            }
            for word in segmentHanRun(run, dictionary: dictionary) {
                if let syllables = word.syllables {
                    for (character, syllable) in zip(word.characters, syllables) {
                        segments.append(mandarinSegment(character, reading: syllable, dictionary: dictionary))
                    }
                } else if let character = word.characters.first {
                    let reading = dictionary.defaultReading(of: character) ?? pinyin(String(character))
                    segments.append(RubySegment(base: String(character), reading: reading))
                }
            }
        }
        return segments
    }

    // MARK: Character classes

    static func containsKanji(_ text: String) -> Bool {
        containsHan(text)
    }

    static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isHan)
    }

    static func containsKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040 ... 0x30FF).contains($0.value) }
    }

    // MARK: Private

    private struct Token {
        let surface: String
        let isWord: Bool
        /// Hiragana reading derived from the tokenizer's Latin transcription.
        let reading: String?
    }

    /// A dictionary phrase with its syllables, or a single character (`syllables == nil`).
    private struct HanWord {
        let characters: ArraySlice<Character>
        let syllables: [String]?
    }

    /// Tokens of at most this many characters are short enough to be fragments of one word.
    private static let maxMergedWordLength = 4

    /// Tokenizes `text`, returning every word token plus the gaps between them,
    /// so that concatenating all surfaces reproduces the input exactly.
    private static func tokenize(_ text: String, localeIdentifier: String) -> [Token] {
        let nsText = text as NSString
        let cfText = text as CFString
        let fullRange = CFRange(location: 0, length: nsText.length)
        let locale = Locale(identifier: localeIdentifier) as CFLocale

        guard let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault, cfText, fullRange, kCFStringTokenizerUnitWordBoundary, locale
        ) else {
            return [Token(surface: text, isWord: false, reading: nil)]
        }

        var tokens: [Token] = []
        var cursor = 0
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while !tokenType.isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if range.location > cursor {
                let gap = nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))
                tokens.append(Token(surface: gap, isWord: false, reading: nil))
            }
            let surface = nsText.substring(with: NSRange(location: range.location, length: range.length))
            let attribute = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription
            )
            let latin = (attribute as? NSString) as String?
            tokens.append(Token(surface: surface, isWord: true, reading: latin.flatMap(hiragana(fromRomaji:))))
            cursor = range.location + range.length
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        if cursor < nsText.length {
            let tail = nsText.substring(from: cursor)
            tokens.append(Token(surface: tail, isWord: false, reading: nil))
        }
        return tokens
    }

    /// Re-joins adjacent pure-kanji tokens that the tokenizer split inside one dictionary word,
    /// e.g. 二|日 read ふた|か → 二日 ふつか. The split readings are kept when they already form
    /// one of the word's dictionary readings; otherwise the most common dictionary reading wins.
    private static func mergingSplitKanjiWords(
        _ tokens: [Token],
        dictionary: JapaneseFuriganaDictionary
    )
        -> [Token] {
        func isKanjiFragment(_ token: Token) -> Bool {
            token.isWord && token.surface.count <= maxMergedWordLength
                && token.surface.unicodeScalars.allSatisfy(isHan)
        }

        var merged: [Token] = []
        var index = 0
        while index < tokens.count {
            var combined: Token?
            if isKanjiFragment(tokens[index]) {
                var runEnd = index
                while runEnd < tokens.count, isKanjiFragment(tokens[runEnd]) {
                    runEnd += 1
                }
                for end in stride(from: runEnd, through: index + 2, by: -1) {
                    let run = tokens[index ..< end]
                    let surface = run.map(\.surface).joined()
                    guard surface.count <= maxMergedWordLength,
                          let fallback = dictionary.entries(for: surface).first
                    else { continue }
                    let splitReading = run.compactMap(\.reading).joined()
                    let reading = dictionary.entry(for: surface, reading: splitReading)?.reading ?? fallback.reading
                    combined = Token(surface: surface, isWord: true, reading: reading)
                    index = end
                    break
                }
            }
            if let combined {
                merged.append(combined)
            } else {
                merged.append(tokens[index])
                index += 1
            }
        }
        return merged
    }

    /// Furigana for one word: dictionary alignment per kanji when the word's reading is known,
    /// otherwise the okurigana heuristic. A reading the dictionary does not list for an exact
    /// headword is replaced by the dictionary's most common reading.
    private static func furiganaSegments(
        surface: String,
        reading: String,
        dictionary: JapaneseFuriganaDictionary
    )
        -> [RubySegment] {
        let entry = dictionary.entry(for: surface, reading: reading) ?? dictionary.entries(for: surface).first
        if let entry, let segments = entry.segments(for: surface) {
            return segments
        }
        return splitOkurigana(surface: surface, reading: entry?.reading ?? reading)
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005, 0x3007, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF, 0x20000 ... 0x2FA1F:
            true // CJK ideographs, compatibility ideographs, 々, 〇
        default:
            false
        }
    }

    private static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.first.map(isHan) ?? false
    }

    /// Converts the tokenizer's romaji to hiragana. Returns nil if the result still contains Latin letters.
    private static func hiragana(fromRomaji romaji: String) -> String? {
        var latin = romaji.lowercased()
        // Hepburn macrons → kana-friendly doubled vowels.
        let macrons: [String: String] = [
            "ā": "aa",
            "ī": "ii",
            "ū": "uu",
            "ē": "ee",
            "ō": "ou",
            "â": "aa",
            "î": "ii",
            "û": "uu",
            "ê": "ee",
            "ô": "ou",
        ]
        for (macron, plain) in macrons {
            latin = latin.replacingOccurrences(of: macron, with: plain)
        }
        latin = latin.replacingOccurrences(of: " ", with: "")

        let mutable = NSMutableString(string: latin)
        guard CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformLatinHiragana, false) else {
            return nil
        }
        let result = mutable as String
        if result.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) && $0.isASCII }) {
            return nil
        }
        return result
    }

    /// Converts katakana to hiragana so okurigana can be compared with the reading.
    private static func toHiragana(_ text: String) -> String {
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformHiraganaKatakana, true)
        return mutable as String
    }

    /// Moves leading / trailing kana that also appear in the reading out of the ruby,
    /// e.g. 食べる/たべる → 食(た) + べる, お茶/おちゃ → お + 茶(ちゃ).
    private static func splitOkurigana(surface: String, reading: String) -> [RubySegment] {
        var base = Array(surface)
        var kana = Array(reading)
        var prefix: [Character] = []
        var suffix: [Character] = []

        func isKana(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { (0x3040 ... 0x30FF).contains($0.value) }
        }
        func same(_ lhs: Character, _ rhs: Character) -> Bool {
            toHiragana(String(lhs)) == toHiragana(String(rhs))
        }

        while let last = base.last, let lastKana = kana.last, isKana(last), same(last, lastKana), base.count > 1 {
            suffix.insert(base.removeLast(), at: 0)
            kana.removeLast()
        }
        while let first = base.first, let firstKana = kana.first, isKana(first), same(first, firstKana),
              base.count > 1 {
            prefix.append(base.removeFirst())
            kana.removeFirst()
        }

        var segments: [RubySegment] = []
        if !prefix.isEmpty {
            segments.append(RubySegment(base: String(prefix), reading: nil))
        }
        segments.append(RubySegment(base: String(base), reading: kana.isEmpty ? nil : String(kana)))
        if !suffix.isEmpty {
            segments.append(RubySegment(base: String(suffix), reading: nil))
        }
        return segments
    }

    /// Bidirectional maximum matching: segments the run forwards and backwards and keeps the
    /// result with fewer words, then fewer single characters, preferring the backward pass on
    /// a tie (会长期 → 会|长期 rather than 会长|期).
    private static func segmentHanRun(_ run: [Character], dictionary: ChinesePinyinDictionary) -> [HanWord] {
        func phrase(_ range: Range<Int>) -> HanWord? {
            guard range.count >= 2,
                  let syllables = dictionary.syllables(forPhrase: String(run[range])),
                  syllables.count == range.count
            else { return nil }
            return HanWord(characters: run[range], syllables: syllables)
        }
        func single(_ index: Int) -> HanWord {
            HanWord(characters: run[index ... index], syllables: nil)
        }

        var forward: [HanWord] = []
        var start = 0
        while start < run.count {
            let longest = min(dictionary.maxPhraseLength, run.count - start)
            let word = stride(from: longest, through: 2, by: -1).lazy
                .compactMap { phrase(start ..< start + $0) }.first ?? single(start)
            forward.append(word)
            start += word.characters.count
        }

        var backward: [HanWord] = []
        var end = run.count
        while end > 0 {
            let longest = min(dictionary.maxPhraseLength, end)
            let word = stride(from: longest, through: 2, by: -1).lazy
                .compactMap { phrase(end - $0 ..< end) }.first ?? single(end - 1)
            backward.insert(word, at: 0)
            end -= word.characters.count
        }

        func singles(_ words: [HanWord]) -> Int {
            words.filter { $0.characters.count == 1 }.count
        }
        if forward.count != backward.count {
            return forward.count < backward.count ? forward : backward
        }
        return singles(forward) < singles(backward) ? forward : backward
    }

    /// One character of a dictionary phrase. It is marked as a context reading when the phrase
    /// reads it differently from its default reading, except for a mere neutral tone
    /// (桌子 zi, 东西 xi), which would flag almost every compound.
    private static func mandarinSegment(
        _ character: Character,
        reading: String,
        dictionary: ChinesePinyinDictionary
    )
        -> RubySegment {
        var segment = RubySegment(base: String(character), reading: reading)
        guard let standalone = dictionary.defaultReading(of: character) ?? pinyin(String(character)),
              standalone.lowercased() != reading.lowercased()
        else { return segment }

        let isNeutralToneOnly = !hasToneMark(reading)
            && standalone.folding(options: .diacriticInsensitive, locale: nil)
            == reading.folding(options: .diacriticInsensitive, locale: nil)
        if !isNeutralToneOnly {
            segment.isContextReading = true
            segment.defaultReading = standalone
        }
        return segment
    }

    private static func hasToneMark(_ syllable: String) -> Bool {
        syllable.contains { "āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ".contains($0) }
    }

    private static func pinyin(_ text: String) -> String? {
        let mutable = NSMutableString(string: text)
        guard CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformMandarinLatin, false) else {
            return nil
        }
        let result = (mutable as String).trimmingCharacters(in: .whitespaces)
        return result.isEmpty || result == text ? nil : result
    }
}
