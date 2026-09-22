import SwiftUI
import AppKit

@main
struct SpeccedApp: App {
    let model = SpecModel()

    var body: some Scene {
        Window("Specced", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, idealWidth: 960, minHeight: 600, idealHeight: 680)
        }
        .windowResizability(.contentMinSize)
    }
}
