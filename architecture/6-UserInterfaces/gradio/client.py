import argparse
import gradio as gr
import lancedb
from lancedb.rerankers import LinearCombinationReranker
from lancedb.embeddings import get_registry
from sentence_transformers import SentenceTransformer
import random
from types import SimpleNamespace
import json
from ollama import Client
from rich.console import Console
from lancedb.pydantic import LanceModel, Vector
from lancedb.embeddings import EmbeddingFunctionRegistry
from baml_client import b
import kuzu
from sentence_transformers import SentenceTransformer
import polars
from gradio_multimodalchatbot import MultimodalChatbot
from gradio.data_classes import FileData

from defs import usage_info

# Global dictionary to store colors for IDs
id_colors = {}

def get_color_for_id_grey(id):
    if id not in id_colors:
        # Generate a shade of grey
        # We'll use values between 220 and 240 to ensure light shades
        # that don't interfere with text readability
        grey_value = random.randint(10, 110)
        id_colors[id] = f"rgb({grey_value},{grey_value},{grey_value})"
    return id_colors[id]

def get_color_for_id(id):
    if id not in id_colors:
        # Generate a light, pastel color
        r = random.randint(5, 150)
        g = random.randint(5, 150)
        b = random.randint(5, 150)
        id_colors[id] = f"rgb({r},{g},{b})"
    return id_colors[id]

def greet(n, db):
    table = db.open_table("source")

    results = table.search(n).limit(10).select(["id", "description"]).to_list()

    output = f"<h3>Full text index search for '{n}':</h3>"
    for result in results:
        background_color = get_color_for_id(result['id'])
        output += f"""
        <div style="border: 1px solid #ddd; padding: 10px; margin-bottom: 10px; border-radius: 5px; background-color: {background_color};">
            <strong>ID:</strong> {result['id']}<br>
            <strong>Text:</strong> {result['description']}<br>
            <strong>Score:</strong> {result['_score']}
        </div>
        """

    return output

def ss_search(n, db):
    # model = SentenceTransformer('all-MiniLM-L6-v2')
    model = SentenceTransformer('jinaai/jina-embeddings-v2-small-en')

    table = db.open_table("source")

    search_embedding = model.encode([n])[0]  # We get the first (and only) embedding
    results = table.search(search_embedding.tolist()).limit(10).to_list()  # or to_pandas()

    output = f"<h3>Vector search for '{n}':</h3>"
    for result in results:
        background_color = get_color_for_id(result['id'])
        output += f"""
        <div style="border: 1px solid #ddd; padding: 10px; margin-bottom: 10px; border-radius: 5px; background-color: {background_color};">
            <strong>ID:</strong> {result['id']}<br>
            <strong>Text:</strong> {result['description']}<br>
            <strong>Distance:</strong> {result['_distance']}
        </div>
        """

    return output

# ref: https://github.com/lancedb/vectordb-recipes/blob/main/examples/Hybrid_search_bm25_lancedb/main.ipynb

def hybrid_Search(n, db):
    embeddings = get_registry().get("huggingface").create(name="jinaai/jina-embeddings-v2-small-en")
    table = db.open_table("source")

    table.embedding_functions = {"embeddings": SimpleNamespace(function=embeddings)}

    reranker = LinearCombinationReranker(
        weight=0.7
    )  # Weight = 0 Means pure Text Search (BM-25) and 1 means pure Sementic (Vector) Search

    results = table.search(n, query_type="hybrid").rerank(reranker=reranker).limit(10).to_list()

    output = f"<h3>Hybrid search (weight 0.7, mostly vector) '{n}':</h3>"
    for result in results:
        background_color = get_color_for_id(result['id'])
        output += f"""
        <div style="border: 1px solid #ddd; padding: 10px; margin-bottom: 10px; border-radius: 5px; background-color: {background_color};">
            <strong>ID:</strong> {result['id']}<br>
            <strong>Text:</strong> {result['description']}<br>
            <strong>Relevance Score:</strong> {result['_relevance_score']}
        </div>
        """

    return output


