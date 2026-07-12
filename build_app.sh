#!/bin/bash
# Compila o Voz Mac (Swift nativo) e monta ~/Desktop/VozMac.app — zero dependências.
# Requer apenas as Command Line Tools do Xcode (swiftc).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="VozMac"
BUILD_DIR=".build"
APP="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "🎙️  Compilando Voz Mac (Swift nativo)…"

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Compila todos os fontes Swift num único binário.
swiftc -O \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/*.swift Sources/Apps/*.swift \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework Speech \
    -framework Carbon

# Info.plist e ícone
cp Info.plist "$APP/Contents/Info.plist"
if [ -f VozMac.icns ]; then
    cp VozMac.icns "$RES_DIR/VozMac.icns"
fi

# Assinatura ad-hoc (necessária para TCC liberar microfone/fala/AppleEvents).
codesign --force --deep --sign - "$APP" 2>/dev/null || true

# Instala no Desktop
DEST="$HOME/Desktop/$APP_NAME.app"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "✅  Pronto: $DEST"
echo "   Abra com:  open \"$DEST\""
echo ""
echo "Na primeira execução o macOS pedirá permissão de Microfone e"
echo "Reconhecimento de Fala. Para controlar os apps, conceda também"
echo "Automação/Acessibilidade em Ajustes do Sistema → Privacidade."
