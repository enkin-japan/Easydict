//
//  AdvancedTabSpeechSection.swift
//  Easydict
//
//  Slim build: chooses the speech engine and its per-language voices.
//

import AVFoundation
import Defaults
import SFSafeSymbols
import SwiftUI

// MARK: - AdvancedTabSpeechSection

struct AdvancedTabSpeechSection: View {
    // MARK: Internal

    var body: some View {
        Section {
            Picker(
                selection: $speechEngine,
                label: AdvancedTabItemView(
                    color: .blue,
                    icon: .speakerWave2Fill,
                    labelText: "setting.advance.speech.engine"
                )
            ) {
                ForEach(SpeechEngine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }

            switch speechEngine {
            case .system:
                ForEach(SpeechVoiceLanguage.systemVoiceLanguages) { language in
                    SystemVoiceRow(language: language, preview: preview)
                }
                footnote("setting.advance.speech.system.footnote")
            case .openAICompatible:
                TextField(
                    "setting.advance.speech.tts.endpoint",
                    text: $ttsEndpoint,
                    prompt: Text(verbatim: Defaults.Keys.ttsEndpoint.defaultValue)
                )
                SecureTextField(title: "setting.advance.speech.tts.api_key", placeholder: "", text: $ttsAPIKey)
                TextField(
                    "setting.advance.speech.tts.model",
                    text: $ttsModel,
                    prompt: Text(verbatim: Defaults.Keys.ttsModel.defaultValue)
                )
                ForEach(SpeechVoiceLanguage.allCases) { language in
                    TTSVoiceRow(language: language, preview: preview)
                }
                footnote("setting.advance.speech.tts.footnote")
            }

            if let previewError {
                Text("setting.advance.speech.preview.failed \(previewError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        } header: {
            Text("setting.advance.header.speech")
        }
        .onChange(of: speechEngine) { _ in
            speechPlayer.stop()
            previewError = nil
        }
    }

    // MARK: Private

    @State private var speechPlayer = SpeechPlayer()
    @State private var previewError: String?

    @Default(.speechEngine) private var speechEngine
    @Default(.ttsEndpoint) private var ttsEndpoint
    @Default(.ttsAPIKey) private var ttsAPIKey
    @Default(.ttsModel) private var ttsModel

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Speaks the group's sample with the selected engine, reporting server errors instead of falling back.
    private func preview(_ language: SpeechVoiceLanguage) {
        previewError = nil
        let sample = language.sample
        speechPlayer.speak(
            sample.text,
            language: sample.language,
            engine: speechEngine,
            onServerFailure: .report { previewError = $0.localizedDescription },
            completion: {}
        )
    }
}

// MARK: - SystemVoiceRow

private struct SystemVoiceRow: View {
    // MARK: Lifecycle

    init(language: SpeechVoiceLanguage, preview: @escaping (SpeechVoiceLanguage) -> ()) {
        self.language = language
        self.preview = preview
        self._voiceIdentifier = .init(language.systemVoiceKey ?? .systemVoiceEnglish)
        self.voices = language.voiceLanguagePrefix.map { AppleSpeechService().voices(languagePrefix: $0) } ?? []
    }

    // MARK: Internal

    var body: some View {
        LabeledContent {
            HStack {
                Picker(selection: selection) {
                    Text("setting.advance.speech.voice.automatic").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text(verbatim: Self.title(of: voice)).tag(voice.identifier)
                    }
                } label: {
                    EmptyView()
                }
                .labelsHidden()

                PreviewButton { preview(language) }
            }
        } label: {
            Text(language.title)
        }
    }

    // MARK: Private

    private let language: SpeechVoiceLanguage
    private let preview: (SpeechVoiceLanguage) -> ()
    private let voices: [AVSpeechSynthesisVoice]

    @Default private var voiceIdentifier: String

    /// Shows "Automatic" when the saved voice is no longer installed.
    private var selection: Binding<String> {
        Binding(
            get: { voices.contains { $0.identifier == voiceIdentifier } ? voiceIdentifier : "" },
            set: { voiceIdentifier = $0 }
        )
    }

    private static func title(of voice: AVSpeechSynthesisVoice) -> String {
        let quality: String? = switch voice.quality {
        case .premium:
            String(localized: "setting.advance.speech.voice.quality.premium")
        case .enhanced:
            String(localized: "setting.advance.speech.voice.quality.enhanced")
        default:
            nil
        }
        let name = quality.map {
            String(localized: "setting.advance.speech.voice.name_with_quality \(voice.name) \($0)")
        } ?? voice.name
        return "\(name) · \(voice.language)"
    }
}

// MARK: - TTSVoiceRow

private struct TTSVoiceRow: View {
    // MARK: Lifecycle

    init(language: SpeechVoiceLanguage, preview: @escaping (SpeechVoiceLanguage) -> ()) {
        self.language = language
        self.preview = preview
        self._voice = .init(language.ttsVoiceKey)
    }

    // MARK: Internal

    var body: some View {
        LabeledContent {
            HStack {
                TextField(
                    text: $voice,
                    prompt: Text(verbatim: language.ttsVoiceKey.defaultValue)
                ) {
                    EmptyView()
                }
                .labelsHidden()

                PreviewButton { preview(language) }
            }
        } label: {
            Text(language.title)
        }
    }

    // MARK: Private

    private let language: SpeechVoiceLanguage
    private let preview: (SpeechVoiceLanguage) -> ()

    @Default private var voice: String
}

// MARK: - PreviewButton

private struct PreviewButton: View {
    let action: () -> ()

    var body: some View {
        Button(action: action) {
            Image(systemSymbol: .playCircle)
        }
        .buttonStyle(.borderless)
        .help("setting.advance.speech.preview")
    }
}
