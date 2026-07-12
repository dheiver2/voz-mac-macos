import SwiftUI
import AppKit

@main
struct VozMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.isRecording ? "mic.fill" : "mic")
        }
        .menuBarExtraStyle(.window)
        .environmentObject(state)
        .onChange(of: delegate.launched) {
            state.bootstrap()
            delegate.hotKey = HotKey { [weak state] in state?.toggleRecording() }
            delegate.hotKey?.register()
        }
    }
}

/// Delegate mínimo: mantém o app como acessório (só barra de menus) e retém o hotkey.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var launched = false
    var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        launched = true
    }
}
