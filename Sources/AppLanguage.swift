import Foundation

/// Idioma do app (fala, reconhecimento e respostas). Padrão: inglês.
/// Para português do Brasil: `defaults write com.dheiver.vozmac language pt`
/// ou a variável de ambiente VOZMAC_LANG=pt.
enum AppLanguage {
    static var code: String {
        let raw = ProcessInfo.processInfo.environment["VOZMAC_LANG"]
            ?? UserDefaults.standard.string(forKey: "language")
            ?? "en"
        return raw.lowercased().hasPrefix("pt") ? "pt" : "en"
    }

    /// Identificador de locale para reconhecimento e síntese de voz.
    static var localeID: String { code == "pt" ? "pt-BR" : "en-US" }

    /// Nome do idioma em inglês, usado no prompt do LLM.
    static var name: String { code == "pt" ? "Brazilian Portuguese" : "English" }
}
