//
//  EnglishWordChecker.swift
//  Easydict
//
//  Slim build: decides whether text is a real English word, e.g. so that a selected
//  `getUserName` is split into words while `username` is kept. Backed by the system
//  spelling dictionaries; this is the one place to switch to a bundled dictionary later.
//

import Foundation

enum EnglishWordChecker {
    // MARK: Internal

    /// Whether `text` is a single English word, in US or British spelling.
    ///
    /// The check is case-insensitive: the spell checker accepts any mixed-case word such as
    /// `viewDidLoad`, so the lowercased form is checked instead.
    static func isWord(_ text: String) -> Bool {
        let word = text.lowercased()
        guard !word.isEmpty, word.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "-" }) else {
            return false
        }
        // Query text is also handled off the main thread; one serial queue keeps the
        // shared spell checker from being used by two threads at once.
        return queue.sync {
            languages.contains { word.isSpelledCorrectly(language: $0) }
        }
    }

    // MARK: Private

    private static let languages = ["en", "en_GB"]
    private static let queue = DispatchQueue(label: "com.izual.Easydict.english-word-checker")
}
