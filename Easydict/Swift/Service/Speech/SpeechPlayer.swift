//
//  SpeechPlayer.swift
//  Easydict
//
//  Slim build: speaks text with the engine chosen in Settings › Advanced › Pronunciation.
//

import AVFoundation
import Defaults
import Foundation

// MARK: - ServerFailureHandling

enum ServerFailureHandling {
    /// Speak with the system voice instead.
    case fallBackToSystemVoice
    /// Pass the error on and finish without speaking, e.g. for a settings preview.
    case report((Error) -> ())
}

// MARK: - SpeechPlayer

/// Plays text through the system synthesizer or an OpenAI-compatible TTS server.
/// Each instance plays one thing at a time; a new `speak` stops the previous one.
@objc(EZSpeechPlayer)
@MainActor
final class SpeechPlayer: NSObject {
    // MARK: Internal

    /// Speaks `text` with the configured engine, falling back to the system voice when the
    /// TTS server fails. `completion` runs once: when playback ends, is stopped, or cannot start.
    @objc
    func speak(_ text: String, language: Language, completion: @escaping () -> ()) {
        speak(
            text,
            language: language,
            engine: Defaults[.speechEngine],
            onServerFailure: .fallBackToSystemVoice,
            completion: completion
        )
    }

    /// - Parameter onServerFailure: What to do when the TTS server request fails.
    func speak(
        _ text: String,
        language: Language,
        engine: SpeechEngine,
        onServerFailure: ServerFailureHandling,
        completion: @escaping () -> ()
    ) {
        stop()
        self.completion = completion

        switch engine {
        case .system:
            speakWithSystemVoice(text, language: language)
        case .openAICompatible:
            speakWithTTSServer(
                text,
                language: language,
                onServerFailure: onServerFailure
            )
        }
    }

    /// Stops playback and any pending server request, then runs the pending completion.
    @objc
    func stop() {
        generation += 1
        synthesisTask?.cancel()
        synthesisTask = nil

        audioPlayer?.stop()
        audioPlayer = nil

        currentUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        finish()
    }

    // MARK: Private

    /// Recently synthesized audio, so replaying the same word does not hit the server again.
    private static let audioCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 50
        return cache
    }()

    private let speechService = AppleSpeechService()

    private lazy var synthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        return synthesizer
    }()

    private var audioPlayer: AVAudioPlayer?
    private var currentUtterance: AVSpeechUtterance?
    private var synthesisTask: Task<(), Never>?
    private var completion: (() -> ())?

    /// Bumped by `stop()`, so results of an abandoned request are ignored.
    private var generation = 0

    private func speakWithSystemVoice(_ text: String, language: Language) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = speechService.voice(for: language)
        logInfo("System speech with voice: \(utterance.voice?.identifier ?? "default")")
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    private func speakWithTTSServer(
        _ text: String,
        language: Language,
        onServerFailure: ServerFailureHandling
    ) {
        let client = OpenAICompatibleTTSClient.configured
        let voice = Defaults[SpeechVoiceLanguage(language).ttsVoiceKey]
        let cacheKey = client.cacheKey(text: text, voice: voice) as NSString
        let generation = generation

        synthesisTask = Task { [weak self] in
            do {
                let audio: Data
                if let cached = Self.audioCache.object(forKey: cacheKey) {
                    audio = cached as Data
                } else {
                    audio = try await client.synthesize(text, voice: voice)
                }
                guard let self, generation == self.generation else { return }

                try play(audio)
                Self.audioCache.setObject(audio as NSData, forKey: cacheKey)
            } catch {
                guard let self, generation == self.generation, !Task.isCancelled else { return }

                logError("TTS server failed: \(error.localizedDescription)")
                switch onServerFailure {
                case .fallBackToSystemVoice:
                    speakWithSystemVoice(text, language: language)
                case let .report(handler):
                    handler(error)
                    finish()
                }
            }
        }
    }

    private func play(_ audio: Data) throws {
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(data: audio)
        } catch {
            throw SpeechSynthesisError.unplayableAudio
        }
        player.delegate = self
        guard player.play() else {
            throw SpeechSynthesisError.unplayableAudio
        }
        logInfo("Playing TTS audio: \(audio.count) bytes, \(String(format: "%.1f", player.duration)) s")
        audioPlayer = player
    }

    private func finish() {
        let completion = completion
        self.completion = nil
        completion?()
    }

    private func utteranceDidEnd(_ utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
        finish()
    }

    private func audioPlayerDidEnd(_ player: AVAudioPlayer) {
        guard player === audioPlayer else { return }
        audioPlayer = nil
        finish()
    }
}

// MARK: AVSpeechSynthesizerDelegate

extension SpeechPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in utteranceDidEnd(utterance) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in utteranceDidEnd(utterance) }
    }
}

// MARK: AVAudioPlayerDelegate

extension SpeechPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in audioPlayerDidEnd(player) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in audioPlayerDidEnd(player) }
    }
}
