//
//  BuiltinDictionaryHTML.swift
//  Easydict
//
//  Slim build: renders Built-in Dictionary results as one HTML page for the result web view.
//  Pronunciation buttons post a `pronounce` message, which EZWebViewManager passes to
//  WordPronouncer.
//

import AppKit
import Foundation

// MARK: - BuiltinDictionaryHTML

enum BuiltinDictionaryHTML {
    // MARK: Internal

    static func page(english entries: [EnglishDictionaryEntry], query: String) -> String {
        let body = entries.map { englishEntryHTML($0, query: query) }.joined()
        return document(body: body, language: "en")
    }

    static func page(japanese matches: [BuiltinDictionary.JapaneseMatch], query: String) -> String {
        var body = matches.map { japaneseEntryHTML($0, query: query) }.joined()
        if let first = matches.first {
            let headword = first.entry.visibleWritings.first?.text ?? ""
            let kanji = BuiltinDictionaryStore.shared.kanji(in: headword)
            if !kanji.isEmpty {
                body += "<section class=\"kanji\"><h3>汉字</h3>\(kanji.map(kanjiHTML).joined())</section>"
            }
        }
        return document(body: body, language: "ja")
    }

    // MARK: Private

    // MARK: English

    private static let englishInflectionNames = [
        "p": "过去式", "d": "过去分词", "i": "现在分词", "3": "第三人称单数",
        "r": "比较级", "t": "最高级", "s": "复数",
    ]

    private static let englishTagNames = [
        "zk": "中考", "gk": "高考", "cet4": "四级", "cet6": "六级", "ky": "考研",
        "toefl": "托福", "ielts": "雅思", "gre": "GRE",
    ]

    // MARK: Japanese

    private static let partOfSpeechNames = [
        "n": "名词", "pn": "代词", "num": "数词", "ctr": "量词", "n-suf": "名词后缀",
        "n-pref": "名词前缀", "suf": "后缀", "pref": "前缀", "adj-i": "い形容词",
        "adj-ix": "い形容词（いい／よい）", "adj-na": "な形容词", "adj-no": "可接「の」",
        "adj-t": "たる形容词", "adj-f": "连体修饰", "adj-pn": "连体词", "adv": "副词",
        "adv-to": "副词（可接「と」）", "aux-v": "助动词", "aux": "助动词", "aux-adj": "形容词性助动词",
        "conj": "接续词", "int": "感叹词", "prt": "助词", "exp": "惯用表达", "cop": "系词",
        "v1": "一段动词", "v1-s": "一段动词（くれる类）", "vs": "可接「する」",
        "vs-i": "サ变动词", "vs-s": "サ变动词（する结尾）", "vs-c": "サ变动词（す结尾）",
        "vk": "カ变动词", "vz": "ザ变动词", "vt": "他动词", "vi": "自动词",
        "v5k-s": "五段动词（行く）", "v5r-i": "五段动词（不规则）", "v5aru": "五段动词（ある结尾）",
        "v5u-s": "五段动词（特殊）",
    ]

    private static let miscNames = [
        "uk": "常写作假名", "abbr": "略语", "col": "口语", "hon": "尊敬语", "hum": "谦让语",
        "pol": "礼貌语", "sl": "俚语", "arch": "古语", "derog": "贬义", "vulg": "粗俗",
        "id": "惯用语", "on-mim": "拟声拟态", "obs": "旧词", "rare": "罕用", "joc": "戏谑",
        "fam": "亲昵", "male": "男性用语", "fem": "女性用语", "sens": "敏感词", "poet": "诗歌用语",
        "yoji": "四字熟语", "proverb": "谚语", "chn": "儿语", "form": "书面语", "euph": "委婉语",
        "dated": "过时", "net-sl": "网络用语", "work": "作品名",
    ]

    private static let speakerIcon = """
    <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6h3l4-3v10l-4-3H2z"/>\
    <path d="M11 5.5a3.5 3.5 0 0 1 0 5M12.8 3.5a6 6 0 0 1 0 9" fill="none" stroke-width="1.4"/></svg>
    """

