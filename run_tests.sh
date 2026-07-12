#!/bin/bash
# Compila e roda a suíte de testes (lógica pura + integração Ollama se disponível).
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p .build
echo "🧪  Compilando testes…"
swiftc -o .build/tests \
    Sources/AppleScript.swift \
    Sources/Commander.swift \
    Sources/Voice.swift \
    Sources/Apps/MessagingApps.swift \
    Tests/main.swift \
    -framework Foundation \
    -framework AppKit \
    -framework AVFoundation

echo "🧪  Rodando testes…"
.build/tests
