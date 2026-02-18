from typing import List

import dspy
import lancedb
from lance_mcp.signatures.lance_mcp import LanceMcpSignature
from sentence_transformers import SentenceTransformer

embedding_model = SentenceTransformer('jinaai/jina-embeddings-v2-small-en')
db = lancedb.connect('../../stores/lance/db')
tbl = db.open_table("source")


def lance_retriever(query: str, k: int = 5) -> List[str]:
    try:
        ## vector
        query_embedding = embedding_model.encode(query)
        results = tbl.search(query_embedding, vector_column_name="embeddings", query_type="vector").limit(k).to_pandas()
        ## fts
        # results = tbl.search(query, query_type="fts").limit(k).select(["text", "docName"]).to_pandas()
        ## hybrid
        # embeddings = get_registry().get("huggingface").create(name="sentence-transformers/all-MiniLM-L6-v2")
        # tbl.embedding_functions = {"embeddings": SimpleNamespace(function=embeddings)}  # ✅ Fixed
        # reranker = LinearCombinationReranker(weight=0.7)
        # results = tbl.search(query, query_type="hybrid").rerank(reranker=reranker).limit(k).to_pandas()

        if results.empty:
            return [print(f"No relevant passages found for query: {query} and k: {k}.")]

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


class LanceMcpPredict(dspy.Module):
    #
    # def __init__(self):
    #     super().__init__()
    #     self.predictor = dspy.Predict(LanceMcpSignature)
    #
    # def forward(self, query: str) -> dspy.Prediction:
    #     return self.predictor(query=query)
    #

    def __init__(self):
        super().__init__()
        self.generate = dspy.ChainOfThought(LanceMcpSignature)

    def forward(self, question: str) -> dspy.Prediction:
        # Use direct retrieval instead of dspy.Retrieve
        context = lance_retriever(question, k=5)
        context_str = "\n-----------\n".join(context)
        prediction = self.generate(question=question, context=context_str)
        return dspy.Prediction(
            question=question,
            context=context_str,
            answer=prediction.answer
        )
