//
//  String+WordComponents.swift
//  Easydict
//
//  Created by tisfeng on 2025/6/24.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation

extension String {
    /// Count the number of English words in the text string.
    var englishWordCount: Int {
        let englishWords = wordComponents.filter { $0.removingNonLetters().isEnglishText }
        return englishWords.count
    }

    /// Splits the string into word components, preserving the original order of appearance.
    ///
    /// - Chinese characters are treated as individual words.
    /// - Non-Chinese characters (e.g., English words or numbers) are grouped together until a character of a different type or a separator is encountered.
    /// - Whitespace and most punctuation marks act as separators and are excluded from the result.
    ///
    /// - Returns: An array of word components in the order they appear in the original string.
    ///
    /// - Examples:
    ///   - `"Hello, world!"` → `["Hello", "world"]`
    ///   - `"scpl.example.com"` → `["scpl.example.com"]`
    ///   - `"包括Google翻译、DeepL翻译等"` → `["包", "括", "Google", "翻", "译", "DeepL", "翻", "译", "等"]`
    var wordComponents: [String] {
        // Create a character set that includes whitespace, newlines, and punctuation
        var separatorSet = CharacterSet.whitespacesAndNewlines
        separatorSet.formUnion(.punctuationCharacters)

        // Exclude specific characters that are considered as a part of the word
        separatorSet.remove(charactersIn: "@#/•\"-.")

        var components: [String] = []
        var currentWord = ""

        for char in self {
            let str = String(char)
            guard let scalar = str.unicodeScalars.first else { continue }

            // Check if the character is a separator
            if separatorSet.contains(scalar) {
                if !currentWord.isEmpty {
                    components.append(currentWord)
                    currentWord = ""
                }
                continue
            }

            // Determine if current character is Chinese
            let isChinese = str.isChineseTextByRegex

            if isChinese {
                // If we were building a non-Chinese word, flush it
                if !currentWord.isEmpty {
                    components.append(currentWord)
                    currentWord = ""
                }
                // Each Chinese character is a separate word
                components.append(str)
            } else {
                // If continuing non-Chinese word
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            components.append(currentWord)
        }

        return components
    }
}
