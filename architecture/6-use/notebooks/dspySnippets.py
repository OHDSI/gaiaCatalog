import marimo

__generated_with = "0.17.5"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import re
    import dspy
    import torch
    import lancedb
    import os

    from lancedb.embeddings import get_registry
    from lancedb.pydantic import LanceModel, Vector
    from lancedb.rerankers import LinearCombinationReranker # LanceDB hybrid search uses LinearCombinationReranker by default
    return LinearCombinationReranker, dspy, lancedb, os, re


@app.cell
def _(client):
    device = "cuda" # torch.device("cuda" if torch.cuda.is_available() else "cpu")
    # embed_model = get_registry().get("huggingface").create(name="BAAI/bge-small-en-v1.5", device=device)
    embed_model = lambda text: client.embeddings.create(model="jinaai/jina-embeddings-v2-small-en", input=text).data[0].embedding
    return


@app.cell
def _(LinearCombinationReranker, lancedb):
    # class Schema(LanceModel):
    #     text: str = embed_model.SourceField()
    #     vector: Vector(embed_model.ndims()) = embed_model.VectorField()

    class Vectorstore:
        def __init__(self, db_path=None, tablename='sources', chunk_size=50):
            # if context_information is None or db_path is None:
            #     raise ValueError("Both context_information and db_path must be provided")
        
            # self.context_information = context_information
            self.db_path = db_path
            self.tablename = tablename
            # self.chunk_size = chunk_size
            # self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            # self.embed_model = get_registry().get("huggingface").create(name="BAAI/bge-small-en-v1.5", device=self.device)
            self.db = lancedb.connect(self.db_path) 
            # self._persist_on_db()

        # def split_text_into_chunks(self):
        #     """Splits the context information into chunks of the specified size."""
        #     words = self.context_information.split()
        #     return [' '.join(words[i:i + self.chunk_size]) for i in range(0, len(words), self.chunk_size)]

        # def _persist_on_db(self): 
        #     if self.tablename not in self.db.table_names(): 
        #         tbl = self.db.create_table(self.tablename, schema=Schema, mode="overwrite") 
        #         contexts = [{"text": re.sub(r'\s+', ' ', text)} for text in self.split_text_into_chunks()]
        #         tbl.add(contexts) 
        #     else: 
        #         tbl = self.db.open_table(self.tablename)

        #     tbl.create_fts_index("text", replace=True)

        def search_table(self, query_string, query_type='hybrid', top_k=3): 
            print(f'Searching table with query type: {query_type}, table: {self.tablename}, query: {query_string}') 
            reranker = LinearCombinationReranker(weight=0.7)
            tbl = self.db.open_table(self.tablename)
            rs = tbl.search(query_string, query_type=query_type).rerank(reranker=reranker).limit(top_k).to_list() 
            return "- context block: ".join([item['text'] for item in rs])
    return (Vectorstore,)


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
def _(dspy):
    class GenerateAnswer(dspy.Signature):
        """As a chat assitant, generates an answer based on a query and given context chunks. """
        query = dspy.InputField(desc="The question or query to be answered, if context is not provided answers respectfully that cannot help with that question", type=str)
        context_chunks = dspy.InputField(desc="List of relevant context chunks to answer the query", type=list)
        answer = dspy.OutputField(desc="The answer to the query, 5-20 words")
        answer_rationale = dspy.OutputField(desc="LM's reasoning before it generates the output")
    return (GenerateAnswer,)


@app.cell
def _(GenerateAnswer, Vectorstore, dspy):
    class RAG(dspy.Module):
        def __init__(self,  db_path):
            super().__init__()
       
            self.vectorstore = Vectorstore(
        
                db_path=db_path
            )
            self.generate_answer = dspy.ChainOfThought(GenerateAnswer)  # Using signature defined above

        def forward(self, query):
            relevant_contexts = self.vectorstore.search_table(
                query_string=query,
                query_type='hybrid',
                top_k=3
            )
            prediction = self.generate_answer(
                query=query,
                context_chunks=relevant_contexts
            )

            return dspy.Prediction(
                query=query,
                context_chunks=relevant_contexts,
                answer=prediction.answer,
                answer_rationale=prediction.answer_rationale
            )
    return (RAG,)


