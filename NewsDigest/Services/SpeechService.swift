import Foundation
import AVFoundation

/// Text-to-Speech service using macOS AVSpeechSynthesizer.
@MainActor
class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var isPaused = false
    @Published var progress: Double = 0

    private var totalLength: Int = 0
    private var spokenLength: Int = 0
    private var saveURL: URL?
    private var completion: ((URL?) -> Void)?

    /// Cached best voice — resolved once
    private var _bestVoice: AVSpeechSynthesisVoice?
    private var _bestVoiceResolved = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak with the best available natural/premium voice.
    func speakNatural(_ text: String) {
        stop()

        let voice = bestNaturalVoice()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.1

        totalLength = text.count
        spokenLength = 0
        isSpeaking = true
        isPaused = false

        synthesizer.speak(utterance)
    }

    /// Speak the text aloud using the system voice.
    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? bestNaturalVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.1

        totalLength = text.count
        spokenLength = 0
        isSpeaking = true
        isPaused = false

        synthesizer.speak(utterance)
    }

    /// Stop speaking.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        progress = 0
    }

    /// Pause speaking.
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    /// Resume speaking.
    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    /// Find the best human-like voice available on the system.
    /// Prefers premium/enhanced voices (Siri, premium quality) over default ones.
    private func bestNaturalVoice() -> AVSpeechSynthesisVoice {
        if _bestVoiceResolved, let v = _bestVoice { return v }
        _bestVoiceResolved = true

        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let enVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Prefer premium quality voices (highest quality available)
        // Quality tiers: .default (1), .enhanced (2), .premium (3)
        let premium = enVoices
            .filter { $0.quality == .premium }
            .sorted { $0.name < $1.name }

        if let voice = premium.first {
            _bestVoice = voice
            print("Using premium voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Fallback to enhanced quality
        let enhanced = enVoices
            .filter { $0.quality == .enhanced }
            .sorted { $0.name < $1.name }

        if let voice = enhanced.first {
            _bestVoice = voice
            print("Using enhanced voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Fallback to any en-US voice, or first available voice
        let fallback = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first
            ?? AVSpeechSynthesisVoice()
        _bestVoice = fallback
        return fallback
    }

    /// Save speech to an audio file (AIFF on macOS).
    func saveToFile(_ text: String, filename: String, completion: @escaping (URL?) -> Void) {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(nil)
            return
        }
        let digestsDir = documentsDir.appendingPathComponent("NewsDigest", isDirectory: true)
        try? FileManager.default.createDirectory(at: digestsDir, withIntermediateDirectories: true)
        let fileURL = digestsDir.appendingPathComponent("\(filename).aiff")

        self.saveURL = fileURL
        self.completion = completion

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestNaturalVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95

        synthesizer.write(utterance) { [weak self] buffer in
            guard let self = self else { return }
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer,
                  pcmBuffer.frameLength > 0 else {
                return
            }

            let audioFile: AVAudioFile
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    audioFile = try AVAudioFile(forWriting: fileURL, settings: pcmBuffer.format.settings, commonFormat: pcmBuffer.format.commonFormat, interleaved: pcmBuffer.format.isInterleaved)
                } else {
                    audioFile = try AVAudioFile(forWriting: fileURL, settings: pcmBuffer.format.settings)
                }
                try audioFile.write(from: pcmBuffer)
            } catch {
                print("Error writing audio: \(error)")
            }
        }
    }

    /// List available voices for the given language.
    static func availableVoices(language: String = "en") -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenLength = characterRange.location + characterRange.length
            if self.totalLength > 0 {
                self.progress = Double(self.spokenLength) / Double(self.totalLength)
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.progress = 1.0

            if let url = self.saveURL {
                self.completion?(url)
                self.saveURL = nil
                self.completion = nil
            }
        }
    }
}
