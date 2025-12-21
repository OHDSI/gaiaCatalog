import marimo

__generated_with = "0.17.5"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import dspy
    import lancedb
    import pandas as pd
    import os
    from typing import List, Dict, Any
    from dspy import Example
    from dspy.teleprompt import BootstrapFewShot, MIPROv2,LabeledFewShot
    from dspy.evaluate import answer_exact_match

    return List, dspy, lancedb, os


@app.cell
def _(lancedb):
    db = lancedb.connect('/home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog/architecture/stores/lance/db')
    tbl = db.open_table("source")
    return


@app.cell
def _(client):
    embedder = lambda text: client.embeddings.create(model="jinaai/jina-embeddings-v2-small-en", input=text).data[0].embedding
    return (embedder,)


@app.cell
def _(List, dspy, lancedb):
    class LanceDBRetriever(dspy.Retrieve):
        def __init__(self, db_uri: str, table_name: str, embedder_func, k: int = 5):
            super().__init__(k=k)
            self.db = lancedb.connect(db_uri)
            self.table = self.db.open_table(table_name)
            self.embedder = embedder_func
            # 3.0.3: Enable caching for repeated queries (optional, but recommended)
            dspy.settings.configure(cache=True)

        def retrieve(self, query: str) -> List[str]:
            try:
                query_embedding = self.embedder(query)
                # 3.0.3 enhancement: Support metadata in search (LanceDB returns as dict)
                results = self.table.search(query_embedding).limit(self.k).to_pandas()

                if results.empty:
                    return ["No relevant passages found."]

                # Extract 'text' as primary passage; optionally include metadata as formatted str
                passages = []
                for _, row in results.iterrows():
                    passage = row['text']
                    if 'metadata' in row and isinstance(row['metadata'], dict):  # If your table has a metadata column
                        meta_str = f"\n[Metadata: {row['metadata']}]"
                        passage += meta_str
                    passages.append(passage)

                return passages[:self.k]  # Ensure exactly k
            except Exception as e:
                dspy.logging.warning(f"Retrieval error: {e}")
                return ["Error retrieving passages."]
    return (LanceDBRetriever,)


@app.cell
def _(dspy, os):
    # Using OpenRouter
    OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
    lm = dspy.LM(
        model="openrouter/x-ai/grok-code-fast-1",
        api_base="https://openrouter.ai/api/v1",
        api_key=OPENROUTER_API_KEY,
        cache=False,
        temperature=0.5
    )


    dspy.configure(lm=lm)
    return


@app.cell
def _(LanceDBRetriever, dspy, embedder):
    # Initialize retriever (reuse embedder from setup)
    db_uri = "/home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog/architecture/stores/lance/db"
    table_name = "source"
    retriever = LanceDBRetriever(db_uri, table_name, embedder, k=3)

    # Critical: Configure the global RM to avoid "No RM is loaded" error
    dspy.settings.configure(rm=retriever)  # This wires your LanceDB retriever into DSPy
    return


@app.cell
def _(dspy):

    # RAG Signature (unchanged)
    class RAG(dspy.Signature):
        """Answer questions based on provided context."""
        question: str = dspy.InputField()
        context: str = dspy.InputField(desc="Relevant passages from retrieval")
        answer: str = dspy.OutputField(desc="Concise answer to the question")
    return (RAG,)


@app.cell
def _(RAG, dspy):

    # Module (now using dspy.Retrieve(k=3) to hook into global RM)
    class SimpleRAG(dspy.Module):
        def __init__(self):
            super().__init__()
            self.retrieve = dspy.Retrieve(k=3)  # Uses configured global RM (your LanceDBRetriever)
            self.generate = dspy.ChainOfThought(RAG)

        def forward(self, question: str):
            context = self.retrieve(question)  # Now works via global RM
            context_str = "\n\n".join(context)  # Join passages
            prediction = self.generate(question=question, context=context_str)
            return dspy.Prediction(
                question=question, 
                context=context_str, 
                answer=prediction.answer
            )
    return (SimpleRAG,)


