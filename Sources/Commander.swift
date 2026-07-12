import Foundation

/// Comando estruturado devolvido pelo LLM.
struct Command: Decodable {
    var acao: String
    var app: String?
    var contato: String?
    var mensagem: String?
    var resposta: String?
}

/// Interpreta linguagem natural PT-BR via Ollama (local) e despacha para os apps.
final class Commander {
    let ollamaURL: URL
    let model: String

    private let systemPrompt = """
    Você é o cérebro de um assistente de voz que controla apps no MacBook Pro.
    Interprete o comando do usuário em português e retorne um JSON com a ação a executar.

    Apps disponíveis: telegram, whatsapp, messages (iMessage)

    Formato de resposta — APENAS JSON, sem texto extra, sem markdown:
    {"acao":"<abrir|enviar_mensagem|nova_conversa|resposta_verbal>","app":"<telegram|whatsapp|messages|null>","contato":"<nome ou null>","mensagem":"<texto ou null>","resposta":"<frase curta em PT-BR para falar em voz alta>"}

    Exemplos:
    - "abre o telegram" → {"acao":"abrir","app":"telegram","contato":null,"mensagem":null,"resposta":"Abrindo o Telegram."}
    - "manda oi pro João no zap" → {"acao":"enviar_mensagem","app":"whatsapp","contato":"João","mensagem":"Oi","resposta":"Mensagem enviada pro João no WhatsApp."}
    - "nova conversa no telegram" → {"acao":"nova_conversa","app":"telegram","contato":null,"mensagem":null,"resposta":"Abrindo nova conversa no Telegram."}
    - "que horas são" → {"acao":"resposta_verbal","app":null,"contato":null,"mensagem":null,"resposta":"Só consigo controlar seus apps de mensagem por enquanto."}

    Responda APENAS com o JSON, sem nenhum texto adicional.
    """

    init() {
        let urlString = ProcessInfo.processInfo.environment["OLLAMA_URL"]
            ?? "http://localhost:11434/api/generate"
        ollamaURL = URL(string: urlString)!
        model = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "qwen2.5:3b-instruct"
    }

    /// Verifica se o Ollama está no ar. `completion(true)` = pronto.
    func checkOllama(_ completion: @escaping (Bool) -> Void) {
        guard var comps = URLComponents(url: ollamaURL, resolvingAgainstBaseURL: false) else {
            completion(false); return
        }
        comps.path = "/api/tags"
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 3
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async { completion(data != nil) }
        }.resume()
    }

    /// Processa o texto transcrito: interpreta via LLM e executa a ação.
    /// `onResponse` recebe a frase a ser falada em voz alta.
    func process(_ text: String, onResponse: @escaping (String) -> Void) {
        interpret(text) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                onResponse("Tive um problema ao interpretar o comando.")
            case .success(let cmd):
                let reply = self.dispatch(cmd)
                onResponse(reply)
            }
        }
    }

    // MARK: - LLM

    /// Interpreta o texto via LLM sem executar ação alguma. Exposto para testes.
    func interpret(_ text: String,
                   _ completion: @escaping (Result<Command, Error>) -> Void) {
        let payload: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "prompt": text,
            "stream": false,
            "options": ["temperature": 0.1],
        ]
        var req = URLRequest(url: ollamaURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { data, _, error in
            let done: (Result<Command, Error>) -> Void = { r in
                DispatchQueue.main.async { completion(r) }
            }
            if let error { return done(.failure(error)) }
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = obj["response"] as? String else {
                return done(.failure(VozError.ollama("resposta inválida")))
            }
            do {
                done(.success(try Self.parseCommand(raw)))
            } catch {
                done(.failure(error))
            }
        }.resume()
    }

    /// Extrai o JSON do comando, tolerando blocos ```json``` que o modelo às vezes inclui.
    static func parseCommand(_ raw: String) throws -> Command {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.contains("```") {
            let parts = s.components(separatedBy: "```")
            if parts.count >= 2 {
                s = parts[1]
                if s.hasPrefix("json") { s = String(s.dropFirst(4)) }
            }
        }
        // Recorta do primeiro { ao último } para descartar prosa extra.
        if let open = s.firstIndex(of: "{"), let close = s.lastIndex(of: "}") {
            s = String(s[open...close])
        }
        guard let data = s.data(using: .utf8) else {
            throw VozError.ollama("não foi possível ler o JSON")
        }
        return try JSONDecoder().decode(Command.self, from: data)
    }

    // MARK: - Dispatch

    private func dispatch(_ cmd: Command) -> String {
        let acao = cmd.acao
        let mod = cmd.app.flatMap { AppRegistry.app(for: $0) }
        let contato = cmd.contato ?? ""
        let mensagem = cmd.mensagem ?? ""
        var resposta = cmd.resposta ?? "Pronto."

        do {
            switch acao {
            case "abrir":
                if let mod { try mod.open() }
            case "enviar_mensagem":
                guard let mod else { return "Qual app você quer usar? Telegram, WhatsApp ou Mensagens?" }
                guard !contato.isEmpty else { return "Pra quem você quer mandar a mensagem?" }
                guard !mensagem.isEmpty else { return "O que você quer enviar?" }
                try mod.send(contact: contato, message: mensagem)
            case "nova_conversa":
                if let mod { try mod.newChat() }
            default:
                break   // resposta_verbal ou desconhecida → só fala a resposta
            }
        } catch {
            resposta = "Tive um problema ao executar isso."
        }
        return resposta
    }
}
