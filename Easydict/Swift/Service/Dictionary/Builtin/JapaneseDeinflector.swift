//
//  JapaneseDeinflector.swift
//  Easydict
//
//  Slim build: turns conjugated Japanese verbs and i-adjectives back into dictionary forms
//  (食べなかった → 食べる, 行っちゃった → 行く) so they can be looked up in JMdict.
//  Each rule replaces a suffix; rules chain, and every candidate carries the word class it
//  must have, which the caller checks against the entry's parts of speech.
//

import Foundation

// MARK: - JapaneseDeinflector

enum JapaneseDeinflector {
    // MARK: Internal

    /// Word classes a candidate can be. A rule applies to a form whose class intersects the
    /// rule's input; the text as given matches every rule.
    struct WordClass: OptionSet, Hashable, Sendable {
        static let ichidan = WordClass(rawValue: 1 << 0)
        static let godan = WordClass(rawValue: 1 << 1)
        static let suru = WordClass(rawValue: 1 << 2)
        static let kuru = WordClass(rawValue: 1 << 3)
        static let adjectiveI = WordClass(rawValue: 1 << 4)
        /// Polite ます forms, which conjugate further (ました, ません).
        static let masu = WordClass(rawValue: 1 << 5)
        /// て forms, which take auxiliaries (ている, てしまう).
        static let te = WordClass(rawValue: 1 << 6)

        static let verbs: WordClass = [.ichidan, .godan, .suru, .kuru]
        static let dictionaryForms: WordClass = [.verbs, .adjectiveI]

        let rawValue: Int

        /// Whether a JMdict entry with these parts of speech can have this class.
        func matches(partsOfSpeech: Set<String>) -> Bool {
            partsOfSpeech.contains { pos in
                (contains(.ichidan) && pos.hasPrefix("v1"))
                    || (contains(.godan) && pos.hasPrefix("v5"))
                    || (contains(.suru) && pos.hasPrefix("vs"))
                    || (contains(.kuru) && pos == "vk")
                    || (contains(.adjectiveI) && (pos == "adj-i" || pos == "adj-ix"))
            }
        }
    }

    struct Candidate: Hashable, Sendable {
        let text: String
        /// Word class the dictionary entry must have; empty for the text as given.
        let wordClass: WordClass
        /// Number of rules applied.
        let steps: Int
        /// Total length of the suffixes the rules replaced. Specific rules replace longer
        /// suffixes (行った → 行く beats った → う), so a higher value is a likelier reading.
        let specificity: Int
    }

    /// The text itself followed by every dictionary-form candidate, fewest steps first.
    static func candidates(for text: String) -> [Candidate] {
        var results = [Candidate(text: text, wordClass: [], steps: 0, specificity: 0)]
        var seen: Set<String> = [text]
        var frontier = results
        for _ in 0 ..< maxSteps {
            var next: [Candidate] = []
            for candidate in frontier {
                for rule in rules where candidate.text.hasSuffix(rule.from)
                    && (candidate.steps == 0 || !candidate.wordClass.isDisjoint(with: rule.input)) {
                    let stem = candidate.text.dropLast(rule.from.count)
                    let text = String(stem) + rule.to
                    guard !text.isEmpty, seen.insert("\(text)|\(rule.output.rawValue)").inserted else {
                        continue
                    }
                    next.append(Candidate(
                        text: text,
                        wordClass: rule.output,
                        steps: candidate.steps + 1,
                        specificity: candidate.specificity + rule.from.count
                    ))
                }
            }
            results += next
            frontier = next
            if frontier.isEmpty { break }
        }

        // Only dictionary forms (and the original text) are worth a lookup.
        return results.filter { $0.steps == 0 || !$0.wordClass.isDisjoint(with: .dictionaryForms) }
    }

    // MARK: Private

    private struct Rule {
        let from: String
        let to: String
        let input: WordClass
        let output: WordClass
    }

    private static let maxSteps = 6

    /// Godan endings by row: (う-column ending, い-column, あ-column, え-column, お-column).
    private static let godanRows: [(u: String, i: String, a: String, e: String, o: String)] = [
        ("う", "い", "わ", "え", "お"), ("く", "き", "か", "け", "こ"), ("ぐ", "ぎ", "が", "げ", "ご"),
        ("す", "し", "さ", "せ", "そ"), ("つ", "ち", "た", "て", "と"), ("ぬ", "に", "な", "ね", "の"),
        ("ぶ", "び", "ば", "べ", "ぼ"), ("む", "み", "ま", "め", "も"), ("る", "り", "ら", "れ", "ろ"),
    ]

    /// Godan て/た forms: (ending before て or た, dictionary ending, voiced).
    private static let godanTeEndings: [(stem: String, u: String, voiced: Bool)] = [
        ("い", "く", false), ("い", "ぐ", true), ("し", "す", false), ("っ", "う", false),
        ("っ", "つ", false), ("っ", "る", false), ("ん", "ぬ", true), ("ん", "ぶ", true),
        ("ん", "む", true),
    ]

