import duckdb
from sentence_transformers import SentenceTransformer
from lancedb.pydantic import LanceModel, Vector
import lancedb
import hashlib
import pandas as pd
from typing import Optional
from chonkie import LateChunker, RecursiveRules, SemanticChunker

class DocVector(LanceModel):
    id: str
    name: str
    description: str
    license: str | None
    filename: str
    embeddings: Vector(512)  # shouldn't this be 768

def lchunkText(full_text: str = None,):
    late_chunker = LateChunker(
        embedding_model="all-MiniLM-L6-v2",  # options: jinaai/jina-embeddings-v2-small-en,  all-MiniLM-L6-v2
        # mode="sentence",
        chunk_size=512,
        rules=RecursiveRules(),
        # min_characters_per_chunk=24,
        # min_sentences_per_chunk=1,
        # min_characters_per_sentence=12,
        device="cpu",   # set to 'cpu' if you don't have a cuda GPU or enough memory
    )

    lchunks = late_chunker(full_text)
    return lchunks

def main():
    # Directory containing the JSON files
    json_dir = '../stores/input/'  # Change this to your directory
    # json_dir = '../stores/input/'  # Change this to your directory

    # directly query a JSON file
    # TODO review issue here where description is reading like an array
    df = duckdb.sql(f"SELECT name, description, license, filename FROM read_json('{json_dir}*.json', filename=true)").to_df()

    # Add an 'id' column by creating a SHA256 hash of the filename
    df['id'] = df['filename'].apply(lambda x: hashlib.sha256(x.encode()).hexdigest())

    # Chunk the description text. This will create a list of chunks for each row.
    # TODO   this obviously isn't returning what I expect in this case!   look at the df.head() output
    # the lchunkText is returning chunks?  not embeddings?
    df['embeddings'] = df['description'].apply(lambda x: lchunkText(x))

    # Explode the DataFrame to create a new row for each text chunk.
    # df = df.explode('embeddings').reset_index(drop=True)

    # Initialize the sentence transformer model
    # model = SentenceTransformer("jinaai/jina-embeddings-v2-small-en", device="cpu")
    # Create the embeddings from the chunked descriptions
    # The tolist() is important for performance with sentence-transformers
    # df['embeddings'] = model.encode(df['description'].str, show_progress_bar=True).tolist()

    print(df.head())

    db = lancedb.connect("../stores/lance/db")
    if "source" in db.table_names():
        db.drop_table("source")
    table = db.create_table("source", schema=DocVector.to_arrow_schema())
    table.add(data=df)
    # table = db.create_table("source", data=df, mode="overwrite")
    table.create_fts_index(["description"], replace=True, use_tantivy=True )  ## create the text index, replace it if it already exists

if __name__ == '__main__':
    main()
