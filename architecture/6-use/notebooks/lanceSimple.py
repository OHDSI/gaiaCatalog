import os
from typing import List
import numpy as np
from sentence_transformers import SentenceTransformer
import pandas as pd

import dspy
import lancedb
from lancedb.embeddings import get_registry

db = lancedb.connect('/home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog/architecture/stores/lance/db')
tbl = db.open_table("source")

# TODO
#  look at https://colab.research.google.com/github/mporraProactive/BeatyPets-RAG-System/blob/main/DSPy-LanceDB-demo.ipynb#scrollTo=WP2o6D5qc6F9 
# to see about evaluator stage
# Look at prompt optimizing with
# https://colab.research.google.com/github/huggingface/cookbook/blob/main/notebooks/en/dspy_gepa.ipynb
# https://colab.research.google.com/drive/1pS6H_7Ge8tZClxPWuwnybkNFWodTM96i

# embedding_model = dspy.SentenceTransformer(model_name='jinaai/jina-embeddings-v2-small-en')
# embedder = get_registry().get("huggingface").create(name="jinaai/jina-embeddings-v2-small-en", device="cuda")
embedding_model = SentenceTransformer('jinaai/jina-embeddings-v2-small-en')

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
lm = dspy.LM(
    model="openrouter/x-ai/grok-4-fast",  # grok-code-fast-1
    api_base="https://openrouter.ai/api/v1",
    api_key=OPENROUTER_API_KEY,
    cache=False,
    temperature=0.5
)

dspy.configure(lm=lm)

def lance_retriever(query: str, k: int = 3) -> List[str]:
    try:
        # Fix: Use the correct method for LanceDB embedder
        # query_embedding = embedder.compute_query_embeddings([query])[0]  # Note: pass as list
        query_embedding = embedding_model.encode(query)

        results = tbl.search(query_embedding).limit(k).to_pandas()


        if results.empty:
            return ["No relevant passages found."]

        passages = []
        for _, row in results.iterrows():
            passage = row['description']
            if 'metadata' in row and isinstance(row['metadata'], dict):
                meta_str = f"\n[Metadata: {row['metadata']}]"
                passage += meta_str
            passages.append(passage)

        return passages[:k]
    except Exception as e:
        print(f"Retrieval error: {e}")
        return ["Error retrieving passages."]


class RAG(dspy.Signature):
    """Answer questions based on provided context."""
    question: str = dspy.InputField()
    context: str = dspy.InputField(desc="Relevant passages from retrieval")
    answer: str = dspy.OutputField(desc="Concise answer to the question")
   # answer_rationale = dspy.OutputField(desc="LM's reasoning before it generates the output")

class SimpleRAG(dspy.Module):
    def __init__(self):
        super().__init__()
        self.generate = dspy.ChainOfThought(RAG)

    def forward(self, question: str):
        # Use direct retrieval instead of dspy.Retrieve
        context = lance_retriever(question, k=5)
        context_str = "\n\n".join(context)
        prediction = self.generate(question=question, context=context_str)
        return dspy.Prediction(
            question=question,
            context=context_str,
            answer=prediction.answer
        )


class RewriteQuery(dspy.Signature):
    """Rewrite the user's query to be used in embedding search. Make sure it is a question
    that enhances the original query with the category and example question from the context.
    Data is from a set of state-level resources and services."""
    user_query: str = dspy.InputField(desc="User's query which will be used to access resources from a geospatial index.")
    context: str = dspy.InputField(desc="A set of queries associated with categories and example questions")
    query_phrase: str = dspy.OutputField(desc="a query that feed semantic search to get geospatial and geopolitical resources")
    # query_phrases: list[str] = dspy.OutputField(desc="a list of 5-10 queries that feed semantic search to get chunks of transcripts")


# Instantiate and test (no compile needed)
query = ("What geospatial features can you describe for  Dade country?")

# rewrite query with RewriteQuery
## Provide some general context
df = pd.read_csv('./data/contextv3.csv', nrows=100)
context = df.to_dict(orient='records')
## the re-write stage
rewrite = dspy.ChainOfThought(RewriteQuery)
response = rewrite(user_query=query, context=context)

print("-"*60+  "\n" + query + "\n" + "-"*60 + "\n")

# TODO look into how to best use the array of query_phrases returned in the re-write

# results section
rag = SimpleRAG()
result = rag(question=response.query_phrase)
print(f"\nQuestion: {result.question}")
print(f"\nContext: {result.context}")
print(f"\nAnswer: {result.answer}")

