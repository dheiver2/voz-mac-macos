import Foundation
import SwiftUI
import AppKit

/// Estado central do app, observável pela UI. Orquestra transcrição → LLM → voz.
@MainActor
final class AppState: ObservableObject {
    enum Phase: String {
        case idle = "Ready"
        case listening = "Listening…"
        case thinking = "Thinking…"
        case speaking = "Speaking…"
        case error = "Error"
    }

    @Published var phase: Phase = .idle
    @Published var transcript = ""
    @Published var lastResponse = ""
    @Published var authorized = false
    @Published var ollamaOnline = false
    /// Gate de login simples (admin/admin) — sem persistência entre execuções.
    @Published var isAuthenticated = false

    private let transcriber = SpeechTranscriber()
    private let commander = Commander()

    var isRecording: Bool { transcriber.isRecording }

    func bootstrap() {
        SpeechTranscriber.requestAuthorization { [weak self] ok in
            guard let self else { return }
            self.authorized = ok
            if !ok {
                self.phase = .error
                self.lastResponse = "I need microphone and speech recognition permission."
            }
        }
        commander.checkOllama { [weak self] online in
            self?.ollamaOnline = online
            if !online {
                self?.lastResponse = "Ollama is not running. Start it with: ollama serve"
            } else if self?.lastResponse.isEmpty ?? true {
                Voice.shared.speak(AppLanguage.code == "pt" ? "Olá! Estou pronta. Clique em gravar e fale o comando." : "Hi! I'm ready. Click record and say a command.")
            }
        }
    }

    /// Alterna gravação (usado pelo botão e pelo atalho global).
    /// Bloqueado até o login (admin/admin) ser feito no painel.
    func toggleRecording() {
        guard isAuthenticated else { return }
        if transcriber.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard authorized else { bootstrap(); return }
        Voice.shared.stop()
        transcript = ""
        phase = .listening
        transcriber.start(
            onPartial: { [weak self] text in
                Task { @MainActor in self?.transcript = text }
            },
            onFinal: { [weak self] text in
                Task { @MainActor in self?.handleFinal(text) }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.phase = .error
                    self?.lastResponse = error.localizedDescription
                }
            }
        )
    }

    func stopRecording() {
        transcriber.stop()
    }

    private func handleFinal(_ text: String) {
        transcript = text
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            phase = .idle
            return
        }
        phase = .thinking
        commander.process(text) { [weak self] reply in
            Task { @MainActor in
                self?.lastResponse = reply
                self?.phase = .speaking
                Voice.shared.speak(reply)
                self?.phase = .idle
            }
        }
    }
}
