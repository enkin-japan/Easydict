//
//  ReadingAnnotator.swift
//  Easydict
//
//  Slim build: offline reading annotation using the system's own linguistic data.
//  - Japanese: CFStringTokenizer word segmentation + per-word reading → furigana.
//  - Mandarin: ICU Han→Latin transform per word (phrase-aware) → pinyin with tones.
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
        tokenize(text, localeIdentifier: "ja").flatMap { token -> [RubySegment] in
            guard token.isWord, containsKanji(token.surface),
                  let latin = token.latinTranscription,
                  let reading = hiragana(fromRomaji: latin)
            else {
                return [RubySegment(base: token.surface, reading: nil)]
            }
            return splitOkurigana(surface: token.surface, reading: reading)
        }
    }

    // MARK: Mandarin

    /// Splits Chinese text into segments with tone-marked pinyin per character.
    static func mandarin(_ text: String) -> [RubySegment] {
        tokenize(text, localeIdentifier: "zh-Hans").flatMap { token -> [RubySegment] in
            guard token.isWord, containsHan(token.surface) else {
                return [RubySegment(base: token.surface, reading: nil)]
            }
            return pinyinSegments(forWord: token.surface)
        }
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
        let latinTranscription: String?
    }

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
            return [Token(surface: text, isWord: false, latinTranscription: nil)]
        }

        var tokens: [Token] = []
        var cursor = 0
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while !tokenType.isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if range.location > cursor {
                let gap = nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))
                tokens.append(Token(surface: gap, isWord: false, latinTranscription: nil))
            }
            let surface = nsText.substring(with: NSRange(location: range.location, length: range.length))
            let attribute = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription
            )
            let latin = (attribute as? NSString) as String?
            tokens.append(Token(surface: surface, isWord: true, latinTranscription: latin))
            cursor = range.location + range.length
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        if cursor < nsText.length {
            let tail = nsText.substring(from: cursor)
            tokens.append(Token(surface: tail, isWord: false, latinTranscription: nil))
        }
        return tokens
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005, 0x3007, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF, 0x20000 ... 0x2FA1F:
            true // CJK ideographs, compatibility ideographs, 々, 〇
        default:
            false
        }
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

    /// Tone-marked pinyin for a Chinese word, split per character when syllables line up.
    private static func pinyinSegments(forWord word: String) -> [RubySegment] {
        guard let wordPinyin = pinyin(word) else {
            return [RubySegment(base: word, reading: nil)]
        }

        let characters = Array(word)
        let syllables = wordPinyin.split(whereSeparator: \.isWhitespace).map(String.init)
        let hanCount = characters.filter { containsHan(String($0)) }.count

        guard hanCount == characters.count, syllables.count == characters.count else {
            // Mixed content or unexpected syllabification: annotate the whole word.
            return [RubySegment(base: word, reading: wordPinyin)]
        }

        return zip(characters, syllables).map { character, syllable in
            var segment = RubySegment(base: String(character), reading: syllable)
            if characters.count > 1, let standalone = pinyin(String(character)),
               standalone.lowercased() != syllable.lowercased() {
                segment.isContextReading = true
                segment.defaultReading = standalone
            }
            return segment
        }
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
