"""Signature definitions for lance_mcp."""

import dspy


class LanceMcpSignature(dspy.Signature):
    """Answer questions based on provided context.  Provide detail based mostly on the context
     and if possible, provide a short rationale for the answer based on the context."""
    question: str = dspy.InputField()
    context: str = dspy.InputField(desc="Relevant passages from retrieval")
    answer: str = dspy.OutputField(desc="Concise answer to the question")
# answer_rationale = dspy.OutputField(desc="LM's reasoning before it generates the output")