    private static var contentSecurityPolicy: String {
        """
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; \
        style-src 'unsafe-inline'; script-src 'unsafe-inline';">
        """
    }

    private static var style: String {
        let lightText = NSColor.mm_hexString(from: NSColor.ez_resultTextLight())
        let lightBG = NSColor.mm_hexString(from: NSColor.ez_resultViewBgLight())
        let darkText = NSColor.mm_hexString(from: NSColor.ez_resultTextDark())
        let darkBG = NSColor.mm_hexString(from: NSColor.ez_resultViewBgDark())

        return """
        <style>
        :root { color-scheme: light dark; --text: \(lightText); --bg: \(lightBG); --muted: rgba(0,0,0,.55);
          --line: rgba(0,0,0,.12); --accent: #2773DB; --badge: rgba(39,115,219,.12); --pitch: #D9480F; }
        @media (prefers-color-scheme: dark) {
          :root { --text: \(darkText); --bg: \(darkBG); --muted: rgba(255,255,255,.55);
            --line: rgba(255,255,255,.14); --accent: #6AA5FF; --badge: rgba(106,165,255,.16); --pitch: #FF922B; }
        }
        html, body { margin: 0; padding: 0; color: var(--text); background-color: var(--bg);
          font-family: system-ui; font-size: 14px; line-height: 1.55; }
        .entry { padding: 8px 12px 10px; }
        .entry + .entry, .kanji { border-top: 1px solid var(--line); }
        .head { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 8px; }
        .word { font-size: 1.45em; font-weight: 600; }
        .word rt { font-size: .5em; font-weight: 400; opacity: .7; }
        .phonetic { color: var(--muted); }
        .badge { font-size: .78em; padding: 0 6px; border-radius: 4px; background: var(--badge); color: var(--accent); }
        .stars { color: #F59F00; letter-spacing: 1px; font-size: .9em; }
        .speak { display: inline-flex; align-items: center; gap: 2px; border: 1px solid var(--line);
          border-radius: 5px; background: transparent; color: var(--accent); font: inherit; font-size: .8em;
          padding: 1px 6px; cursor: pointer; }
        .speak:hover { background: var(--badge); }
        .speak svg { width: 14px; height: 14px; fill: currentColor; stroke: currentColor; }
        .note { color: var(--muted); font-size: .9em; margin-top: 2px; }
        .readings { margin-top: 4px; display: flex; flex-wrap: wrap; gap: 4px 14px; align-items: center; }
        .reading { display: inline-flex; align-items: center; gap: 6px; }
        .pitch { font-size: 1.05em; letter-spacing: .5px; padding-top: 3px; }
        .pitch .h { border-top: 1.5px solid var(--pitch); }
        .pitch .d { border-right: 1.5px solid var(--pitch); }
        .accent { color: var(--pitch); font-size: .85em; }
        .translation { margin: 6px 0 0; white-space: pre-line; }
        .forms { color: var(--muted); font-size: .9em; margin-top: 4px; }
        ol.senses { margin: 6px 0 0; padding-left: 1.4em; }
        ol.senses li { margin: 3px 0; }
        .pos { color: var(--accent); font-size: .85em; margin-right: 6px; }
        .tags { color: var(--muted); font-size: .85em; margin-left: 6px; }
        .example { color: var(--muted); font-size: .9em; margin: 2px 0 0; }
        details { margin-top: 6px; color: var(--muted); font-size: .9em; }
        details p { margin: 4px 0 0; white-space: pre-line; }
        .kanji { padding: 6px 12px 10px; }
        .kanji h3 { margin: 0 0 4px; font-size: .85em; color: var(--muted); font-weight: 500; }
        .kanji-row { display: flex; gap: 10px; margin: 6px 0; }
        .kanji-char { font-size: 1.8em; line-height: 1.1; min-width: 1.2em; }
        .kanji-info { font-size: .9em; }
        .kanji-info .meaning { color: var(--muted); }
        </style>
        """
    }

