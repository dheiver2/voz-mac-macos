import SwiftUI

/// Painel flutuante da barra de menus: botão de gravar, transcrição e resposta.
struct PanelView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if !state.isAuthenticated {
            LoginView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Button(action: state.toggleRecording) {
                HStack {
                    Image(systemName: state.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 20))
                    Text(state.isRecording ? "Parar" : "Gravar")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("⌃⌥Space")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isRecording ? .red : .accentColor)
            .disabled(!state.authorized)

            if !state.transcript.isEmpty {
                labeled("Você", state.transcript, .primary)
            }
            if !state.lastResponse.isEmpty {
                labeled("Voz Mac", state.lastResponse, .secondary)
            }

            Divider()

            HStack(spacing: 12) {
                statusDot("Ollama", ok: state.ollamaOnline)
                statusDot("Permissões", ok: state.authorized)
                Spacer()
                Button("Sair") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("🎙️ Voz Mac").font(.headline)
            Spacer()
            Text(state.phase.rawValue)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func labeled(_ title: String, _ body: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(body).font(.callout).foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusDot(_ label: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ok ? .green : .orange).frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
        }
    }
}
