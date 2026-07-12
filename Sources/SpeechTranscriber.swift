import Foundation
import Speech
import AVFoundation

/// Captura de microfone + transcrição PT-BR 100% on-device via Speech.framework.
/// Substitui faster-whisper + sounddevice + pynput por frameworks nativos da Apple.
final class SpeechTranscriber: NSObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private(set) var isRecording = false

    /// Pede autorização de reconhecimento de fala e microfone.
    static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            let speechOK = status == .authorized
            AVCaptureDevice.requestAccess(for: .audio) { micOK in
                DispatchQueue.main.async { completion(speechOK && micOK) }
            }
        }
    }

    /// Começa a escutar. `onPartial` recebe transcrição parcial ao vivo;
    /// `onFinal` recebe o texto final quando o usuário para (ou detecta silêncio).
    func start(onPartial: @escaping (String) -> Void,
               onFinal: @escaping (String) -> Void,
               onError: @escaping (Error) -> Void) {
        guard !isRecording else { return }

        guard let recognizer, recognizer.isAvailable else {
            onError(VozError.speech("reconhecedor PT-BR indisponível"))
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // On-device: 100% local, sem enviar áudio a servidores.
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            req?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            cleanup()
            onError(error)
            return
        }

        isRecording = true
        var lastText = ""
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            if let result {
                lastText = result.bestTranscription.formattedString
                onPartial(lastText)
                if result.isFinal {
                    self?.finish()
                    onFinal(lastText)
                }
            }
            if let error {
                let final = lastText
                self?.finish()
                if final.isEmpty {
                    onError(error)
                } else {
                    onFinal(final)   // erro após já ter texto = fim normal
                }
            }
        }
    }

    /// Para a captura e força a finalização da transcrição.
    func stop() {
        guard isRecording else { return }
        request?.endAudio()
        // task chama onFinal via callback; áudio para em finish()
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
    }

    private func finish() {
        cleanup()
    }

    private func cleanup() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        task = nil
        request = nil
        isRecording = false
    }
}
