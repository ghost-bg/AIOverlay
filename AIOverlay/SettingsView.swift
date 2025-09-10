import SwiftUI

struct SettingsView: View {
    @ObservedObject var chat: ChatClient
    @State private var systemPreamble = ""
    @State private var backend: ChatClient.Backend = .chatgpt
    @State private var apiKey = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("System Preamble", text: $systemPreamble)

            Picker("Backend", selection: $backend) {
                ForEach(ChatClient.Backend.allCases) { b in
                    Text(b.rawValue.capitalized).tag(b)
                }
            }

            SecureField("API Key", text: $apiKey)

            Button("Apply") {
                chat.systemPreamble = systemPreamble
                chat.backend = backend
                chat.apiKey = apiKey
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 380)
        .padding()
        .onAppear {
            systemPreamble = chat.systemPreamble
            backend = chat.backend
            apiKey = chat.apiKey
        }
    }
}
