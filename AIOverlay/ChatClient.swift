import Foundation
import os.log

// Payload message sent to/received from the Python chat service
private struct APIMessage: Codable {
    let role: String   // "system", "user", "assistant"
    let content: String
}

private let netLog = Logger(subsystem: "AIOverlay", category: "network")

final class ChatClient: ObservableObject {
    // Persist the system preamble so users can customize it in settings
    var systemPreamble: String {
        didSet {
            UserDefaults.standard.set(systemPreamble, forKey: "systemPreamble")
            if !history.isEmpty {
                history[0] = APIMessage(role: "system", content: systemPreamble)
            }
        }
    }

    private var history: [APIMessage] = []

    init() {
        self.systemPreamble = UserDefaults.standard.string(forKey: "systemPreamble")
            ?? "You are a helpful macOS overlay assistant."
        self.history = [APIMessage(role: "system", content: self.systemPreamble)]
    }

    // Attach screen context to the *next* user message only
    private var pendingContext: String?
    func attachContext(_ text: String) { pendingContext = text }

    func send(user text: String, completion: @escaping (Result<String, Error>) -> Void) {
        var userPayload = text
        if let ctx = pendingContext, !ctx.isEmpty {
            userPayload = "Context:\n\(ctx)\n\nUser:\n\(text)"
            pendingContext = nil
        }

        history.append(APIMessage(role: "user", content: userPayload))

        guard let url = URL(string: "http://127.0.0.1:5001/chat") else {
            return completion(.failure(URLError(.badURL)))
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "messages": history.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        // ---- DEBUG: request ----
        if let u = req.url {
            netLog.debug("➡️ Chat POST \(u.absoluteString)")
            netLog.debug("   scheme=\(u.scheme ?? "-") host=\(u.host ?? "-") port=\(u.port?.description ?? "nil")")
        }
        netLog.debug("   headers=\(String(describing: req.allHTTPHeaderFields))")
        if let d = req.httpBody, let s = String(data: d, encoding: .utf8) {
            netLog.debug("   body=\(s, privacy: .public)")
        }

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                netLog.error("❌ Chat service error: \(err.localizedDescription)")
                return DispatchQueue.main.async { completion(.failure(err)) }
            }

            guard let data = data else {
                return DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Chat", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No data"])))
                }
            }

            if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let raw = String(data: data, encoding: .utf8) ?? ""
                netLog.error("⬅️ Chat HTTP \(http.statusCode): \(raw, privacy: .public)")
                let e = NSError(domain: "Chat", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)", "raw": raw])
                return DispatchQueue.main.async { completion(.failure(e)) }
            }

            do {
                let model = try JSONDecoder().decode(ChatResponse.self, from: data)
                let text = model.response
                DispatchQueue.main.async {
                    self.history.append(APIMessage(role: "assistant", content: text))
                    completion(.success(text))
                }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? ""
                netLog.error("⬅️ Chat decode failed. Raw=\(raw, privacy: .public)")
                let wrapped = NSError(domain: "Chat", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Chat decode failed", "raw": raw])
                DispatchQueue.main.async { completion(.failure(wrapped)) }
            }
        }.resume()
    }

    private struct ChatResponse: Codable { let response: String }
}
