import SwiftUI

struct SettingsView: View {
    @ObservedObject var chat: ChatClient
    @State private var systemPreamble = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("System Preamble", text: $systemPreamble)

            Button("Apply") {
                chat.systemPreamble = systemPreamble
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 380)
        .padding()
        .onAppear {
            systemPreamble = chat.systemPreamble
        }
    }
}
