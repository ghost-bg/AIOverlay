import Foundation

enum Sender {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: Sender
    let text: String
}

