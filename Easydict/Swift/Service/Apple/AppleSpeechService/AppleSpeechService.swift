//
//  AppleSpeechService.swift
//  Easydict
//
//  Created by tisfeng on 2025/6/21.
//  Copyright © 2025 izual. All rights reserved.
//

import AVFoundation
import Defaults
import Foundation

// MARK: - AppleSpeechService

/// Picks `AVSpeechSynthesizer` voices. Third-party apps only see compact, Eloquence and
/// downloaded Enhanced/Premium voices; Siri voices stay private to Apple's own processes.
@objc
public class AppleSpeechService: NSObject {
    // MARK: Public

    /// Identifiers of the installed voices for `language`, best first.
    @objc
    public func availableVoices(for language: Language) -> [String] {
        voices(forLocale: localeIdentifier(for: language)).map(\.identifier)
    }

    // MARK: Internal

    func preferredVoiceIdentifier(from voiceIds: [String]) -> String? {
        var bestVoice: (id: String, priority: Int)?

        for voiceId in voiceIds {
            let priority = voicePriority(for: voiceId)

            if let currentBest = bestVoice {
                if priority > currentBest.priority {
                    bestVoice = (id: voiceId, priority: priority)
                }
            } else {
                bestVoice = (id: voiceId, priority: priority)
            }
        }

        return bestVoice?.id
    }

    func voicePriority(for voiceId: String) -> Int {
        if voiceId.contains("premium") {
            return 3
        }
        if voiceId.contains("enhanced") {
            return 2
        }
        if voiceId.contains("compact") {
            return 1
        }
        return 0
    }

    /// The voice for `language`: the user's choice while it is installed, otherwise the best one.
    func voice(for language: Language) -> AVSpeechSynthesisVoice? {
        if let key = SpeechVoiceLanguage(language).systemVoiceKey,
           case let identifier = Defaults[key], !identifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: identifier) {
            return chosen
        }

        let locale = localeIdentifier(for: language)
        let prefix = String(locale.prefix { $0 != "-" })
        return voices(forLocale: locale).first
            ?? voices(languagePrefix: prefix).first
            ?? AVSpeechSynthesisVoice(language: locale)
    }

    /// Installed voices whose language starts with `prefix` (e.g. `zh`), best first.
    func voices(languagePrefix prefix: String) -> [AVSpeechSynthesisVoice] {
        sortedByQuality(speakableVoices().filter {
            $0.language == prefix || $0.language.hasPrefix("\(prefix)-")
        })
    }

    // MARK: Private

    /// Installed voices for a BCP 47 locale such as `zh-CN`, best first.
    private func voices(forLocale locale: String) -> [AVSpeechSynthesisVoice] {
        sortedByQuality(speakableVoices().filter { $0.language == locale })
    }

    /// Excludes novelty voices (Bubbles, Zarvox, ...) and the user's Personal Voice (macOS 14+).
    private func speakableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            guard #available(macOS 14.0, *) else { return true }
            return !voice.voiceTraits.contains(.isNoveltyVoice)
                && !voice.voiceTraits.contains(.isPersonalVoice)
        }
    }

    /// Premium > Enhanced > default; within a tier, regular voices (Samantha, Tingting) before
    /// the robotic legacy MacinTalk (Fred, Kathy) and Eloquence (Eddy, Flo) ones.
    private func sortedByQuality(_ voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
        func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
            let isLegacy = voice.identifier.hasPrefix("com.apple.speech.synthesis.")
                || voice.identifier.contains(".eloquence.")
            return voice.quality.rawValue * 2 + (isLegacy ? 0 : 1)
        }
        return voices.sorted {
            let lhs = rank($0), rhs = rank($1)
            return lhs != rhs ? lhs > rhs : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Classical Chinese has no Apple locale of its own; it is read in Mandarin.
    private func localeIdentifier(for language: Language) -> String {
        let language = language == .classicalChinese ? .simplifiedChinese : language
        return (AppleLanguageMapper.shared.supportedLanguages[language] ?? "en_US")
            .replacingOccurrences(of: "_", with: "-")
    }
}
