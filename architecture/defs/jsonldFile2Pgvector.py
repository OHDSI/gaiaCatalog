import argparse
import hashlib
import logging
import warnings
from typing import List

import duckdb
import psycopg2
import transformers
from pgvector.psycopg2 import register_vector
from sentence_transformers import SentenceTransformer

transformers.logging.set_verbosity_error()
logging.getLogger("transformers").setLevel(logging.ERROR)

warnings.filterwarnings(
    "ignore",
    message="Some weights of BertModel were not initialized from the model checkpoint.*",
)
warnings.filterwarnings(
    "ignore",
    message=".*`torch.nn.functional.scaled_dot_product_attention` does not support.*",
)

logging.basicConfig(level=logging.INFO)


def embed_texts(texts: List[str], model_name: str) -> List[List[float]]:
    """Embed list of texts using SentenceTransformer."""
    model = SentenceTransformer(model_name, device="cpu")
    embeddings = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)
    return embeddings.tolist()


def processor(
    json_dir: str,
    host: str = "localhost",
    port: int = 5432,
    user: str = "postgres",
    password: str = "",
    dbname: str = "gaia_catalog",
    table_name: str = "source",
    model: str = "jinaai/jina-embeddings-v2-small-en",
    overwrite: bool = True,
) -> None:
    """Process JSON-LD directory to pgvector table with FTS and HNSW index."""
    logging.info(
        f"Processing {json_dir} -> Postgres://{user}@{host}:{port}/{dbname}.{table_name}"
    )

    # Read and clean data with duckdb
    query = f"""
        SELECT name, description, license, filename
        FROM read_json('{json_dir}/*.json',
                       filename = true,
                       ignore_errors = true,
                       maximum_object_size = 10000000,
                       format = 'auto')
    """
    df = duckdb.sql(query).to_df()

    if df.empty:
        logging.warning("No JSON-LD data found in directory.")
        return

    # Clean data
    df["name"] = df["name"].fillna("").astype(str)
    df["description"] = df["description"].fillna("").astype(str)
    df["license"] = df["license"].fillna("")
    df["filename"] = df["filename"].astype(str)
    df["id"] = df["filename"].apply(lambda x: hashlib.sha256(x.encode()).hexdigest())

    # Generate embeddings
    descriptions = df["description"].tolist()
    logging.info(f"Generating embeddings for {len(descriptions)} descriptions...")
    embeddings = embed_texts(descriptions, model)
    dim = len(embeddings[0]) if embeddings and len(embeddings[0]) > 0 else 512
    logging.info(f"Embedding dimension: {dim}")

    # Prepare insert data
    data = [
        (
            row["id"],
            row["name"],
            row["description"],
            row["license"],
            row["filename"],
            emb,
        )
        for row, emb in zip(df.itertuples(index=False), embeddings)
    ]

    # Setup database
    setup_conn = psycopg2.connect(
        host=host, port=port, user=user, password=password, dbname="postgres"
    )
    setup_conn.autocommit = True
    setup_cur = setup_conn.cursor()
    setup_cur.execute("SELECT 1 FROM pg_database WHERE datname = %s;", (dbname,))
    if not setup_cur.fetchone():
        logging.info(f"Creating database '{dbname}'...")
        setup_cur.execute(f"CREATE DATABASE {dbname};")
        logging.info(f"Database '{dbname}' created.")
    setup_cur.close()
    setup_conn.close()

    # Connect to target database
    conn = psycopg2.connect(
        host=host, port=port, user=user, password=password, dbname=dbname
    )
    register_vector(conn)
    cur = conn.cursor()

    # Extensions and schema
    try:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        conn.commit()
    except Exception as e:
        logging.error(f"Vector extension issue: {e}")

    if overwrite:
        cur.execute(f"DROP TABLE IF EXISTS {table_name} CASCADE;")
        conn.commit()
        logging.info(f"Dropped existing table '{table_name}'.")

    # Create table with FTS
    create_table_sql = f"""
        CREATE TABLE {table_name} (
            id text PRIMARY KEY,
            name text NOT NULL,
            description text NOT NULL,
            license text,
            filename text NOT NULL,
            embedding vector({dim}),
            description_tsvec tsvector GENERATED ALWAYS AS (
                to_tsvector('english', coalesce(description, ''))
            ) STORED
        );
    """
    cur.execute(create_table_sql)

    # Indices
    cur.execute(
        f"CREATE INDEX IF NOT EXISTS {table_name}_embedding_idx ON {table_name} USING hnsw (embedding vector_cosine_ops);"
    )
    cur.execute(
        f"CREATE INDEX IF NOT EXISTS {table_name}_fts_idx ON {table_name} USING gin(description_tsvec);"
    )
    conn.commit()
    logging.info("Table and indices created.")

    # Bulk insert
    try:
        cur.executemany(
            f"""
            INSERT INTO {table_name} (id, name, description, license, filename, embedding)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
        """,
            data,
        )
        conn.commit()
        logging.info(f"Successfully inserted {len(data)} rows.")
    except Exception as e:
        logging.error(f"Bulk insert failed: {e}. Attempting row-by-row...")
        for i, row_data in enumerate(data):
            try:
                cur.execute(
                    f"""
                    INSERT INTO {table_name} (id, name, description, license, filename, embedding)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id) DO NOTHING
                """,
                    row_data,
                )
                conn.commit()
            except Exception as row_e:
                logging.error(f"Row {i} failed: {row_e}")
        logging.info("Row-by-row insert completed.")

    # Sample similarity query
    query_text = "data catalog description"
    query_emb = embed_texts([query_text], model)[0]
    cur.execute(
        f"""
        SELECT id, name, filename, 1 - (embedding <=> %s::vector) AS similarity
        FROM {table_name}
        ORDER BY embedding <=> %s::vector
        LIMIT 3;
    """,
        (query_emb, query_emb),
    )
    results = cur.fetchall()
    logging.info("Sample top-3 similarity matches:")
    for row in results:
        logging.info(
            f"  ID: {row[0]}, Name: {row[1][:50]}..., Similarity: {row[3]:.3f}"
        )

    cur.close()
    conn.close()
    logging.info("Process completed successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert JSON-LD files to Postgres pgvector table."
    )
    parser.add_argument(
        "--json_dir", required=True, help="Directory containing JSON-LD files (*.json)"
    )
    parser.add_argument("--host", default="localhost", help="Postgres host")
    parser.add_argument("--port", type=int, default=5432, help="Postgres port")
    parser.add_argument("--user", default="postgres", help="Postgres user")
    parser.add_argument("--password", default="", help="Postgres password")
    parser.add_argument("--dbname", default="gaia_catalog", help="Target database name")
    parser.add_argument("--table_name", default="source", help="Target table name")
    parser.add_argument(
        "--model", default="jinaai/jina-embeddings-v2-small-en", help="Embedding model"
    )
    parser.add_argument(
        "--overwrite", action="store_true", default=True, help="Drop table if exists"
    )
    args = parser.parse_args()
    processor(**vars(args))
