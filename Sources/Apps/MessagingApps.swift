import Foundation

/// Uma integração de app de mensagem controlável por AppleScript.
protocol MessagingApp {
    static var id: String { get }        // "telegram" | "whatsapp" | "messages"
    static var displayName: String { get }
    static func open() throws
    static func send(contact: String, message: String) throws
    static func newChat() throws
}

// MARK: - Telegram

enum Telegram: MessagingApp {
    static let id = "telegram"
    static let displayName = "Telegram"

    static func open() throws {
        try AppleScript.run(#"tell application "Telegram" to activate"#)
        AppleScript.notify("Voz Mac", "Telegram opened")
    }

    static func send(contact: String, message: String) throws {
        let c = AppleScript.escape(contact)
        let m = AppleScript.escape(message)
        try AppleScript.run("""
        tell application "Telegram" to activate
        delay 1
        tell application "System Events"
            tell process "Telegram"
                keystroke "k" using command down
                delay 0.5
                keystroke "\(c)"
                delay 1
                key code 36
                delay 0.5
                keystroke "\(m)"
                delay 0.3
                key code 36
            end tell
        end tell
        """)
        AppleScript.notify("Telegram", "Message sent to \(contact)")
    }

    static func newChat() throws {
        try AppleScript.run("""
        tell application "Telegram" to activate
        delay 0.5
        tell application "System Events"
            tell process "Telegram" to keystroke "n" using command down
        end tell
        """)
    }
}

// MARK: - WhatsApp

enum WhatsApp: MessagingApp {
    static let id = "whatsapp"
    static let displayName = "WhatsApp"

    static func open() throws {
        try AppleScript.run(#"tell application "WhatsApp" to activate"#)
        AppleScript.notify("Voz Mac", "WhatsApp opened")
    }

    static func send(contact: String, message: String) throws {
        let c = AppleScript.escape(contact)
        let m = AppleScript.escape(message)
        try AppleScript.run("""
        tell application "WhatsApp" to activate
        delay 1
        tell application "System Events"
            tell process "WhatsApp"
                keystroke "f" using command down
                delay 0.5
                keystroke "\(c)"
                delay 1
                key code 36
                delay 0.5
                keystroke "\(m)"
                delay 0.3
                key code 36
            end tell
        end tell
        """)
        AppleScript.notify("WhatsApp", "Message sent to \(contact)")
    }

    static func newChat() throws {
        try AppleScript.run("""
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp" to keystroke "n" using command down
        end tell
        """)
    }
}

// MARK: - iMessage

enum Messages: MessagingApp {
    static let id = "messages"
    static let displayName = "Mensagens"

    static func open() throws {
        try AppleScript.run(#"tell application "Messages" to activate"#)
        AppleScript.notify("Voz Mac", "Messages opened")
    }

    static func send(contact: String, message: String) throws {
        let c = AppleScript.escape(contact)
        let m = AppleScript.escape(message)
        try AppleScript.run("""
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set toBuddy to buddy "\(c)" of targetService
            send "\(m)" to toBuddy
        end tell
        """)
        AppleScript.notify("Messages", "Message sent to \(contact)")
    }

    static func newChat() throws {
        try AppleScript.run(#"tell application "Messages" to activate"#)
    }
}

/// Resolve o identificador vindo do LLM para a integração correspondente.
enum AppRegistry {
    static func app(for id: String) -> MessagingApp.Type? {
        switch id.lowercased() {
        case "telegram": return Telegram.self
        case "whatsapp": return WhatsApp.self
        case "messages", "imessage", "mensagens": return Messages.self
        default: return nil
        }
    }
}
