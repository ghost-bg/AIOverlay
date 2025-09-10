import SwiftUI

struct SettingsView: View {
    @ObservedObject var chat: ChatClient
    @State private var useOpenAI = false
    @State private var apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    @State private var openAIModel = "gpt-4o-mini"
    @State private var ollamaModel = "llama3.1"

    @Environment(\.dismiss) private var dismiss   // <-- add

    var body: some View {
        Form {
            Toggle("Use OpenAI (off = Ollama)", isOn: $useOpenAI)
                .onChange(of: useOpenAI) { _ in apply() }  // keep: apply but don't dismiss

            if useOpenAI {
                TextField("OpenAI API Key", text: $apiKey)
                TextField("OpenAI Model", text: $openAIModel)
            } else {
                TextField("Ollama Model", text: $ollamaModel)
            }

            Button("Apply") {
                apply()
                dismiss()   // <-- close the sheet
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 380)
        .padding()
        .onAppear {
            switch chat.backend {
            case .openAI(let key, let model):
                useOpenAI = true; apiKey = key; openAIModel = model
            case .ollama(let model):
                useOpenAI = false; ollamaModel = model
            }
        }
    }

    private func apply() {
        if useOpenAI {
            chat.backend = .openAI(apiKey: apiKey, model: openAIModel)
        } else {
            chat.backend = .ollama(model: ollamaModel)
        }
    }
}
