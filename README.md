# Voz Mac 🎙️ — nativo (Swift)

Controle por voz do seu Mac para **Telegram**, **WhatsApp** e **iMessage**.
Reescrita **100% em linguagem macOS** (Swift/SwiftUI), **zero dependências**,
**zero Python**. Toda a inteligência de voz roda on-device.

| Função | Framework nativo |
|---|---|
| Transcrição PT-BR | **Speech.framework** (`SFSpeechRecognizer`, on-device) |
| Captura de áudio | **AVFoundation** (`AVAudioEngine`) |
| Síntese de voz | **AVFoundation** (`AVSpeechSynthesizer`, voz PT-BR) |
| Interface / barra de menus | **SwiftUI** (`MenuBarExtra`) |
| Atalho global ⌃⌥Space | **Carbon** (`RegisterEventHotKey`) |
| Controle dos apps | **AppleScript** (`NSAppleScript`) |
| Cérebro (LLM) | **URLSession** → Ollama local |

Único serviço externo: o **Ollama** (não é Python — é o mesmo backend local que
interpreta os comandos). Nenhuma chave de API, nada sai da máquina.

## Requisitos

- macOS 13+
- Command Line Tools do Xcode (`xcode-select --install`) — só `swiftc`
- [Ollama](https://ollama.com) rodando (`ollama serve`) com o modelo:
  `ollama pull qwen2.5:3b-instruct`

## Build

```bash
./build_app.sh
open ~/Desktop/VozMac.app
```

O script compila com `swiftc`, monta o `.app`, assina ad-hoc e instala no Desktop.

## Uso

Um ícone 🎙️ aparece na barra de menus. Clique nele para abrir o painel e em
**Gravar** (ou aperte **⌃⌥Space** de qualquer lugar). Fale o comando; ele é
transcrito ao vivo, interpretado pelo LLM e executado — com resposta falada.

### Exemplos

```
"Abre o Telegram"
"Manda oi pra Maria no WhatsApp"
"Envia mensagem pro Pedro no Telegram: Estou chegando"
```

## Permissões

Na primeira execução o macOS pede **Microfone** e **Reconhecimento de Fala**.
Para controlar os apps de mensagem, conceda também **Automação** (e, se o app
pedir, **Acessibilidade**) em *Ajustes do Sistema → Privacidade e Segurança*.

## Configuração (opcional)

Variáveis de ambiente, todas opcionais:

| Variável | Padrão | Descrição |
|---|---|---|
| `OLLAMA_URL` | `http://localhost:11434/api/generate` | Endpoint do Ollama |
| `OLLAMA_MODEL` | `qwen2.5:3b-instruct` | Modelo que interpreta os comandos |

## Testes

```bash
./run_tests.sh
```

Suíte standalone (sem XCTest) que cobre parsing do JSON do LLM (inclusive com
cercas ```` ```json ```` e prosa ao redor), escaping de AppleScript, resolução
de apps e aliases, e a voz PT-BR disponível. Se o **Ollama** estiver rodando,
roda também testes de integração reais de interpretação (abrir app, enviar
mensagem com contato/texto, pergunta fora de escopo). 28 casos, todos verdes.

## Estrutura

```
Sources/
  VozMacApp.swift        # @main, MenuBarExtra, AppDelegate (accessory)
  AppState.swift         # orquestra transcrição → LLM → voz
  PanelView.swift        # painel SwiftUI da barra de menus
  SpeechTranscriber.swift# SFSpeechRecognizer + AVAudioEngine (on-device)
  Voice.swift            # AVSpeechSynthesizer PT-BR
  Commander.swift        # Ollama via URLSession + despacho de ações
  HotKey.swift           # atalho global ⌃⌥Space (Carbon)
  AppleScript.swift      # NSAppleScript + notificações + erros
  Apps/MessagingApps.swift # Telegram, WhatsApp, iMessage
build_app.sh             # compila e empacota o .app
Info.plist               # LSUIElement + usage descriptions (mic/fala/AppleEvents)
```

## Licença

MIT.
