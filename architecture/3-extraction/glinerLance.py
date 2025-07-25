#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.12,<3.13"
# dependencies = [
#   "utca",
#   "datasets",
#   "torch",
#   "setuptools",
#   "gliner==0.2.21",
# ]
# ///

import lancedb
from lancedb.pydantic import LanceModel, Vector
from lancedb.embeddings import EmbeddingFunctionRegistry
# from sentence_transformers import SentenceTransformer
# import random
# import json
# from ollama import Client
# from rich.console import Console
# from baml_client import b

# from gliner import GLiNER
# import datasets
import pandas as pd
# from tqdm import tqdm
import torch
import hashlib
from lancedb.pydantic import LanceModel, Vector


from gliner import GLiNER
import datasets
from tqdm import tqdm


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

def er_function(text):

    labels = [
        "Persistent Identifier",
        "DOI",
        "ORCID",
        "Metadata",
        "Data Repository",
        "Search Engine",
        "Data Catalog",
        "Unique Identifier",
        "Registry",
        "Open Access",
        "Data Access Protocol",
        "Authentication System",
        "Authorization",
        "API",
        "Data License",
        "Access Control",
        "HTTP Protocol",
        "Secure Data Transfer",
        "RDF",
        "Ontology",
        "Controlled Vocabulary",
        "Data Standard",
        "JSON-LD",
        "XML",
        "Semantic Web",
        "Linked Data",
        "Schema.org",
        "Interoperability Framework",
        "Creative Commons License",
        "Data Provenance",
        "Data Citation",
        "Machine-Readable Format",
        "Data Documentation",
        "Usage Policy",
        "Community Standard",
        "Data Reuse",
        "License Agreement",
        "FAIR Principles",
        "Data Management Plan",
        "Data Steward",
        "Research Data",
        "Open Science",
        "Data Sharing",
        "FAIR Compliance",
        "Data Infrastructure",
        "Digital Repository",
        "Data Quality",
        "Author", "Researcher", "Scientist", "Corresponding Author", "Collaborator",
        "Patient", "Study Participant", "Institution", "Research Institute", "University",
        "Laboratory", "Company", "Funding Agency", "Consortium", "Hospital",
        "Government Agency", "Gene", "Peptide", "Protein", "Enzyme", "Pathway", "Disease",
        "Virus", "Bacteria", "Drug", "Compound", "Cell Type", "Tissue", "Organ",
        "System", "Biomarker", "Mutation", "Phenotype", "Genotype", "Citation", "Journal",
        "Publisher", "Article Title", "DOI", "Grant Number", "Ethics Committee",
        "Study Type", "Software", "Algorithm", "Model", "Protocol",
        "Experiment", "Figure", "Table", "Keyword", "Technology",
        "Equipment", "Location", "Date", "Event", "Project", "Standard", "Metric",
        "Method", "Result", "Failure", "Success"
    ]

    entities = model.predict_entities(text, labels, threshold=0.6)
    return entities


# set up elements
uri = "../../stores/lance/db"
db = lancedb.connect(uri)
table = db.open_table("chonkey")

print(table.schema)   #  id, embeddings, text, docName
df = table.to_pandas()

df_b = pd.DataFrame()

for index, row in df.iterrows():
    result_dict = er_function(row["text"])
    if result_dict:
        df_er = pd.DataFrame(result_dict)
        df_er["id"] = row["id"]
        df_er["docName"] = row["docName"]
        df_er["chunk"] = row["text"]
        df_er["chunkid"] = hashlib.md5(row["text"].encode()).hexdigest()
        df_b = pd.concat([df_b, df_er], ignore_index=True)
    print(len(df))

# print(df_b.head(10))
# print(len(df_b))

df_b.to_csv('original_dataframe.csv', index=False)


db = lancedb.connect("../../stores/lance/db")
if "entities" in db.table_names():
    db.drop_table("entities")
table = db.create_table("entities", schema=DocVector.to_arrow_schema())
table.add(data=df_b)
# table = db.create_table("chonkey", data=embeddings_df, mode="overwrite")
table.create_fts_index(["text"], replace=True)  ## create the text index, replace it if it already exists