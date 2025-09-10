from fastapi import FastAPI
from pydantic import BaseModel
from langgraph.graph import StateGraph, START, END
from typing import List


class ContextPayload(BaseModel):
    """Input payload for context processing."""
    text: str


class Message(BaseModel):
    role: str
    content: str


class ChatPayload(BaseModel):
    """Conversation payload for the chat endpoint."""
    messages: List[Message]


def build_context_graph():
    """Build a minimal LangGraph pipeline that cleans input text."""

    class State(dict):
        text: str

    def clean(state: State) -> State:
        # Strip whitespace and collapse internal spaces.
        return {"text": " ".join(state["text"].split())}

    graph = StateGraph(State)
    graph.add_node("clean", clean)
    graph.add_edge(START, "clean")
    graph.add_edge("clean", END)
    return graph.compile()


def build_chat_graph():
    """Build a tiny LangGraph that echoes the last user message."""

    class State(dict):
        messages: List[dict]

    def respond(state: State) -> State:
        msgs = state["messages"]
        last_user = next(
            (m["content"] for m in reversed(msgs) if m["role"] == "user"), ""
        )
        msgs = msgs + [{"role": "assistant", "content": f"Echo: {last_user}"}]
        return {"messages": msgs}

    graph = StateGraph(State)
    graph.add_node("respond", respond)
    graph.add_edge(START, "respond")
    graph.add_edge("respond", END)
    return graph.compile()


app = FastAPI()


@app.post("/process")
async def process(payload: ContextPayload) -> dict:
    """Process raw OCR text and return a cleaned version."""
    graph = build_context_graph()
    result = graph.invoke({"text": payload.text})
    return {"processed": result["text"]}


@app.post("/chat")
async def chat(payload: ChatPayload) -> dict:
    """Generate a chat response using a LangGraph pipeline."""
    graph = build_chat_graph()
    state = {"messages": [m.dict() for m in payload.messages]}
    result = graph.invoke(state)
    return {"response": result["messages"][-1]["content"]}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=5001)