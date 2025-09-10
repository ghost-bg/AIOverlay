import SwiftUI

struct ContentView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Launcher Window").font(.title2)
            HStack {
                Button("Toggle Overlay") { appVM.showOverlay() }
                Button("Settings") { showSettings = true }
            }
            Text("Tip: ⌥Space toggles overlay.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(width: 420, height: 160)
        .padding()
        .sheet(isPresented: $showSettings) {
            SettingsView(chat: appVM.chat)
        }
    }
}
