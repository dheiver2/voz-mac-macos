import Foundation
import AVFoundation

// Runner de testes standalone (sem XCTest) — compila junto com os fontes de
// lógica pura e roda via ./run_tests.sh. Cobre parsing do comando do LLM,
// escaping de AppleScript, resolução de apps, seleção de voz e — se o Ollama
// estiver no ar — um teste de integração real de interpretação.

var passed = 0, failed = 0

func check(_ name: String, _ cond: Bool) {
    if cond { passed += 1; print("  ✅ \(name)") }
    else { failed += 1; print("  ❌ \(name)") }
}

func checkEq<T: Equatable>(_ name: String, _ got: T, _ want: T) {
    check("\(name)  →  \(got)", got == want)
}

/// Espera uma condição assíncrona rodando a RunLoop (as completions usam main.async).
func waitUntil(_ done: () -> Bool, timeout: TimeInterval = 40) {
    let deadline = Date().addingTimeInterval(timeout)
    while !done() && Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
}

// MARK: - 1. Parsing do comando do LLM

print("\n▶ Commander.parseCommand")

do {
    let c = try Commander.parseCommand(
        #"{"acao":"abrir","app":"telegram","contato":null,"mensagem":null,"resposta":"Abrindo o Telegram."}"#)
    checkEq("json puro: acao", c.acao, "abrir")
    checkEq("json puro: app", c.app ?? "nil", "telegram")
    checkEq("json puro: resposta", c.resposta ?? "nil", "Abrindo o Telegram.")
    check("json puro: contato nulo vira nil", c.contato == nil)
} catch { check("json puro não deveria lançar", false) }

do {
    let raw = "```json\n{\"acao\":\"enviar_mensagem\",\"app\":\"whatsapp\",\"contato\":\"João\",\"mensagem\":\"Oi\",\"resposta\":\"ok\"}\n```"
    let c = try Commander.parseCommand(raw)
    checkEq("cerca ```json```: acao", c.acao, "enviar_mensagem")
    checkEq("cerca ```json```: contato", c.contato ?? "nil", "João")
    checkEq("cerca ```json```: mensagem", c.mensagem ?? "nil", "Oi")
} catch { check("cerca ```json``` não deveria lançar", false) }

do {
    let raw = "Claro! Aqui está: {\"acao\":\"nova_conversa\",\"app\":\"telegram\",\"resposta\":\"Abrindo\"} espero ter ajudado."
    let c = try Commander.parseCommand(raw)
    checkEq("prosa ao redor: acao", c.acao, "nova_conversa")
    check("prosa ao redor: campos ausentes viram nil", c.contato == nil && c.mensagem == nil)
} catch { check("prosa ao redor não deveria lançar", false) }

do {
    let c = try Commander.parseCommand(#"{"acao":"resposta_verbal","resposta":"oi"}"#)
    check("campos opcionais ausentes", c.app == nil && c.contato == nil && c.mensagem == nil)
} catch { check("opcionais ausentes não deveria lançar", false) }

do {
    _ = try Commander.parseCommand("sem json nenhum aqui")
    check("texto sem JSON deve lançar", false)
} catch {
    check("texto sem JSON deve lançar", true)
}

// MARK: - 2. Escaping de AppleScript

print("\n▶ AppleScript.escape")
checkEq("escapa aspas", AppleScript.escape(#"diz "oi""#), #"diz \"oi\""#)
checkEq("escapa barra invertida", AppleScript.escape(#"a\b"#), #"a\\b"#)
checkEq("texto simples inalterado", AppleScript.escape("Olá Maria"), "Olá Maria")

// MARK: - 3. Resolução de apps

print("\n▶ AppRegistry.app(for:)")
check("telegram resolve", AppRegistry.app(for: "telegram")?.id == "telegram")
check("case-insensitive (TELEGRAM)", AppRegistry.app(for: "TELEGRAM")?.id == "telegram")
check("whatsapp resolve", AppRegistry.app(for: "whatsapp")?.id == "whatsapp")
check("alias imessage → messages", AppRegistry.app(for: "imessage")?.id == "messages")
check("alias mensagens → messages", AppRegistry.app(for: "mensagens")?.id == "messages")
check("desconhecido vira nil", AppRegistry.app(for: "spotify") == nil)

// MARK: - 4. Voz PT-BR disponível

print("\n▶ Voz (AVSpeechSynthesizer)")
let langVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == AppLanguage.localeID }
print("  ℹ️  vozes \(AppLanguage.localeID) instaladas: \(langVoices.map { $0.name }.joined(separator: ", "))")
check("há ao menos uma voz \(AppLanguage.localeID)", !langVoices.isEmpty)

// MARK: - 5. Integração Ollama (condicional)

print("\n▶ Ollama (integração)")
let commander = Commander()
var onlineChecked = false
var online = false
commander.checkOllama { online = $0; onlineChecked = true }
waitUntil({ onlineChecked }, timeout: 5)

if online {
    print("  ℹ️  Ollama online — testando interpretação real")
    var got: Command?
    var errored = false
    var finished = false
    commander.interpret("open telegram") { r in
        switch r {
        case .success(let c): got = c
        case .failure: errored = true
        }
        finished = true
    }
    waitUntil({ finished }, timeout: 40)
    if let c = got {
        print("  ℹ️  LLM retornou: acao=\(c.acao) app=\(c.app ?? "nil")")
        check("Ollama interpreta 'open telegram' → abrir", c.acao == "abrir")
        check("Ollama identifica app telegram", AppRegistry.app(for: c.app ?? "")?.id == "telegram")
    } else {
        check("Ollama respondeu sem erro", !errored)
    }

    // Caso central: extração de contato + mensagem + app.
    var sendCmd: Command?
    var sendDone = false
    commander.interpret("send hi to Maria on whatsapp") { r in
        if case .success(let c) = r { sendCmd = c }
        sendDone = true
    }
    waitUntil({ sendDone }, timeout: 40)
    if let c = sendCmd {
        print("  ℹ️  LLM retornou: acao=\(c.acao) app=\(c.app ?? "nil") contato=\(c.contato ?? "nil") msg=\(c.mensagem ?? "nil")")
        check("envio: acao=enviar_mensagem", c.acao == "enviar_mensagem")
        check("envio: app=whatsapp", AppRegistry.app(for: c.app ?? "")?.id == "whatsapp")
        check("envio: contato contém 'Maria'", (c.contato ?? "").localizedCaseInsensitiveContains("maria"))
        check("envio: mensagem não vazia", !(c.mensagem ?? "").isEmpty)
    } else {
        check("Ollama interpretou envio de mensagem", false)
    }

    // Pergunta fora de escopo deve virar resposta_verbal (sem app).
    var verbalCmd: Command?
    var verbalDone = false
    commander.interpret("what time is it?") { r in
        if case .success(let c) = r { verbalCmd = c }
        verbalDone = true
    }
    waitUntil({ verbalDone }, timeout: 40)
    if let c = verbalCmd {
        print("  ℹ️  LLM retornou: acao=\(c.acao) resposta=\(c.resposta ?? "nil")")
        check("fora de escopo: resposta falada não vazia", !(c.resposta ?? "").isEmpty)
    } else {
        check("Ollama interpretou pergunta fora de escopo", false)
    }
} else {
    print("  ⚠️  Ollama offline — teste de integração pulado (não conta como falha)")
}

// MARK: - Resultado

print("\n" + String(repeating: "─", count: 40))
print("Resultado: \(passed) passaram, \(failed) falharam")
exit(failed == 0 ? 0 : 1)
