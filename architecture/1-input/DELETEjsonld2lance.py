import duckdb
from sentence_transformers import SentenceTransformer
from lancedb.pydantic import LanceModel, Vector
import lancedb
import hashlib
import pandas as pd
import numpy as np
from typing import Optional
from chonkie import LateChunker, RecursiveRules, SemanticChunker
import transformers
import warnings
import logging

transformers.logging.set_verbosity_error()
logging.getLogger("transformers").setLevel(logging.ERROR)

# Suppress specific warnings
warnings.filterwarnings("ignore",
                       message="Some weights of BertModel were not initialized from the model checkpoint.*")
warnings.filterwarnings("ignore",
                       message=".*`torch.nn.functional.scaled_dot_product_attention` does not support.*")


class DocVector(LanceModel):
    id: str
    name: str
    description: str
    license: str | None
    filename: str
    embeddings: Vector(512)

def lchunkText(full_text: str = None,):
    if full_text is None or not isinstance(full_text, str):
        return []
    
    late_chunker = LateChunker(
        embedding_model="jinaai/jina-embeddings-v2-small-en",  # options: jinaai/jina-embeddings-v2-small-en,  all-MiniLM-L6-v2
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
    
    # Directly query a JSON file
    df = duckdb.sql(f"SELECT name, description, license, filename FROM read_json('{json_dir}*.json', filename=true)").to_df()

    # Clean up data types to ensure compatibility
    # Handle None values and ensure string types
    df['name'] = df['name'].apply(lambda x: str(x) if x is not None else "")
    
    # If 'description' is a list of strings, join them into a single text
    df['description'] = df['description'].apply(lambda x: str(x) if x is not None else "")
    # df['description'] = df['description'].apply(lambda x: ' '.join(x) if isinstance(x, list) else
    #                                           (str(x) if x is not None else ""))
    
    # Handle None values in a license
    df['license'] = df['license'].fillna("")
    
    # Add an 'id' column by creating a SHA256 hash of the filename
    df['id'] = df['filename'].apply(lambda x: hashlib.sha256(str(x).encode()).hexdigest())

    # Chunk the description text. This will create a list of chunks for each row.
    # df['chunks'] = df['description'].apply(lchunkText.)
    
    # Filter out rows where chunking failed (returned empty lists)
    # df = df[df['chunks'].apply(lambda x: len(x) > 0)]
    
    # Explode the DataFrame to create a new row for each text chunk
    # df = df.explode('chunks').reset_index(drop=True)

    # The 'description' for the final table should be the chunk, not the original full description
    # df['description'] = df['chunks']
    # df = df.drop(columns=['chunks'])

    # Initialize the sentence transformer model
    model = SentenceTransformer("jinaai/jina-embeddings-v2-small-en", device="cpu")
    
    # Create the embeddings from the chunked descriptions
    # Ensure we're working with a list of strings
    descriptions = df['description'].tolist()
    print(f"Number of descriptions: {len(descriptions)}")
    embeddings = model.encode(descriptions, show_progress_bar=True).tolist()
    
    # Make sure embeddings are exactly 512 dimensions
    df['embeddings'] = embeddings
    
    # Verify all data types match expected schema
    # print("DataFrame info before adding to LanceDB:")
    # print(df.dtypes)
    # print(len(df))
    
    # Connect to the database and create/update the table
    db = lancedb.connect("../stores/lance/db")
    
    # Drop existing table if it exists
    if "source" in db.table_names():
        db.drop_table("source")
    
    # Create new table with the schema
    table = db.create_table("source", schema=DocVector.to_arrow_schema())
    
    # Convert each column to the correct type
    # Convert embeddings to the correct format if needed
    df_for_lance = df.copy()
    
    # Add the data to the table
    try:
        table.add(data=df_for_lance)
        print("Data successfully added to LanceDB table.")
        
        # Create text index
        table.create_fts_index(["description"], replace=True, use_tantivy=True)
        print("Text index created successfully.")
    except Exception as e:
        print(f"Error adding data to LanceDB: {e}")
        # Attempt to add data row by row if bulk add fails
        print("Attempting to add data row by row...")
        
        for i, row in df_for_lance.iterrows():
            try:
                # Convert row to dict and add to table
                row_dict = row.to_dict()
                table.add(data=[row_dict])
                print(f"Row {i} added successfully.")
            except Exception as e:
                print(f"Error adding row {i}: {e}")

if __name__ == '__main__':
    main()
