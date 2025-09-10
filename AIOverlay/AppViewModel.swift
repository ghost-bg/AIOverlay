import SwiftUI

final class AppViewModel: ObservableObject {
    let overlay = OverlayController()
    let context = ScreenContext()
    @Published var messages: [String] = ["👋 Overlay ready."]
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
                self.messages.append("You: \(text)")
                self.overlay.setContent(rootView: self.makeOverlayView())

                self.chat.send(user: text) { result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        switch result {
                        case .success(let reply):
                            self.messages.append("Assistant: \(reply)")
                        case .failure(let err):
                            let raw = (err as NSError).userInfo["raw"] as? String
                            self.messages.append("⚠️ Error: \(raw ?? err.localizedDescription)")
                        }
                        self.overlay.setContent(rootView: self.makeOverlayView())
                    }
                }
            },
            onUseScreenContext: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    let grabbed = await self.context.getContextText()
                    self.messages.append("• Captured preview:\n\(String(grabbed.prefix(300)))…")
                    self.chat.attachContext(grabbed)
                    self.overlay.setContent(rootView: self.makeOverlayView())
                }
            }
        )
    }
}
