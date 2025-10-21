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
import json

# Initialize the Visualizer
viz = Visualizer()

def extract_text(obj):
         texts = []
         if isinstance(obj, dict):
             for key, value in obj.items():
                 if key in ['description', 'name', 'label', 'content', '@value']:  # Add relevant keys
                     if isinstance(value, str):
                         texts.append(value)
                     elif isinstance(value, list):
                         texts.extend([v for v in value if isinstance(v, str)])
                 else:
                     texts.extend(extract_text(value))  # Recurse
         elif isinstance(obj, list):
             for item in obj:
                 texts.extend(extract_text(item))
         return texts

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

    ## TODO  make this the set of JSON-LD documents in ../stores/input/
    SOURCES = [
        '081b254df8d9_dg.json',
        '409f16b43a60_dg.json',
        '851de0746bfb_dg.json',
        'b69933d7017a_dg.json',
        '096cbb634605_dg.json',
        '44933445991d_dg.json',
        '87e9e33549b7_dg.json',
        'b8df4e0677e7_dg.json',
        '0a1b8d369227_dg.json',
        '4687adf9cdde_dg.json',
        '898560ecf97e_dg.json',
        'b9183ce8ea43_dg.json',
        '0a2deae259df_dg.json',
        '48d93a0b96d1_dg.json',
        '89a2f63bbde0_dg.json',
        'b99c9ab19e78_dg.json',
        '13594d3e6654_dg.json',
        '4aca80ef82c3_dg.json',
        '8b1ec6110f6a_dg.json',
        'bde2b41f49a1_dg.json',
        '17ee8d524408_dg.json',
        '4b0fe7a62a8a_dg.json',
        '8f47e6e1e744_dg.json',
        'c2cebc3ca9f7_dg.json',
        '1b0aab7cb6de_dg.json',
        '4b7cd07f3788_dg.json',
        '8f8de5edf0c5_dg.json',
        'c5126aa7f696_dg.json',
        '1b4a595ba463_dg.json',
        '4d47a298679c_dg.json',
        '913262ed4f99_dg.json',
        'c6b7c14e5a50_dg.json',
        '21ef41cd70bb_dg.json',
        '4d6d47f03e50_dg.json',
        '918c8c7ed097_dg.json',
        'cabb24be4af6_dg.json',
        '22b3db73c13f_dg.json',
        '51f630597395_dg.json',
        '93a0e987e3a7_dg.json',
        'cbbfd218fd1a_dg.json',
        '23bc93201842_dg.json',
        '54407cf65b43_dg.json',
        '9732791c35ac_dg.json',
        'd2af193f16a7_dg.json',
        '25984b130782_dg.json',
        '5af3741cd9d2_dg.json',
        '9d29f3701239_dg.json',
        'd2dc7886a089_dg.json',
        '303dd78a2ec2_dg.json',
        '62ec1e750084_dg.json',
        'a07d6eb84eb9_dg.json',
        'd33bb313828d_dg.json',
        '30b0e130b8fd_dg.json',
        '64bd27a5605a_dg.json',
        'a1832eb49774_dg.json',
        'd98c1ddad777_dg.json',
        '32168e5cbeb7_dg.json',
        '6835aa51a1d6_dg.json',
        'a2b4fc367066_dg.json',
        'e0cc193fd16f_dg.json',
        '322ff892d8b5_dg.json',
        '6b25eb44747f_dg.json',
        'a38277ddb41e_dg.json',
        'e2596f561243_dg.json',
        '3917b06f81da_dg.json',
        '6d6f2c14a4e2_dg.json',
        'a752184d977b_dg.json',
        'e6579c75f206_dg.json',
        '3b6ef49af3f5_dg.json',
        '73484f5246ad_dg.json',
        'a7e6ea9f11d3_dg.json',
        'e88d00bba958_dg.json',
        '3eb31259068b_dg.json',
        '78d1d628fa5b_dg.json',
        'a860687282ec_dg.json',
        'ec9712bb85d0_dg.json',
        '3f20927b5639_dg.json',
        '790e9d901cfc_dg.json',
        'a95e092bab6a_dg.json',
        'ede0d80b1a31_dg.json',
        '3faed2e83308_dg.json',
        '7b7434c73442_dg.json',
        'aaa5282ac6f8_dg.json',
        'f0a97ed89eb8_dg.json',
        '3fbdd982ee8c_dg.json',
        '7c7f48f6d5f6_dg.json',
        'ae32b43d8224_dg.json',
        'f83229981133_dg.json',
        '408b8a13ef6a_dg.json',
        '7e17e42a7135_dg.json',
        'b4ec44fb5d17_dg.json',
        'f9d4d442ebd5_dg.json'
    ]


    # full_text = read_file("../1-Input/docling_paper.md")

    df_list = []
    for source in SOURCES:
        p = f"../stores/input/{source}"

        # For JSON[LD] files
        with open(p, 'r', encoding='utf-8') as f:
                 data = json.load(f)

        full_text = ' '.join(extract_text(data))


        # # For PDF files
        # doc = fitz.open(p)
        # full_text = ""
        # for page in doc:
        #     full_text += page.get_text()

        # lchunks = lchunkText(full_text)  # or schunkText if you want
        schunks = schunkText(full_text)
        # viz.print(chunks)   #Or you can directly call the Visualizer object
        # viz.save("lchunks.html", lchunks)

        # Create a DataFrame for the current source and add it to our list
        # hashes = [hashlib.md5(chunk.text.encode()).hexdigest() for chunk in lchunks]
        # source_df = pd.DataFrame({
        #     "id": [f"urn://{source}/{h}" for h in hashes],
        #     "embeddings": [chunk.embedding.tolist() for chunk in lchunks],
        #     "text": [chunk.text for chunk in lchunks],
        #     "docName": source
        # })

        # Adjust DataFrame creation for schunks instead of lchunks
        hashes = [hashlib.md5(chunk.text.encode()).hexdigest() for chunk in schunks]
        source_df = pd.DataFrame({
            "id": [f"urn://{source}/{h}" for h in hashes],
            # "embeddings": [chunk.embedding.tolist() for chunk in schunks],
            "text": [chunk.text for chunk in schunks],
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
    table.create_fts_index(["text"], replace=True, use_tantivy=True)  ## create the text index, replace it if it already exists

    # print(embeddings_df)

if __name__ == '__main__':
    main()
