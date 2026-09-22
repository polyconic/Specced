import SwiftUI
import AppKit

@main
struct SpeccedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Window("Specced", id: "main") {
            ContentView()
                .environmentObject(delegate.model)
                .environmentObject(delegate.checker)
                .frame(minWidth: 820, idealWidth: 960, minHeight: 600, idealHeight: 680)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Check a File…") { delegate.checker.choose() }
                    .keyboardShortcut("o")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = SpecModel()
    lazy var checker = Checker(model: model)

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { checker.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
