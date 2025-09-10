import SwiftUI

final class AppViewModel: ObservableObject {
    let overlay = OverlayController()
    let context = ScreenContext()
    private struct ProcessResponse: Decodable { let processed: String }
    @Published var messages: [ChatMessage] = [
        ChatMessage(sender: .assistant, text: "👋 Overlay ready.")
    ]
    @Published var chat = ChatClient()

    func showOverlay() {
        overlay.toggle(rootView: makeOverlayView())
    }

    // Build a fresh view each time (prevents recursive getter issues)
    private func makeOverlayView() -> some View {
        OverlayView(
            messages: self.messages,
            onSend: { [weak self] text in
                guard let self = self else { return }
                self.messages.append(ChatMessage(sender: .user, text: text))
                self.overlay.setContent(rootView: self.makeOverlayView())

                self.chat.send(user: text) { result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        switch result {
                        case .success(let reply):
                            self.messages.append(ChatMessage(sender: .assistant, text: reply))
                        case .failure(let err):
                            let raw = (err as NSError).userInfo["raw"] as? String
                            self.messages.append(ChatMessage(sender: .assistant, text: "⚠️ Error: \(raw ?? err.localizedDescription)"))
                        }
                        self.overlay.setContent(rootView: self.makeOverlayView())
                    }
                }
            },
            onUseScreenContext: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.overlay.hide()
                    let grabbed = await self.context.getContextText()
                    self.messages.append(ChatMessage(sender: .assistant, text: "• Captured preview:\n\(String(grabbed.prefix(300)))…"))
                    var processed = grabbed
                    if let url = URL(string: "http://127.0.0.1:5001/process") {
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": grabbed])
                        do {
                            let (data, _) = try await URLSession.shared.data(for: request)
                            if let resp = try? JSONDecoder().decode(ProcessResponse.self, from: data) {
                                processed = resp.processed
                            }
                        } catch {
                            processed = grabbed
                        }
                    }
                    self.chat.attachContext(processed)
                    self.overlay.setContent(rootView: self.makeOverlayView())
                    self.overlay.show()
                }
            }
        )
    }
}
