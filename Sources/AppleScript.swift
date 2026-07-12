import Foundation
import AppKit

/// Execução de AppleScript 100% nativa via NSAppleScript — sem `osascript`, sem subprocess.
enum AppleScript {
    /// Executa um script e devolve o texto do resultado. Lança em caso de erro.
    @discardableResult
    static func run(_ source: String) throws -> String {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw VozError.applescript("script inválido")
        }
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo, let msg = errorInfo[NSAppleScript.errorMessage] as? String {
            throw VozError.applescript(msg)
        }
        return result.stringValue ?? ""
    }

    /// Escapa aspas e barras invertidas antes de interpolar num literal AppleScript.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Notificação nativa do macOS.
    static func notify(_ title: String, _ message: String) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = message
        NSUserNotificationCenter.default.deliver(n)
    }
}

enum VozError: LocalizedError {
    case applescript(String)
    case ollama(String)
    case speech(String)

    var errorDescription: String? {
        switch self {
        case .applescript(let m): return "AppleScript: \(m)"
        case .ollama(let m): return "Ollama: \(m)"
        case .speech(let m): return "Voz: \(m)"
        }
    }
}
