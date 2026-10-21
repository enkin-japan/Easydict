//
//  ReadingService.swift
//  Easydict
//
//  Slim build: an offline "service" that shows the query text with readings
//  (furigana for Japanese, tone-marked pinyin for Chinese) as HTML <ruby>.
//  Chinese characters read differently in context than on their own
//  (多音字 in their non-default reading) are highlighted and listed.
//

import AppKit
import Foundation

// MARK: - ReadingService

@objc(EZReadingService)
@objcMembers
class ReadingService: QueryService, @unchecked Sendable {
    // MARK: Internal

    override func serviceType() -> ServiceType {
        .reading
    }

    override func name() -> String {
        NSLocalizedString("service.reading.name", comment: "")
    }

    override func apiKeyRequirement() -> ServiceAPIKeyRequirement {
        .none
    }

    override func supportedQueryType() -> EZQueryTextType {
        [.dictionary, .sentence, .translation]
    }

    override func intelligentQueryTextType() -> EZQueryTextType {
        [.dictionary, .sentence, .translation]
    }

    override func supportLanguagesDictionary() -> MMOrderedDictionary {
        let ordered = MMOrderedDictionary()
        for lang in EZLanguageManager.shared().allLanguages {
            ordered.setObject(lang as NSString, forKey: lang as NSString)
        }
        return ordered
    }

    @nonobjc
    override func translate(
        _ text: String,
        from: Language,
        to: Language
    ) async throws
        -> QueryResult {
        guard let script = Self.script(for: text, language: from) else {
            throw QueryError(type: .unsupportedLanguage)
        }

        let segments: [RubySegment]
        switch script {
        case .japanese:
            segments = ReadingAnnotator.japanese(text)
        case .mandarin:
            segments = ReadingAnnotator.mandarin(text)
        }

        guard segments.contains(where: { $0.reading != nil }) else {
            throw QueryError(type: .noResult)
        }

        result?.htmlString = Self.renderHTML(segments: segments, script: script)
        return result ?? QueryResult()
    }

    // MARK: Private

    private enum Script {
        case japanese
        case mandarin

        // MARK: Internal

        var htmlLanguage: String {
            switch self {
            case .japanese: "ja"
            case .mandarin: "zh-Hans"
            }
        }
    }

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
        :root { color-scheme: light dark; --text: \(lightText); --bg: \(lightBG); --accent: #D9480F; }
        @media (prefers-color-scheme: dark) {
          :root { --text: \(darkText); --bg: \(darkBG); --accent: #FF922B; }
        }
        html, body { margin: 0; padding: 0; color: var(--text); background-color: var(--bg); font-family: system-ui; }
        .reading { padding: 6px 12px 8px; font-size: 16px; line-height: 2.3; word-break: break-word; }
        ruby { ruby-position: over; }
        rt { font-size: 0.55em; opacity: 0.75; user-select: none; -webkit-user-select: none; }
        ruby.context, ruby.context rt { color: var(--accent); opacity: 1; }
        .notes { margin: 0 12px 10px; padding-left: 18px; font-size: 13px; line-height: 1.7; opacity: 0.9; }
        </style>
        """
    }

    /// Implements the hooks `EZWebViewManager` calls: font size and height reporting.
    private static var pageScript: String {
        """
        <script>
        function changeWebViewBodyFontSize(ratio) {
          document.body.style.fontSize = (ratio * 100) + '%';
        }
        function notifyContentHeight() {
          var body = document.body, root = document.documentElement;
          var height = Math.max(body ? body.scrollHeight : 0, root ? root.scrollHeight : 0,
                                body ? body.offsetHeight : 0, root ? root.offsetHeight : 0);
          if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.objcHandler) {
            return;
          }
          window.webkit.messageHandlers.objcHandler.postMessage({
            method: 'noteToUpdateScrollHeight',
            renderGeneration: window.__easydictRenderGeneration,
            scrollHeight: height
          });
        }
        function updateWebViewContentStyle() {
          window.requestAnimationFrame(notifyContentHeight);
        }
        window.addEventListener('load', updateWebViewContentStyle);
        window.addEventListener('resize', updateWebViewContentStyle);
        </script>
        """
    }

    /// Picks the reading system from the detected language, falling back to the text itself.
    private static func script(for text: String, language: Language) -> Script? {
        switch language {
        case .japanese:
            return .japanese
        case .classicalChinese, .simplifiedChinese, .traditionalChinese:
            return .mandarin
        default:
            if ReadingAnnotator.containsKana(text) {
                return .japanese
            }
            if ReadingAnnotator.containsHan(text) {
                return .mandarin
            }
            return nil
        }
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func renderHTML(segments: [RubySegment], script: Script) -> String {
        let body = segments.map { segment -> String in
            guard let reading = segment.reading else {
                return escape(segment.base)
            }
            let cssClass = segment.isContextReading ? " class=\"context\"" : ""
            return "<ruby\(cssClass)>\(escape(segment.base))<rt>\(escape(reading))</rt></ruby>"
        }.joined()

        // List characters whose reading here differs from their stand-alone reading.
        var seen = Set<String>()
        let notes = segments.compactMap { segment -> String? in
            guard segment.isContextReading, let reading = segment.reading,
                  let standalone = segment.defaultReading,
                  seen.insert(segment.base + reading).inserted
            else {
                return nil
            }
            return "<li><b>\(escape(segment.base))</b> 此处读 <b>\(escape(reading))</b>"
                + "（单字常读 \(escape(standalone))）</li>"
        }
        let notesHTML = notes.isEmpty ? "" : "<ul class=\"notes\">\(notes.joined())</ul>"

        return """
        <!doctype html>
        <html lang="\(script.htmlLanguage)">
        <head>
        <meta charset="UTF-8">
        <meta name="color-scheme" content="light dark">
        \(contentSecurityPolicy)
        \(style)
        \(pageScript)
        </head>
        <body>
        <div class="reading">\(body)</div>
        \(notesHTML)
        </body>
        </html>
        """
    }
}