    /// Implements the hooks `EZWebViewManager` calls (font size, height reporting) and the
    /// pronunciation buttons.
    private static var script: String {
        """
        <script>
        function changeWebViewBodyFontSize(ratio) {
          document.body.style.fontSize = (ratio * 14) + 'px';
        }
        function postToApp(message) {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.objcHandler) {
            window.webkit.messageHandlers.objcHandler.postMessage(message);
          }
        }
        function notifyContentHeight() {
          var body = document.body, root = document.documentElement;
          var height = Math.max(body ? body.scrollHeight : 0, root ? root.scrollHeight : 0,
                                body ? body.offsetHeight : 0, root ? root.offsetHeight : 0);
          postToApp({ method: 'noteToUpdateScrollHeight',
                      renderGeneration: window.__easydictRenderGeneration, scrollHeight: height });
        }
        function updateWebViewContentStyle() {
          window.requestAnimationFrame(notifyContentHeight);
        }
        document.addEventListener('click', function (event) {
          var button = event.target.closest('.speak');
          if (!button) { return; }
          event.preventDefault();
          postToApp({ method: 'pronounce', text: button.dataset.text, language: button.dataset.lang });
        });
        document.addEventListener('toggle', updateWebViewContentStyle, true);
        window.addEventListener('load', updateWebViewContentStyle);
        window.addEventListener('resize', updateWebViewContentStyle);
        </script>
        """
    }