def combined_search(n):
    # Clear previous color assignments
    id_colors.clear()

    # set up elements
    uri = "../../stores/lance/db"
    db = lancedb.connect(uri)

    text_result = greet(n, db)
    ss_result = ss_search(n, db)
    hs_result = hybrid_Search(n, db)
    return text_result, ss_result, hs_result


# CHAT Section
# registry = EmbeddingFunctionRegistry.get_instance()
# embedder = registry.get("ollama").create(name="mxbai-embed-large")
# model = SentenceTransformer('all-MiniLM-L6-v2')
model = SentenceTransformer('jinaai/jina-embeddings-v2-small-en')


#
# class Schema(LanceModel):
#     id: str
#     text: str = embedder.SourceField()
#     vector: Vector(embedder.ndims()) = embedder.VectorField()

def extract_context(rows):
    return sorted(
        [
            {"id": r['id'], "text": r['description'], "index": r['_distance']}
            for r in rows
        ],
        key=lambda x: x['id']
    )


def chat_search(n):
    uri = "../../stores/lance/db"
    db = lancedb.connect(uri)

    table = db.open_table("source")
    model = SentenceTransformer('jinaai/jina-embeddings-v2-small-en')

    search_embedding = model.encode([n])[0]  # We get the first (and only) embedding
    results = table.search(search_embedding.tolist()).limit(10).to_list()  # or to_pandas()

    print(f"resulte len {len(results)}")

    # citations = []
    # for result in results:
    #     citations.append({
    #         "id": result['id'],
    #         "citationText": result['text']
    #     })

    # # Convert the list to a JSON string
    # output_json = json.dumps(citations, indent=4)

    # # You can now use this JSON string
    # print(output_json)

    # Pass the original string format to the baml client
    output_string = f"Semanitc similarity results for '{n}':"
    for result in results:
        print(result["id"])
        output_string += f"""
            ID:  {result['id']}
            CitationText:  {result['description']}
        """

    # context = vector_store.retrieve_context(question)
    response = b.RAGWithCitations(n, output_string)
    # print(response)
    # print("-" * 10)

    # return response.answer

    output = f"<div>{response.answer}:</dic><br><br><hr><div>Citations</div><br>"
    for result in response.citations:
        background_color = get_color_for_id_grey(result.id)
        output += f"""
        <div style="border: 1px solid #ddd; padding: 10px; margin-bottom: 10px; border-radius: 5px; background-color: {background_color};">
            <strong>ID:</strong> {result.id}<br>
            <p>Text:</p> {result.citationText}<br>
        </div>
        """

    return output


def graph_search(n):
    DB_NAME = "../../4-standardize/ex_kuzu_db.kz"

    model = SentenceTransformer("all-MiniLM-L6-v2")

    # Initialize the database
    db = kuzu.Database(DB_NAME, read_only=True)
    conn = kuzu.Connection(db)

    # result = conn.execute("CALL SHOW_TABLES() RETURN *;")
    # print("\n=== Formatted Schema Output ===")
    # while result.has_next():
    #     row = result.get_next()
    #     # Access specific columns (adjust column names based on actual output)
    #     print(f"Table: {row[0]}")
    #     print(f"Type: {row[1]}")
    #     print(f"Properties: {row[2]}")
    #     print("-" * 40)

    # Install and load vector extension once again
    conn.execute("INSTALL VECTOR;")
    conn.execute("LOAD VECTOR;")

    query_vector = model.encode(n).tolist()
    result = conn.execute(
        """
        CALL QUERY_VECTOR_INDEX(
            'Chunk',
            'chunk_vec_index',
            $query_vector,
            5
        )
        RETURN node.chunkid, distance ORDER BY distance;
        """,
        {"query_vector": query_vector})

    print(result.get_as_df())

    output = f"<div></dic><br><br><hr><div>Coming</div><br>"

    # output = f"<div>{response.answer}:</dic><br><br><hr><div>Citations</div><br>"
    # for result in response.citations:
    #     background_color = get_color_for_id_grey(result.id)
    #     output += f"""
    #     <div style="border: 1px solid #ddd; padding: 10px; margin-bottom: 10px; border-radius: 5px; background-color: {background_color};">
    #         <strong>ID:</strong> {result.id}<br>
    #         <p>Text:</p> {result.citationText}<br>
    #     </div>
    #     """

    return output