@app.cell
def _(SimpleRAG):
    # Instantiate and test (no compile needed)
    rag = SimpleRAG()
    query = "What is DSPy?"
    result = rag(question=query)
    print(f"Question: {result.question}")
    print(f"Context: {result.context}")
    print(f"Answer: {result.answer}")
    return


@app.cell
def _():
    # Corrected Trainset: Apply .with_inputs("question") to each Example
    # trainset = [
    #     Example(
    #         question="What is LanceDB?", 
    #         answer="LanceDB is an efficient vector database for AI."
    #         # Optional: Add gold_context if available for better RAG optimization
    #         # , context="LanceDB stores vectors for fast similarity search."
    #     ).with_inputs("question"),
    #     Example(
    #         question="What is RAG?", 
    #         answer="Retrieval-augmented generation improves LLM responses with external knowledge."
    #         # , context="RAG retrieves relevant docs before generating answers."
    #     ).with_inputs("question")
    #     # Add more: Example(question="What is DSPy?", answer="...", context="...").with_inputs("question")
    # ]

    # # Simple Metric (using a built-in for robustness; your custom is also fine)
    # def validate_answers(example, pred, trace=None):
    #     # Use exact match (1.0 or 0.0); or dspy.evaluate.answer_exact_match(example, pred)
    #     return 1.0 if example.answer.lower() in pred.answer.lower() else 0.0

    # # Or use built-in (preferred for 3.0.3)
    # # from dspy.evaluate import answer_exact_match
    # metric = answer_exact_match  # Simpler; pass directly to optimizer

    # # Instantiate unoptimized module (assume SimpleRAG and retriever are set up as before)
    # rag = SimpleRAG()  # Or SimpleRAG(retriever) if using standalone version

    return


@app.cell
def _():
    # query2 = "What is DSPy?"
    # result2 = rag(question=query2)
    # print(f"Question: {result2.question}")
    # print(f"Context: {result2.context}")
    # print(f"Answer: {result2.answer}")
    return


@app.cell
def _():

    # # Option 1: BootstrapFewShot (fast few-shot optimizer; great for small trainsets in 3.0.3)
    # # from dspy.teleprompt import BootstrapFewShot
    # optimizer = BootstrapFewShot(
    #     metric=metric,  # Or validate_answers
    #     max_bootstrapped_demos=4,  # Max few-shot demos to generate/select per signature
    #     # num_candidates=10  # 3.0.3: Number of demo candidates to bootstrap (adjust for speed/quality)
    # )
    # compiled_rag = optimizer.compile(rag, trainset=trainset)  # No max_labeled_examples needed; derives from trainset

    return


@app.cell
def _():

    # # Option 2: MIPROv2 (advanced for RAG; optimizes prompts + demos with proposal strategies in 3.0.3)
    # # from dspy.teleprompt import MIPROv2, LabeledFewShot  # LabeledFewShot as base proposer
    # optimizer_mipro = MIPROv2(
    #     metric=metric,
    #     max_bootstrapped_demos=5,  # Demos to generate
    #     num_candidates=16,  # Candidates for RAG-specific optimization (higher for better results)
    #     # 3.0.3: Proposers for RAG (bootstrap for generation, random for diversity)
    #     proposers=[
    #         LabeledFewShot(metric=metric, max_demos=3),  # Few-shot proposers
    #         BootstrapFewShot(metric=metric, max_bootstrapped_demos=2)
    #     ],
    #     optimizer='adam'  # Or 'sgd'; for prompt fine-tuning (if your LM supports)
    # )
    # compiled_rag_mipro = optimizer_mipro.compile(rag, trainset=trainset)  # Bootstraps contexts if missing

    # # Test the optimized module (use compiled_rag or compiled_rag_mipro)
    # query = "What is DSPy?"
    # result = compiled_rag(question=query)
    # print(f"Optimized Answer: {result.answer}")

    # # Optional: Evaluate on trainset to verify improvement
    # score = dspy.evaluate(compiled_rag, trainset=trainset, metric=metric)
    # print(f"Evaluation Score: {score}")
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
