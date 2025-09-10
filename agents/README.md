# Context Processor Service

A minimal FastAPI service that uses LangGraph to clean OCR text before it is sent to the main agent.

## Running

Install dependencies and start the service:

```bash
pip install fastapi uvicorn langgraph pydantic
uvicorn agents.context_processor:app --host 127.0.0.1 --port 5001
```

## Calling from the app

Send a POST request to `http://127.0.0.1:5001/process` with JSON body:

```json
{"text": "<raw ocr text>"}
```

Example using `URLSession` in Swift:

```swift
struct ProcessResponse: Codable { let processed: String }

func sendToContextProcessor(_ raw: String, completion: @escaping (String) -> Void) {
    let url = URL(string: "http://127.0.0.1:5001/process")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONEncoder().encode(["text": raw])

    URLSession.shared.dataTask(with: request) { data, _, _ in
        if let data = data,
           let response = try? JSONDecoder().decode(ProcessResponse.self, from: data) {
            completion(response.processed)
        } else {
            completion(raw) // fallback to unprocessed text
        }
    }.resume()
}
```
