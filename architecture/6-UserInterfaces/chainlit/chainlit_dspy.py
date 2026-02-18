import chainlit as cl
import dspy
import dspy.streaming  # For streaming support
import os
from mcp2py import load
import asyncio
import sys

# Ensure event loop compatibility for Python 3.13
if sys.platform == 'linux':
    try:
        asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
    except Exception:
        pass

# from dspy.retrieve import

# Import any retrievers or modules as needed

# Set up DSPy with your preferred LM (e.g., OpenAI)
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")

lm = dspy.LM(
    model="openrouter/x-ai/grok-4-fast",  # grok-code-fast-1  anthropic/claude-sonnet-4-20250514  anthropic/claude-sonnet-4
    api_base="https://openrouter.ai/api/v1",
    api_key=OPENROUTER_API_KEY,
    cache=False,
    temperature=0.5
)

dspy.settings.configure(lm=lm)

# MCP loading
api = load("http://0.0.0.0:8898/mcp")


# Define a conversational DSPy signature
class ConversationalQA(dspy.Signature):
    """Answer questions based on input and conversation history."""
    history: str = dspy.InputField(desc="Previous conversation history as a formatted string.")
    question: str = dspy.InputField()
    answer: str = dspy.OutputField()


# A simple DSPy program (you can optimize this later)
class QAModule(dspy.Module):
    def __init__(self):
        super().__init__()
        # self.generate_answer = dspy.ChainOfThought(ConversationalQA)
        self.generate_answer = dspy.ReAct(ConversationalQA, tools=api.tools)

    def forward(self, history, question):
        return self.generate_answer(history=history, question=question)


# Instantiate the DSPy program
qa_program = QAModule()

# Initialize session history on chat start
@cl.on_chat_start
async def start():
    cl.user_session.set("history", [])  # List of dicts: [{'role': 'user'/'assistant', 'content': str}]


# Chainlit chat handler
@cl.on_message
async def main(message: cl.Message):
    # Get current history (past exchanges only)
    history = cl.user_session.get("history")

    # Format past history as a string for DSPy (e.g., "User: msg1\nAssistant: resp1\n...")
    formatted_history = "\n".join(
        [f"{msg['role'].capitalize()}: {msg['content']}" for msg in history]
    )

    # Wrap with streamify for streaming (listen to the 'answer' field)
    # Create new listeners for each request to ensure fresh state
    stream_listeners = [
        dspy.streaming.StreamListener(signature_field_name="answer")
    ]
    stream_qa = dspy.streamify(qa_program, stream_listeners=stream_listeners)

    # Get the streaming output from DSPy
    stream_output = stream_qa(history=formatted_history, question=message.content)

    # Create a Chainlit message for streaming
    msg = cl.Message(content="")
    await msg.send()

    full_answer = ""
    async for chunk in stream_output:
        if isinstance(chunk, dspy.streaming.StreamResponse):
            if chunk.signature_field_name == "answer":
                full_answer += chunk.chunk
                msg.content = full_answer
                await msg.update()
        elif isinstance(chunk, dspy.Prediction):
            # Append the current user message and the assistant's response to history
            history.append({"role": "user", "content": message.content})
            history.append({"role": "assistant", "content": chunk.answer})
            cl.user_session.set("history", history)

    # Ensure the message is finalized (optional, but good practice)
    await msg.update()
