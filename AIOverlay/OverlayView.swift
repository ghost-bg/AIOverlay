import SwiftUI

struct OverlayView: View {
    let messages: [ChatMessage]
    let onSend: (String) -> Void
    let onUseScreenContext: () -> Void

    @State private var input = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AI Overlay").font(.headline)
                Spacer()
                Button("Use Screen Context", action: onUseScreenContext)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(messages) { msg in
                        HStack {
                            if msg.sender == .assistant {
                                Text(msg.text)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                                    .textSelection(.enabled)
                                Spacer()
                            } else {
                                Spacer()
                                Text(msg.text)
                                    .padding(8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                TextField("Ask something…", text: $input, onCommit: send)
                Button("Send", action: send)
            }
        }
        .padding(12)
        .frame(minWidth: 420, minHeight: 260)
    }

    private func send() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t)
        input = ""
    }
}
