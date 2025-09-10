import SwiftUI

struct OverlayView: View {
    let messages: [String]
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
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(messages.indices, id: \.self) { i in
                        Text(messages[i])
                            .padding(6)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
