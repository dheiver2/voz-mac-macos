import Foundation
import AVFoundation

/// Síntese de voz (inglês por padrão; pt-BR via AppLanguage) usando AVSpeechSynthesizer nativo — sem o comando `say`.
final class Voice: NSObject {
    static let shared = Voice()

    private let synth = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    private override init() {
        // Prefere uma voz aprimorada/premium do idioma; cai para qualquer voz dele.
        let id = AppLanguage.localeID
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == id }
        voice = candidates.first { $0.quality == .premium }
            ?? candidates.first { $0.quality == .enhanced }
            ?? candidates.first
            ?? AVSpeechSynthesisVoice(language: id)
        super.init()
    }

    /// Fala o texto. Interrompe qualquer fala em andamento (como o `terminate` do Python).
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = 0.5           // ~185 wpm equivalente
        u.postUtteranceDelay = 0.05
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }
}
