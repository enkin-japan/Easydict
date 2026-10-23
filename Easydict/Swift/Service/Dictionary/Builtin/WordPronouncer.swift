//
//  WordPronouncer.swift
//  Easydict
//
//  Slim build: reads a single dictionary word aloud with the system's offline voices.
//  Dictionary pages ask for it through the `pronounce` web view message.
//

import AVFoundation
import Foundation

// MARK: - WordPronouncer

@objc(EZWordPronouncer)
@objcMembers
final class WordPronouncer: NSObject {
    // MARK: Internal

    static let shared = WordPronouncer()

    /// Speaks `text` in `languageCode` (BCP 47, e.g. `ja-JP`, `en-US`, `en-GB`), stopping any
    /// word still being spoken.
    @MainActor
    func speak(_ text: String, languageCode: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= Self.maxLength else { return }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: languageCode)
        // Slightly slower than the default so single words come out clearly.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    // MARK: Private

    private static let maxLength = 64

    private let synthesizer = AVSpeechSynthesizer()

    /// The best installed voice for the language: the exact region first (so en-GB keeps a
    /// British accent), then the highest quality (premium > enhanced > default), then the
    /// system's default voice. Novelty voices are skipped.
    private static func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let language = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
        let defaultVoice = AVSpeechSynthesisVoice(language: languageCode)
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            guard voice.language == languageCode || voice.language.hasPrefix("\(language)-") else {
                return false
            }
            if #available(macOS 14.0, *) {
                return !voice.voiceTraits.contains(.isNoveltyVoice)
            }
            return true
        }
        func rank(_ voice: AVSpeechSynthesisVoice) -> (Int, Int, Int) {
            (
                voice.language == languageCode ? 1 : 0,
                voice.quality.rawValue,
                voice.identifier == defaultVoice?.identifier ? 1 : 0
            )
        }
        return voices.max { rank($0) < rank($1) } ?? defaultVoice
    }
}
