//
//  AudioOutputWarmer.swift
//  Easydict
//
//  Slim build: macOS stops an idle output device, and USB DACs or speakers that wake up
//  again drop the first few hundred milliseconds of sound. Feeding the device silence
//  before and between TTS playbacks keeps it awake, so speech is not cut off.
//

import AVFoundation
import Foundation

@MainActor
final class AudioOutputWarmer {
    // MARK: Internal

    static let shared = AudioOutputWarmer()

    /// How long playback should still wait for a device that was just woken up.
    var remainingWakeUpTime: TimeInterval {
        guard engine.isRunning, let startDate else { return 0 }
        return max(0, Constants.wakeUpTime - Date().timeIntervalSince(startDate))
    }

    /// Starts streaming silence to the output device, unless it already is.
    func warmUp() {
        stopTask?.cancel()
        stopTask = nil
        guard !engine.isRunning else { return }

        // Only the mixer is used, so no input device is opened and no microphone access is asked for.
        _ = engine.mainMixerNode
        engine.prepare()
        do {
            try engine.start()
            startDate = Date()
        } catch {
            startDate = nil
            logError("Failed to warm up the audio output: \(error.localizedDescription)")
        }
    }

    /// Lets the device go idle once nothing has been played for a while.
    func scheduleStop() {
        guard engine.isRunning else { return }
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.keepAliveTime))
            guard !Task.isCancelled, let self else { return }
            engine.stop()
            startDate = nil
            stopTask = nil
        }
    }

    // MARK: Private

    private enum Constants {
        /// Time a sleeping USB device needs before it plays sound again. Generous, because some
        /// voices (the Japanese ones) start speaking without any leading silence.
        static let wakeUpTime: TimeInterval = 0.8
        /// Covers the pause between looking up words, so the next one starts at once.
        static let keepAliveTime: TimeInterval = 30
    }

    private let engine = AVAudioEngine()
    private var startDate: Date?
    private var stopTask: Task<(), Never>?
}