@app.cell
def _(dspy):
    class EvaluateAnswer(dspy.Signature):
        """Returns a 0-10 metric that measures the accuracy of the provided answer based on the given context chunks and the rationale provided by the algorithm."""
        query = dspy.InputField(desc="The question or query to be answered.", type=str)
        context_chunks = dspy.InputField(desc="List of relevant context chunks used to answer the query.", type=list)
        answer = dspy.InputField(desc="The provided answer to the query.", type=str)
        answer_rationale = dspy.InputField(desc="The reasoning given by the language model for the answer.", type=str)
        accuracy_metric = dspy.OutputField(desc="0-10 number that represents a metric evaluating the accuracy of the answer based on the answer vs contexts provided", type=int)
        rationale_metric = dspy.OutputField(desc="LM's metric reasoning", type=str)
    return (EvaluateAnswer,)


@app.cell
def _(EvaluateAnswer, dspy, re):
    class EvaluatorRAG(dspy.Module):
        def __init__(self):
            super().__init__()
            self.evaluate_answer = dspy.ChainOfThought(EvaluateAnswer)  # Using the EvaluateAnswer signature

        def forward(self, query, context_chunks, answer, answer_rationale):
            evaluation = self.evaluate_answer(
                query=query,
                context_chunks=context_chunks,
                answer=answer,
                answer_rationale=answer_rationale
            )

            # Normalize the accuracy metric to ensure it's always a number
            accuracy_metric = self.normalize_metric(evaluation.accuracy_metric)

            return dspy.Prediction(
                query=query,
                context_chunks=context_chunks,
                answer=answer,
                answer_rationale=answer_rationale,
                accuracy_metric=accuracy_metric,
                rationale_metric=evaluation.rationale_metric
            )

        def normalize_metric(self, metric):
            if isinstance(metric, str):
                match = re.search(r'\d+', metric)
                if match:
                    return int(match.group())
            return metric
    return (EvaluatorRAG,)


@app.cell
def _(EvaluatorRAG, RAG, dspy):
    class RAG_Assitant(dspy.Module):
        def __init__(self, db_path):
            super().__init__()
            self.rag = RAG(db_path=db_path)
            self.evaluator_rag = EvaluatorRAG()

        def process_question(self, query):
            # Get the initial result from RAG
            # result = self.rag.forward(query)
            result = self.rag(query)


            # Evaluate the result using EvaluatorRAG
            # evaluation = self.evaluator_rag.forward(
            evaluation = self.evaluator_rag(
                query=query,
                context_chunks=result.context_chunks,
                answer=result.answer,
                answer_rationale=result.answer_rationale
            )

            # Return the evaluation results as a dictionary
            return {
                "query": evaluation.query,
                "context_chunks": evaluation.context_chunks,
                "answer": evaluation.answer,
                "answer_rationale": evaluation.answer_rationale,
                "accuracy_metric": evaluation.accuracy_metric,
                "rationale_metric": evaluation.rationale_metric
            }
    return (RAG_Assitant,)


@app.cell
def _(EvaluatorRAG, RAG, dspy):
    class WITH_FORWARD_RAG_Assistant(dspy.Module):
        def __init__(self, context_information, db_path):
            super().__init__()
            self.rag = RAG(context_information=context_information, db_path=db_path)
            self.evaluator_rag = EvaluatorRAG()

        def forward(self, query):
            # Get the initial result from RAG
            result = self.rag(query)

            # Evaluate the result using EvaluatorRAG
            evaluation = self.evaluator_rag(
                query=query,
                context_chunks=result.context_chunks,
                answer=result.answer,
                answer_rationale=result.answer_rationale
            )

            return evaluation

    # Usage:
    # assistant = RAG_Assistant(context_info, db_path)
    # result = assistant(query)  # Instead of assistant.process_question(query)
    return


@app.cell
def _(RAG_Assitant):
    assistant = RAG_Assitant(db_path='./db_lancedb')
    return (assistant,)


@app.cell
def _(assistant):
    test_question = "Is it open on Tuesday?"
    result = assistant.process_question(test_question)
    print('Answer:', result['answer'])
    print('Answer Rationale:', result['answer_rationale'])
    print('Accuracy:', result['accuracy_metric'])
    print('Accuracy Rationale:', result['rationale_metric'])
    return


if __name__ == "__main__":
    app.run()
