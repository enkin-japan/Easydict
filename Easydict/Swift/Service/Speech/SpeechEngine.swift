//
//  SpeechEngine.swift
//  Easydict
//
//  Slim build: which engine speaks text, and the per-language voice settings it uses.
//

import Defaults
import SwiftUI

// MARK: - SpeechEngine

enum SpeechEngine: String, CaseIterable, Identifiable, Defaults.Serializable {
    /// `AVSpeechSynthesizer` with an installed system voice.
    case system
    /// A server implementing OpenAI's `POST /v1/audio/speech`, e.g. a local Kokoro-FastAPI.
    case openAICompatible

    // MARK: Internal

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system:
            "setting.advance.speech.engine.system"
        case .openAICompatible:
            "setting.advance.speech.engine.openai_compatible"
        }
    }
}

// MARK: - SpeechVoiceLanguage

/// Language groups that each get their own voice setting.
enum SpeechVoiceLanguage: String, CaseIterable, Identifiable {
    case chinese
    case japanese
    case english
    case other

    // MARK: Lifecycle

    init(_ language: Language) {
        switch language {
        case .classicalChinese, .simplifiedChinese, .traditionalChinese:
            self = .chinese
        case .japanese:
            self = .japanese
        case .english:
            self = .english
        default:
            self = .other
        }
    }

    // MARK: Internal

    /// Groups whose system voice can be chosen; other languages always use the best installed voice.
    static let systemVoiceLanguages: [SpeechVoiceLanguage] = [.chinese, .japanese, .english]

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .chinese:
            "setting.advance.speech.voice.chinese"
        case .japanese:
            "setting.advance.speech.voice.japanese"
        case .english:
            "setting.advance.speech.voice.english"
        case .other:
            "setting.advance.speech.voice.other"
        }
    }

    /// BCP 47 language prefix of the voices offered for this group.
    var voiceLanguagePrefix: String? {
        switch self {
        case .chinese:
            "zh"
        case .japanese:
            "ja"
        case .english:
            "en"
        case .other:
            nil
        }
    }

    var systemVoiceKey: Defaults.Key<String>? {
        switch self {
        case .chinese:
            .systemVoiceChinese
        case .japanese:
            .systemVoiceJapanese
        case .english:
            .systemVoiceEnglish
        case .other:
            nil
        }
    }

    var ttsVoiceKey: Defaults.Key<String> {
        switch self {
        case .chinese:
            .ttsVoiceChinese
        case .japanese:
            .ttsVoiceJapanese
        case .english:
            .ttsVoiceEnglish
        case .other:
            .ttsVoiceOther
        }
    }

    /// Language and text used by the settings preview button.
    var sample: (text: String, language: Language) {
        switch self {
        case .chinese:
            ("你好，银行行长重新开始工作了。", .simplifiedChinese)
        case .japanese:
            ("こんにちは。取り扱いにご注意ください。", .japanese)
        case .english, .other:
            ("Hello, this is how Easydict sounds.", .english)
        }
    }
}
