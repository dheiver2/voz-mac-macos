import SwiftUI

/// Tela de login simples exibida antes de liberar o painel do Voz Mac.
/// Credenciais fixas (admin/admin, case-sensitive) — sem hash, sem Keychain,
/// sem persistência entre execuções: a cada abertura do app é preciso logar de novo.
struct LoginView: View {
    @EnvironmentObject var state: AppState

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("🎙️ Voz Mac").font(.headline)
                Spacer()
                Text("Login").font(.caption).foregroundStyle(.secondary)
            }

            TextField("Usuário", text: $username)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit(attemptLogin)

            SecureField("Senha", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(attemptLogin)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: attemptLogin) {
                Text("Entrar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func attemptLogin() {
        guard username == "admin", password == "admin" else {
            errorMessage = "Usuário ou senha inválidos."
            password = ""
            return
        }
        errorMessage = nil
        state.isAuthenticated = true
    }
}
