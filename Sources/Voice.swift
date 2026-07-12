import Foundation
import AVFoundation

/// Síntese de voz em PT-BR usando AVSpeechSynthesizer nativo — sem o comando `say`.
final class Voice: NSObject {
    static let shared = Voice()

    private let synth = AVSpeechSynthesizer()
    private let ptVoice: AVSpeechSynthesisVoice?

    private override init() {
        // Prefere uma voz aprimorada/premium PT-BR; cai para qualquer pt-BR disponível.
        let ptBR = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "pt-BR" }
        ptVoice = ptBR.first { $0.quality == .premium }
            ?? ptBR.first { $0.quality == .enhanced }
            ?? ptBR.first
            ?? AVSpeechSynthesisVoice(language: "pt-BR")
        super.init()
    }

    /// Fala o texto. Interrompe qualquer fala em andamento (como o `terminate` do Python).
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        let u = AVSpeechUtterance(string: text)
        u.voice = ptVoice
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
