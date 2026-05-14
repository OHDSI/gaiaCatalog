import lancedb
import pandas as pd
import torch
import hashlib
from lancedb.pydantic import LanceModel, Vector
from lancedb.embeddings import get_registry
from gliner import GLiNER
from sentence_transformers import SentenceTransformer
from collections import defaultdict

device = "cuda:0"

model = GLiNER.from_pretrained("urchade/gliner_medium-v2.1", torch_dtype=torch.float16).to(device)

class DocVector(LanceModel):
    start: int
    end: int
    text: str
    label: str
    score: float
    id: str
    docName: str
    chunk: str
    chunkid: str
    embeddings: Vector(512)  # Add embeddings vector column


def er_functionNG(text):
    target_entities = [
        "Person",
        "Organization",
        "Location",
        "Geo-Political Entity",
        "Facility",
        "Event",
        "Law",
        "Product",
        "Work of Art",
        "Temporal Entity",
        "Numerical Value",
        "Language/Nationality",
        "Biological Entity",
        "Chemical Substance",
        "Natural Phenomenon",
        "Geographical Feature",
        "Infrastructure",
        "Technology",
        "Measurement/Indicator",
        "Land Use/Property",
        "Institution/Service",
        "Environmental Hazard",
        "Natural Resource",
        "Demographic/Social Indicator",
        "Administrative Division",
        "Hazard Zone",
        "Transportation Network",
        "Energy/Utility Infrastructure",
        "Communication Network",
        "Public Facility"
    ]

    entities = model.predict_entities(text, target_entities, threshold=0.5)
    return entities

def processor(db_path: str = None, source_table: str = None, output_table: str = None,):
    # Initialize embedding model
    embedding_model = SentenceTransformer("jinaai/jina-embeddings-v2-small-en", device="cpu")
    
    # set up elements
    db = lancedb.connect(db_path)
    table = db.open_table(source_table)

    df = table.to_pandas()
    df_b = pd.DataFrame()

    for index, row in df.iterrows():
        # result_dict = er_function(row["description"])
        result_dict = er_functionNG(row["description"])
        if result_dict:
            df_er = pd.DataFrame(result_dict)
            df_er["id"] = row["id"]
            df_er["docName"] = row["filename"]
            df_er["chunk"] = row["description"]
            df_er["chunkid"] = hashlib.md5(row["description"].encode()).hexdigest()
            df_b = pd.concat([df_b, df_er], ignore_index=True)

    # Generate embeddings for the extracted text entities
    print("Generating embeddings for extracted entities...")
    entity_texts = df_b['chunk'].tolist()  ## TODO:  was on 'text', but this a bad column to do this on, try "chunk"?   or other?
    embeddings = embedding_model.encode(entity_texts, show_progress_bar=True).tolist()
    df_b['embeddings'] = embeddings

    # df_b.to_csv('original_dataframe.csv', index=False)

    db = lancedb.connect(db_path)
    if output_table in db.table_names():
        db.drop_table(output_table)
    
    # Create table with embeddings support
    table = db.create_table(output_table, schema=DocVector.to_arrow_schema())
    table.add(data=df_b)
    
    # Create full text index on relevant text columns
    print("Creating full text search index...")
    table.create_fts_index(["text", "chunk"], replace=True, use_tantivy=True)
    
    print(f"Table '{output_table}' created with embeddings and full text index.")
