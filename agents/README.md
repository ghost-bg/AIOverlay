# LangGraph Service

A FastAPI microservice that uses LangGraph for two tasks:
1. Clean captured OCR text before it is sent to the main agent.
2. Handle chat requests so all conversation flows through Python.

## Running

Install dependencies and start the service:

```bash
pip install fastapi uvicorn langgraph pydantic
uvicorn agents.context_processor:app --host 127.0.0.1 --port 5001
```

## Context processing endpoint

Send a POST request to `http://127.0.0.1:5001/process` with JSON body:

```json
{"text": "<raw ocr text>"}
```

## Chat endpoint

Send conversation history to `http://127.0.0.1:5001/chat`:

```json
{
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "Hello"}
  ]
}
```

The service returns `{ "response": "..." }` which is appended to the history by the Swift `ChatClient`.