def chat_search_old(n):
    # set up elements
    uri = "../../stores/lance/db"
    db = lancedb.connect(uri)

    client = Client(host='http://192.168.202.88:11434')

    SYSTEM = """
    You will receive paragraphs of text for documents discussing FAIR principles.
    Answer the subsequent question using that context.  Try to cite your sources using the "id" field and
    provide a coherent response but do not feel obligated to use all the context items.
    """

    search_text = n
    table = db.open_table("source")

    search_embedding = model.encode([search_text])[0]  # We get the first (and only) embedding
    results = table.search(search_embedding.tolist()).limit(10).to_list()  # or to_pandas()

    # rows = (table.search(question).limit(5).to_pydantic(Schema))  # AH!   here is the cast to pydantic vrs to list.
    # context = extract_context(rows)
    context = extract_context(results)
    stream = client.chat(
        model="llama3.2", stream=False,
        messages=[
            {"role": "system", 'content': SYSTEM},
            {"role": "user", 'content': f"Context: {context}"},
            {"role": "user", 'content': f"Question: {search_text}"}
        ]
    )
    # for chunk in stream:
    #     print(chunk['message']['content'], end='', flush=True)

    # chat_searchv2(n)

    return stream['message']['content']

# Create a true light theme with explicit light colors
light_theme = gr.themes.Default().set(
    body_background_fill="white",
    body_text_color="#2c3e50",
    background_fill_primary="white",
    background_fill_secondary="#f8f9fa",
    background_fill_secondary_dark="#f8f9fa",
    border_color_primary="#dee2e6",
    button_primary_background_fill="#007bff",
    button_primary_text_color="white"
)

# Add custom CSS for light mode
custom_css = """
body, .gradio-container {
    background-color: white !important;
    color: black !important;
}
.dark {
    background-color: white !important;
    color: black !important;
}
"""

#with gr.Blocks(theme=gr.themes.Soft()) as demo:
# with gr.Blocks(title="DSWB playground", theme=light_theme, css=custom_css) as demo:

my_theme = gr.Theme.from_hub("gradio/seafoam")

#with gr.Blocks(title="DSWB playground", theme=gr.themes.Soft()) as demo:
with gr.Blocks(title="DSWB playground") as demo:   # , theme=my_theme
    gr.Markdown("# DSWB playground")

    with gr.Tab("Comparative Search"):
        name = gr.Textbox(label="Search Phrase")
        greet_btn = gr.Button("Search")

        with gr.Row():
            with gr.Column(scale=2):
                output1 = gr.HTML(label="Text Search")
            with gr.Column(scale=2):
                output2 = gr.HTML(label="Semantic Similarity")
            with gr.Column(scale=2):
                output3 = gr.HTML(label="Hybrid Search")

        greet_btn.click(fn=combined_search, inputs=name, outputs=[output1, output2, output3], api_name="combined_search")

    with gr.Tab("VectorRAG Summary"):
        name_input = gr.Textbox(label="Enter your question")
        greet_button = gr.Button("Generate VectorRAG query summary")
        greeting_output = gr.Markdown(label="Response")

        greet_button.click(fn=chat_search, inputs=name_input, outputs=greeting_output)

    with gr.Tab("Graph Search"):
        gs_input = gr.Textbox(label="Enter your question")
        gs_button = gr.Button("NO GRAPH generated yet, do not use:      Generate graph query summary")
        gs_output = gr.Markdown(label="Response")

        gs_button.click(fn=graph_search, inputs=gs_input, outputs=gs_output)

    with gr.Tab("About & Examples"):
        gr.HTML(usage_info.about())



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--share', action='store_true', help='Enable Gradio sharing')
    args = parser.parse_args()

    demo.launch(server_name="0.0.0.0", share=args.share, mcp_server=True)
