// Converts the upstream reading dictionaries into the compact, LZFSE-compressed
// TSV resources loaded by the Reading service.
//
// Usage: swift generate.swift <source-dir> <output-dir>
//
// <source-dir> must contain large_pinyin.txt (phrase-pinyin-data),
// char_pinyin.txt (pinyin-data pinyin.txt) and JmdictFurigana.txt.

import Foundation

// MARK: - Helpers

func isHan(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x3005, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF, 0x20000 ... 0x323AF:
        true
    default:
        false
    }
}

func readLines(_ url: URL) throws -> [Substring] {
    var text = try String(contentsOf: url, encoding: .utf8)
    if text.hasPrefix("\u{FEFF}") {
        text.removeFirst()
    }
    return text.split(whereSeparator: \.isNewline)
}

/// Writes rows sorted by their first field in UTF-8 byte order, which the app's binary search
/// relies on. The sort is stable, so rows sharing a key keep their source order.
func writeCompressed(_ lines: [String], to url: URL) throws {
    let sorted = lines.enumerated().map { index, line in
        (key: Array(line.prefix { $0 != "\t" }.utf8), index: index, line: line)
    }
    .sorted { lhs, rhs in
        lhs.key == rhs.key ? lhs.index < rhs.index : lhs.key.lexicographicallyPrecedes(rhs.key)
    }
    .map(\.line)
    let data = Data((sorted.joined(separator: "\n") + "\n").utf8)
    let compressed = try (data as NSData).compressed(using: .lzfse) as Data
    try compressed.write(to: url)
    print("\(url.lastPathComponent): \(sorted.count) entries, \(data.count) -> \(compressed.count) bytes")
}

// MARK: - Converters

/// `银行: yín háng` → `银行\tyín háng`, keeping multi-character Han phrases whose
/// syllable count matches the character count.
func chinesePhrases(from url: URL) throws -> [String] {
    try readLines(url).compactMap { line -> String? in
        guard !line.hasPrefix("#"), let colon = line.firstIndex(of: ":") else { return nil }
        let phrase = line[..<colon].trimmingCharacters(in: .whitespaces)
        let pinyin = line[line.index(after: colon)...]
            .split(separator: "#", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let syllables = pinyin.split(separator: " ")
        guard phrase.count >= 2, syllables.count == phrase.count,
              phrase.unicodeScalars.allSatisfy(isHan)
        else { return nil }
        return "\(phrase)\t\(syllables.joined(separator: " "))"
    }
}

/// `U+884C: xíng,háng,…  # 行` → `行\txíng`, keeping the first (most common) reading.
func chineseCharacters(from url: URL) throws -> [String] {
    try readLines(url).compactMap { line -> String? in
        guard line.hasPrefix("U+"), let colon = line.firstIndex(of: ":"),
              let code = UInt32(line.dropFirst(2)[..<colon], radix: 16),
              let scalar = Unicode.Scalar(code)
        else { return nil }
        let readings = line[line.index(after: colon)...]
            .split(separator: "#", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard let first = readings.split(separator: ",").first, !first.isEmpty else { return nil }
        return "\(Character(scalar))\t\(first)"
    }
}

/// `取り扱い|とりあつかい|0:と;2:あつか` → tab-separated, keeping entries that contain kanji.
func japaneseFurigana(from url: URL) throws -> [String] {
    try readLines(url).compactMap { line -> String? in
        let fields = line.split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3, !fields[2].isEmpty,
              fields[0].unicodeScalars.contains(where: isHan)
        else { return nil }
        return fields.joined(separator: "\t")
    }
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: swift generate.swift <source-dir> <output-dir>\n".utf8))
    exit(64)
}

let sourceDir = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputDir = URL(fileURLWithPath: arguments[2], isDirectory: true)

try writeCompressed(
    chinesePhrases(from: sourceDir.appendingPathComponent("large_pinyin.txt")),
    to: outputDir.appendingPathComponent("zh-phrases.tsv.lzfse")
)
try writeCompressed(
    chineseCharacters(from: sourceDir.appendingPathComponent("char_pinyin.txt")),
    to: outputDir.appendingPathComponent("zh-characters.tsv.lzfse")
)
try writeCompressed(
    japaneseFurigana(from: sourceDir.appendingPathComponent("JmdictFurigana.txt")),
    to: outputDir.appendingPathComponent("ja-furigana.tsv.lzfse")
)
