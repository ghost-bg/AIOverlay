import Foundation
import os.log

// Simple message model (works for both OpenAI + Ollama payloads)
struct ChatMessage: Codable {
    let role: String   // "system", "user", "assistant"
    let content: String
}

// Which backend to talk to
enum ChatBackend: Equatable {
    case openAI(apiKey: String, model: String = "gpt-4o-mini")
    case ollama(model: String = "llama3.1")
}

private let netLog = Logger(subsystem: "AIOverlay", category: "network")

final class ChatClient: ObservableObject {
    @Published var backend: ChatBackend = .ollama()  // default to local for easy testing
    var systemPreamble = "You are a helpful macOS overlay assistant."

    // Attach screen context to the *next* user message only
    private var pendingContext: String?
    func attachContext(_ text: String) { pendingContext = text }

    func send(user text: String, completion: @escaping (Result<String, Error>) -> Void) {
        var userPayload = text
        if let ctx = pendingContext, !ctx.isEmpty {
            userPayload = "Context:\n\(ctx)\n\nUser:\n\(text)"
            pendingContext = nil
        }

        switch backend {
        case .openAI(let apiKey, let model):
            sendOpenAI(apiKey: apiKey, model: model, user: userPayload, completion: completion)
        case .ollama(let model):
            sendOllama(model: model, user: userPayload, completion: completion)
        }
    }

    // MARK: - OpenAI

    private func sendOpenAI(apiKey: String, model: String, user: String,
                            completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return completion(.failure(URLError(.badURL)))
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPreamble],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        // ---- DEBUG: request ----
        if let u = req.url {
            netLog.debug("➡️ OpenAI POST \(u.absoluteString)")
            netLog.debug("   scheme=\(u.scheme ?? "-") host=\(u.host ?? "-") port=\(u.port?.description ?? "nil")")
        }
        netLog.debug("   headers=\(String(describing: req.allHTTPHeaderFields))")
        if let d = req.httpBody, let s = String(data: d, encoding: .utf8) {
            netLog.debug("   body=\(s, privacy: .public)")
        }

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let e = err as? URLError {
                    netLog.error("❌ OpenAI URLError \(e.code.rawValue): \(e.localizedDescription)")
                } else {
                    netLog.error("❌ OpenAI Error: \(err.localizedDescription)")
                }
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
                netLog.error("⬅️ OpenAI HTTP \(http.statusCode): \(raw, privacy: .public)")
                let e = NSError(domain: "Chat", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)", "raw": raw])
                return DispatchQueue.main.async { completion(.failure(e)) }
            }

            do {
                let model = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                let text = model.choices.first?.message.content ?? "No response."
                DispatchQueue.main.async { completion(.success(text)) }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? ""
                netLog.error("⬅️ OpenAI decode failed. Raw=\(raw, privacy: .public)")
                let wrapped = NSError(domain: "Chat", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "OpenAI decode failed", "raw": raw])
                DispatchQueue.main.async { completion(.failure(wrapped)) }
            }
        }.resume()
    }

    private struct OpenAIResponse: Codable {
        struct Choice: Codable { let message: ChatMessage }
        let choices: [Choice]
    }

    // MARK: - Ollama

    private func sendOllama(model: String, user: String,
                            completion: @escaping (Result<String, Error>) -> Void) {
        // Prefer 127.0.0.1 over "localhost" to avoid IPv6/loopback resolution issues.
        guard let url = URL(string: "http://127.0.0.1:11434/api/chat") else {
            return completion(.failure(URLError(.badURL)))
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPreamble],
                ["role": "user", "content": user]
            ],
            "stream": false
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        // ---- DEBUG: request ----
        if let u = req.url {
            netLog.debug("➡️ Ollama POST \(u.absoluteString)")
            netLog.debug("   scheme=\(u.scheme ?? "-") host=\(u.host ?? "-") port=\(u.port?.description ?? "nil")")
        }
        netLog.debug("   headers=\(String(describing: req.allHTTPHeaderFields))")
        if let d = req.httpBody, let s = String(data: d, encoding: .utf8) {
            netLog.debug("   body=\(s, privacy: .public)")
        }

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let e = err as? URLError {
                    netLog.error("❌ Ollama URLError \(e.code.rawValue): \(e.localizedDescription)")
                } else {
                    netLog.error("❌ Ollama Error: \(err.localizedDescription)")
                }
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
                netLog.error("⬅️ Ollama HTTP \(http.statusCode): \(raw, privacy: .public)")
                let e = NSError(domain: "Chat", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)", "raw": raw])
                return DispatchQueue.main.async { completion(.failure(e)) }
            }

            do {
                let model = try JSONDecoder().decode(OllamaResponse.self, from: data)
                let text = model.message.content
                DispatchQueue.main.async { completion(.success(text)) }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? ""
                netLog.error("⬅️ Ollama decode failed. Raw=\(raw, privacy: .public)")
                let wrapped = NSError(domain: "Chat", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Ollama decode failed", "raw": raw])
                DispatchQueue.main.async { completion(.failure(wrapped)) }
            }
        }.resume()
    }

    private struct OllamaResponse: Codable {
        struct Msg: Codable { let role: String; let content: String }
        let message: Msg
    }
}