    private static let rules: [Rule] = {
        var rules: [Rule] = []
        func add(_ from: String, _ to: String, _ input: WordClass, _ output: WordClass) {
            rules.append(Rule(from: from, to: to, input: input, output: output))
        }

        // Endings built on a base: ichidan drops る, godan changes the final kana's column,
        // and する / くる are irregular.
        func addVerbEndings(
            _ ending: String,
            input: WordClass,
            godanColumn: KeyPath<(u: String, i: String, a: String, e: String, o: String), String>?,
            suru: String?,
            kuru: String?,
            ichidan: Bool = true
        ) {
            if ichidan { add(ending, "る", input, .ichidan) }
            if let godanColumn {
                for row in godanRows {
                    // The あ-column of う verbs is わ (買わない).
                    add(row[keyPath: godanColumn] + ending, row.u, input, .godan)
                }
            }
            if let suru { add(suru + ending, "する", input, .suru) }
            if let kuru {
                add(kuru + ending, "くる", input, .kuru)
                add("来" + ending, "来る", input, .kuru)
            }
        }

        let any: WordClass = [.dictionaryForms, .masu, .te]

        // Polite: 食べます, 食べました, 食べません, 食べましょう.
        addVerbEndings("ます", input: .masu, godanColumn: \.i, suru: "し", kuru: "き")
        add("ました", "ます", any, .masu)
        add("ません", "ます", any, .masu)
        add("ませんでした", "ます", any, .masu)
        add("ましょう", "ます", any, .masu)
        add("まして", "ます", any, .masu)

        // Past and て forms share their stems; only て forms take auxiliaries (ている).
        for (suffix, voicedSuffix) in [("た", "だ"), ("て", "で")] {
            let input: WordClass = suffix == "て" ? .te : any
            add(suffix, "る", input, .ichidan)
            for ending in godanTeEndings {
                add(ending.stem + (ending.voiced ? voicedSuffix : suffix), ending.u, input, .godan)
            }
            add("行っ" + suffix, "行く", input, .godan)
            add("いっ" + suffix, "いく", input, .godan)
            add("し" + suffix, "する", input, .suru)
            add("き" + suffix, "くる", input, .kuru)
            add("来" + suffix, "来る", input, .kuru)
            add("かっ" + suffix, "い", input, .adjectiveI)
        }
        add("くて", "い", any, .adjectiveI)
        add("たら", "た", any, .dictionaryForms)
        add("だら", "だ", any, .dictionaryForms)
        add("たり", "た", any, .dictionaryForms)
        add("だり", "だ", any, .dictionaryForms)

        // Negative (conjugates like an い-adjective) and classical ず.
        addVerbEndings("ない", input: .adjectiveI, godanColumn: \.a, suru: "し", kuru: "こ")
        addVerbEndings("ず", input: any, godanColumn: \.a, suru: "せ", kuru: "こ")
        add("くない", "い", .adjectiveI, .adjectiveI)
        add("なくて", "ない", any, .adjectiveI)
        add("ないで", "ない", any, .adjectiveI)

        // Desire たい (conjugates like an い-adjective).
        addVerbEndings("たい", input: .adjectiveI, godanColumn: \.i, suru: "し", kuru: "き")

        // Passive, potential and causative all conjugate like ichidan verbs.
        add("られる", "る", .ichidan, .ichidan)
        addVerbEndings("れる", input: .ichidan, godanColumn: \.a, suru: "さ", kuru: "こら", ichidan: false)
        addVerbEndings("せる", input: .ichidan, godanColumn: \.a, suru: "さ", kuru: "こさ", ichidan: false)
        add("させる", "る", .ichidan, .ichidan)
        addVerbEndings("る", input: .ichidan, godanColumn: \.e, suru: nil, kuru: nil, ichidan: false)
        add("できる", "する", .ichidan, .suru)

        // Volitional, conditional and imperative.
        add("よう", "る", any, .ichidan)
        for row in godanRows {
            add(row.o + "う", row.u, any, .godan)
            add(row.e + "ば", row.u, any, .godan)
            add(row.e, row.u, any, .godan)
        }
        add("しよう", "する", any, .suru)
        add("こよう", "くる", any, .kuru)
        add("れば", "る", any, .ichidan)
        add("すれば", "する", any, .suru)
        add("くれば", "くる", any, .kuru)
        add("ければ", "い", any, .adjectiveI)
        add("ろ", "る", any, .ichidan)
        add("しろ", "する", any, .suru)
        add("こい", "くる", any, .kuru)

        // い-adjective forms: adverbial, noun and "looks like".
        add("く", "い", any, .adjectiveI)
        add("さ", "い", any, .adjectiveI)
        add("そう", "い", any, .adjectiveI)

        // Auxiliaries after て: ている / てる, てしまう / ちゃう, ておく / とく, てある.
        add("ている", "て", .ichidan, .te)
        add("てる", "て", .ichidan, .te)
        add("でいる", "で", .ichidan, .te)
        add("でる", "で", .ichidan, .te)
        add("てしまう", "て", .godan, .te)
        add("でしまう", "で", .godan, .te)
        add("ちゃう", "て", .godan, .te)
        add("じゃう", "で", .godan, .te)
        add("ておく", "て", .godan, .te)
        add("とく", "て", .godan, .te)
        add("どく", "で", .godan, .te)
        add("てある", "て", .godan, .te)

        return rules
    }()
}
