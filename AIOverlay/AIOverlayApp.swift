import SwiftUI

@main
struct AIOverlayApp: App {
    @StateObject private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appVM: appVM)
                .onAppear { appVM.showOverlay() }   // show overlay on launch
        }
        .commands {
            CommandGroup(after: .appVisibility) {
                Button("Toggle Overlay (⌥Space)") {
                    appVM.showOverlay()
                }.keyboardShortcut(.space, modifiers: [.option])
            }
        }
    }
}