    private static func document(body: String, language: String) -> String {
        """
        <!doctype html>
        <html lang="\(language)">
        <head>
        <meta charset="UTF-8">
        <meta name="color-scheme" content="light dark">
        \(contentSecurityPolicy)
        \(style)
        \(script)
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func speakButton(_ text: String, language: String, label: String = "") -> String {
        """
        <button class="speak" data-text="\(escape(text))" data-lang="\(language)" title="朗读">\
        \(speakerIcon)\(label)</button>
        """
    }

    private static func englishEntryHTML(_ entry: EnglishDictionaryEntry, query: String) -> String {
        var head = "<span class=\"word\">\(escape(entry.word))</span>"
        if !entry.phonetic.isEmpty {
            head += "<span class=\"phonetic\">/\(escape(entry.phonetic))/</span>"
        }
        head += speakButton(entry.word, language: "en-GB", label: "英")
        head += speakButton(entry.word, language: "en-US", label: "美")
        if entry.collins > 0 {
            head += "<span class=\"stars\" title=\"柯林斯星级\">\(String(repeating: "★", count: entry.collins))</span>"
        }
        if entry.isOxford3000 {
            head += "<span class=\"badge\">牛津 3000</span>"
        }
        for tag in entry.tags.split(separator: " ") {
            head += "<span class=\"badge\">\(escape(englishTagNames[String(tag)] ?? String(tag)))</span>"
        }

        var html = "<section class=\"entry\"><div class=\"head\">\(head)</div>"
        if let lemma = entry.lemma {
            let kinds = entry.lemmaInflectionCodes.compactMap { englishInflectionNames[$0] }
            let kind = kinds.isEmpty ? "变形" : kinds.joined(separator: "、")
            html += "<div class=\"note\">\(escape(lemma)) 的\(kind)</div>"
        } else if entry.word.lowercased() != query.lowercased() {
            html += "<div class=\"note\">「\(escape(query))」的原形</div>"
        }
        html += "<p class=\"translation\">\(escape(entry.translation))</p>"

        let forms = entry.inflections.compactMap { item -> String? in
            guard let name = englishInflectionNames[item.code] else { return nil }
            return "\(name) <b>\(escape(item.form))</b>"
        }
        if !forms.isEmpty {
            html += "<div class=\"forms\">\(forms.joined(separator: " · "))</div>"
        }
        if !entry.definition.isEmpty {
            html += "<details><summary>英文释义</summary><p>\(escape(entry.definition))</p></details>"
        }
        return html + "</section>"
    }

    private static func japaneseEntryHTML(_ match: BuiltinDictionary.JapaneseMatch, query: String) -> String {
        let entry = match.entry
        let writings = entry.visibleWritings
        let readings = entry.visibleReadings
        let headWriting = writings.first?.text
        let headReading = readings.first { $0.applies(to: headWriting) } ?? readings.first

        var head = "<span class=\"word\" lang=\"ja\">"
        if let headWriting, let headReading {
            head += rubyHTML(writing: headWriting, reading: headReading.text)
        } else {
            head += escape(headReading?.text ?? headWriting ?? query)
        }
        head += "</span>"
        if let headReading {
            head += speakButton(headReading.text, language: "ja-JP")
        }
        if entry.isCommon {
            head += "<span class=\"badge\">常用</span>"
        }

        var html = "<section class=\"entry\"><div class=\"head\">\(head)</div>"
        if match.isDeinflected {
            html += "<div class=\"note\">「\(escape(query))」的原形</div>"
        }

        let readingHTML = readings.map { reading -> String in
            var item = pitchHTML(reading.text, accent: reading.accent)
            if reading.text != headReading?.text {
                item += speakButton(reading.text, language: "ja-JP")
            }
            return "<span class=\"reading\">\(item)</span>"
        }
        html += "<div class=\"readings\">\(readingHTML.joined())</div>"

        let otherWritings = writings.dropFirst().map(\.text)
        if !otherWritings.isEmpty {
            html += "<div class=\"forms\">其他写法：\(escape(otherWritings.joined(separator: "、")))</div>"
        }

        let senses = entry.senses.map { sense -> String in
            let pos = sense.partsOfSpeech.map { partOfSpeechNames[$0] ?? $0 }
            var item = pos.isEmpty ? "" : "<span class=\"pos\">\(escape(pos.joined(separator: " · ")))</span>"
            item += escape(sense.glosses.joined(separator: "; "))
            let notes = sense.misc.map { miscNames[$0] ?? $0 } + sense.fields + sense.dialects + sense.info
            if !notes.isEmpty {
                item += "<span class=\"tags\">\(escape(notes.joined(separator: "，")))</span>"
            }
            for example in sense.examples {
                item += "<p class=\"example\" lang=\"ja\">\(escape(example.japanese))<br>\(escape(example.english))</p>"
            }
            return "<li>\(item)</li>"
        }
        html += "<ol class=\"senses\">\(senses.joined())</ol>"
        return html + "</section>"
    }

    private static func kanjiHTML(_ kanji: KanjiDictionaryEntry) -> String {
        var lines: [String] = []
        let readings = [kanji.onReadings.joined(separator: "・"), kanji.kunReadings.joined(separator: "・")]
            .filter { !$0.isEmpty }
        if !readings.isEmpty {
            lines.append(escape(readings.joined(separator: "｜")))
        }
        var details: [String] = kanji.pinyin.map(toneMarkedPinyin)
        if let level = kanji.jlptLevel {
            details.append("旧 JLPT \(level) 级")
        }
        if let strokes = kanji.strokeCount {
            details.append("\(strokes) 画")
        }
        if !details.isEmpty {
            lines.append(escape(details.joined(separator: " · ")))
        }
        if !kanji.meanings.isEmpty {
            lines.append("<span class=\"meaning\">\(escape(kanji.meanings.joined(separator: ", ")))</span>")
        }
        return """
        <div class="kanji-row"><div class="kanji-char" lang="ja">\(escape(kanji.literal))</div>\
        <div class="kanji-info">\(lines.joined(separator: "<br>"))</div></div>
        """
    }

    /// Ruby for a headword, per kanji where JmdictFurigana knows the split (食<rt>た</rt>べる),
    /// otherwise over the whole word.
    private static func rubyHTML(writing: String, reading: String) -> String {
        guard writing != reading else { return escape(writing) }
        let segments = JapaneseFuriganaDictionary.shared.entry(for: writing, reading: reading)?
            .segments(for: writing)
        guard let segments else {
            return "<ruby>\(escape(writing))<rt>\(escape(reading))</rt></ruby>"
        }
        return segments.map { segment in
            guard let kana = segment.reading else { return escape(segment.base) }
            return "<ruby>\(escape(segment.base))<rt>\(escape(kana))</rt></ruby>"
        }.joined()
    }

    /// The reading with high morae overlined and the pitch drop marked, plus the accent
    /// number and pattern name. Several accents show the first as a line and all as numbers.
    private static func pitchHTML(_ reading: String, accent: String?) -> String {
        let morae = morae(of: reading)
        let accents = parseAccents(accent)
        guard let first = accents.first else {
            return "<span class=\"pitch\" lang=\"ja\">\(escape(reading))</span>"
        }

        let downstep = first.position
        let line = morae.enumerated().map { index, mora -> String in
            let isHigh = switch downstep {
            case 0: index > 0
            case 1: index == 0
            default: index > 0 && index < downstep
            }
            var classes: [String] = []
            if isHigh { classes.append("h") }
            if downstep > 0, index == downstep - 1 { classes.append("d") }
            return classes.isEmpty ? escape(mora) : "<span class=\"\(classes.joined(separator: " "))\">\(escape(mora))</span>"
        }.joined()

        let labels = accents.map { item -> String in
            let name = switch item.position {
            case 0: "平板"
            case 1: "头高"
            case morae.count: "尾高"
            default: "中高"
            }
            let prefix = item.label.map { "\($0) " } ?? ""
            return "\(prefix)\(circledNumber(item.position)) \(name)"
        }
        return """
        <span class="pitch" lang="ja">\(line)</span>\
        <span class="accent" title="声调核位置">\(escape(labels.joined(separator: "，")))</span>
        """
    }

    /// Splits kana into morae; small ゃゅょぁぃぅぇぉゎ join the preceding kana.
    private static func morae(of reading: String) -> [String] {
        let small = Set("ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ")
        var morae: [String] = []
        for character in reading {
            if small.contains(character), let last = morae.popLast() {
                morae.append(last + String(character))
            } else {
                morae.append(String(character))
            }
        }
        return morae
    }

    /// Kanjium accents such as `0`, `0,2` or `(副)1,(形動)0`.
    private static func parseAccents(_ accent: String?) -> [(label: String?, position: Int)] {
        guard let accent else { return [] }
        var label: String?
        return accent.split(separator: ",").compactMap { part in
            var text = String(part)
            if text.hasPrefix("("), let close = text.firstIndex(of: ")") {
                label = String(text[text.index(after: text.startIndex) ..< close])
                text = String(text[text.index(after: close)...])
            }
            return Int(text).map { (label, $0) }
        }
    }

    private static func circledNumber(_ number: Int) -> String {
        switch number {
        case 0: "⓪"
        case 1 ... 20: String(UnicodeScalar(0x2460 + number - 1).map(Character.init) ?? "?")
        default: "[\(number)]"
        }
    }

    /// `shi2` → `shí`.
    private static func toneMarkedPinyin(_ syllable: String) -> String {
        guard let last = syllable.last, let tone = last.wholeNumberValue, (1 ... 4).contains(tone) else {
            return syllable
        }
        let base = syllable.dropLast().replacingOccurrences(of: "v", with: "ü")
        let marks: [Character: [Character]] = [
            "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
            "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"],
        ]
        // The mark goes on a or e, on the o of ou, otherwise on the last vowel.
        let characters = Array(base)
        let target = characters.firstIndex(of: "a") ?? characters.firstIndex(of: "e")
            ?? (base.contains("ou") ? characters.firstIndex(of: "o") : nil)
            ?? characters.lastIndex { marks[$0] != nil }
        guard let target, let marked = marks[characters[target]]?[tone - 1] else { return base }
        var result = characters
        result[target] = marked
        return String(result)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
