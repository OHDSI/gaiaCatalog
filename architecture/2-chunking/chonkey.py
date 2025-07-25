import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)  ## remove pandas future warning
warnings.filterwarnings("ignore", category=UserWarning)
from chonkie import LateChunker, RecursiveRules, SemanticChunker
import pandas as pd
import requests
import fitz # PyMuPDF
import pymupdf
from chonkie import Visualizer
from sentence_transformers import SentenceTransformer
from lancedb.pydantic import LanceModel, Vector
import lancedb
import hashlib

# Initialize the Visualizer
viz = Visualizer()

class DocVector(LanceModel):
    id: str
    embeddings: Vector(512)  # shouldn't this be 768
    text: str
    docName: str


def read_file(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
            return content
    except FileNotFoundError:
        print(f"Error: The file {file_path} was not found.")
    except PermissionError:
        print(f"Error: No permission to read {file_path}.")
    except Exception as e:
        print(f"An error occurred: {e}")
    return None

def lchunkText(full_text: str = None,):
    late_chunker = LateChunker(
        embedding_model="jinaai/jina-embeddings-v2-small-en",
        # embedding_model="all-MiniLM-L6-v2",
        # mode="sentence",
        chunk_size=512,
        rules=RecursiveRules(),
        # min_characters_per_chunk=24,
        # min_sentences_per_chunk=1,
        # min_characters_per_sentence=12,
        device="cpu",
    )

    lchunks = late_chunker(full_text)

    return lchunks

def schunkText(full_text: str = None,):
    # Basic initialization with default parameters
    sem_chunker = SemanticChunker(
        embedding_model="jinaai/jina-embeddings-v2-small-en",  # Default model
        # embedding_model="sentence-transformers/all-MiniLM-L6-v2",
        threshold=0.5,                               # Similarity threshold (0-1) or (1-100) or "auto"
        chunk_size=512,                              # Maximum tokens per chunk
        min_sentences=1                              # Initial sentences per chunk
    )

    schunks = sem_chunker(full_text)

    return schunks


def main():
    SOURCES = [
        "source files",
        "more_source_files"
    ]

    # full_text = read_file("../1-Input/docling_paper.md")

    df_list = []
    for source in SOURCES:
        p = f"../stores/input/{source}"
        doc = fitz.open(p)
        full_text = ""
        for page in doc:
            full_text += page.get_text()

        lchunks = lchunkText(full_text)  # or schunkText if you want
        # viz.print(chunks)   #Or you can directly call the Visualizer object
        # viz.save("lchunks.html", lchunks)

        # Create a DataFrame for the current source and add it to our list
        hashes = [hashlib.md5(chunk.text.encode()).hexdigest() for chunk in lchunks]
        source_df = pd.DataFrame({
            "id": [f"urn://{source}/{h}" for h in hashes],
            "embeddings": [chunk.embedding.tolist() for chunk in lchunks],
            "text": [chunk.text for chunk in lchunks],
            "docName": source
        })
        df_list.append(source_df)

    # Concatenate all the DataFrames in the list into a single DataFrame
    embeddings_df = pd.concat(df_list, ignore_index=True)

    db = lancedb.connect("../stores/lance/db")
    if "chonkey" in db.table_names():
        db.drop_table("chonkey")
    table = db.create_table("chonkey", schema=DocVector.to_arrow_schema())
    table.add(data=embeddings_df)
    # table = db.create_table("chonkey", data=embeddings_df, mode="overwrite")
    table.create_fts_index(["text"], replace=True)  ## create the text index, replace it if it already exists

    # print(embeddings_df)

if __name__ == '__main__':
    main()
