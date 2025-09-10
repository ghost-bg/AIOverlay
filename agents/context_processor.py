from fastapi import FastAPI
from pydantic import BaseModel
from langgraph.graph import StateGraph, START, END


class Payload(BaseModel):
    """Input payload for context processing."""
    text: str


def build_graph():
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


app = FastAPI()


@app.post("/process")
async def process(payload: Payload) -> dict:
    """Process raw OCR text and return a cleaned version."""
    graph = build_graph()
    result = graph.invoke({"text": payload.text})
    return {"processed": result["text"]}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=5001)
