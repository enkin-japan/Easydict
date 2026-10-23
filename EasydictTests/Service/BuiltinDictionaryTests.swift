//
//  BuiltinDictionaryTests.swift
//  EasydictTests
//
//  Slim build: lookups in the bundled dictionary database, Japanese deinflection and the
//  query-type routing that depends on them.
//

import Testing

@testable import Easydict

// MARK: - BuiltinDictionaryTests

@Suite("Built-in Dictionary", .tags(.unit))
struct BuiltinDictionaryTests {
    // MARK: Lifecycle

    init() {
        // Open (and extract on first run) the database so non-blocking checks see it ready.
        _ = BuiltinDictionaryStore.shared.englishEntries("a")
    }

    // MARK: Internal

    @Test("Japanese keys ignore katakana and width differences")
    func normalizedJapaneseKey() {
        #expect(BuiltinDictionaryStore.normalizedJapaneseKey("カタカナ") == "かたかな")
        #expect(BuiltinDictionaryStore.normalizedJapaneseKey("ｶﾀｶﾅ") == "かたかな")
        #expect(BuiltinDictionaryStore.normalizedJapaneseKey("食べる") == "食べる")
    }

    @Test(
        "Conjugated Japanese words find their dictionary form",
        arguments: [
            ("食べなかった", "食べる"), ("行っちゃった", "行く"), ("書かれた", "書く"),
            ("勉強した", "勉強"), ("高くない", "高い"), ("来ました", "来る"),
            ("見られている", "見る"), ("読みたい", "読む"), ("泳げる", "泳ぐ"),
            ("待って", "待つ"), ("飲もう", "飲む"), ("勉強させられた", "勉強"), ("行った", "行く"),
        ]
    )
    func japaneseDeinflection(query: String, dictionaryForm: String) throws {
        let first = try #require(BuiltinDictionary.japaneseMatches(query).first)
        #expect(first.isDeinflected)
        #expect(first.entry.writings.map(\.text).contains(dictionaryForm)
            || first.entry.readings.map(\.text).contains(dictionaryForm))
    }

    @Test("Japanese lookups carry readings, pitch accents and kanji")
    func japaneseEntry() throws {
        let entry = try #require(BuiltinDictionary.japaneseMatches("東京").first).entry
        #expect(!entry.matchedReading)
        let reading = try #require(entry.readings.first)
        #expect(reading.text == "とうきょう")
        #expect(reading.accent == "0")

        let kanji = BuiltinDictionaryStore.shared.kanji(in: "食べる")
        #expect(kanji.map(\.literal) == ["食"])
        #expect(kanji.first?.onReadings.contains("ショク") == true)
    }

    @Test("Kana-only queries list common homophones first")
    func japaneseHomophones() {
        let matches = BuiltinDictionary.japaneseMatches("はし")
        #expect(matches.count > 1)
        #expect(matches.first?.entry.isCommon == true)
        #expect(matches.allSatisfy { !$0.isDeinflected })
    }

    @Test("English inflections show their dictionary form")
    func englishLemmas() {
        let went = BuiltinDictionary.englishEntries("went").map(\.word)
        #expect(went.first == "went")
        #expect(went.contains("go"))
        #expect(BuiltinDictionary.englishEntries("Running").map(\.word).contains("run"))
    }

    @Test("English word check accepts dictionary words and rejects identifiers")
    func englishWordCheck() {
        #expect(BuiltinDictionary.isEnglishWord("username") == true)
        #expect(BuiltinDictionary.isEnglishWord("getusername") == false)
        #expect(EnglishWordChecker.isWord("LaTeX"))
        #expect(!EnglishWordChecker.isWord("viewDidLoad"))
    }

    @Test("Japanese words and sentences get dictionary and sentence analysis")
    func japaneseQueryType() {
        #expect("食べなかった".queryType(language: .japanese, maxWordCount: 1) == .dictionary)
        #expect("雨".queryType(language: .japanese, maxWordCount: 1) == .dictionary)
        #expect(
            "雨が降りそうだから、傘を持って行ったほうがいいよ。".queryType(language: .japanese, maxWordCount: 1)
                == .sentence
        )
        #expect("I can't make heads or tails of this.".queryType(language: .english, maxWordCount: 1) == .sentence)
        #expect("你好世界很大".queryType(language: .simplifiedChinese, maxWordCount: 1) == .translation)
    }
}
