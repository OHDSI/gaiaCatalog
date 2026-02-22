import psycopg2
import numpy as np
from pgvector.psycopg2 import register_vector
import requests
import os

# OpenRouter API configuration
OPENROUTER_API_KEY = os.environ.get('OPENROUTER_API_KEY', 'your-api-key-here')
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/embeddings"

def get_embedding(text, model="openai/text-embedding-3-small"):
    """
    Get embedding from OpenRouter API

    Args:
        text: The text to embed
        model: The embedding model to use (default: openai/text-embedding-3-small)
               Other options: openai/text-embedding-3-large, openai/text-embedding-ada-002

    Returns:
        List of floats representing the embedding
    """
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }

    data = {
        "model": model,
        "input": text
    }

    response = requests.post(OPENROUTER_API_URL, headers=headers, json=data)
    response.raise_for_status()

    result = response.json()
    embedding = result['data'][0]['embedding']

    return embedding

# Database connection parameters
host = 'ghost.lan'
user = 'postgres'
password = 'mysecretpassword'
dbname = 'my_vector_db'

# Connect to the default 'postgres' database to check/create our target database
setup_conn = psycopg2.connect(host=host, user=user, password=password, dbname='postgres')
setup_conn.autocommit = True  # CREATE DATABASE cannot run inside a transaction
setup_cur = setup_conn.cursor()

setup_cur.execute("SELECT 1 FROM pg_database WHERE datname = %s;", (dbname,))
if not setup_cur.fetchone():
    print(f"Database '{dbname}' not found. Creating...")
    setup_cur.execute(f'CREATE DATABASE {dbname};')
    print(f"Database '{dbname}' created successfully.")
else:
    print(f"Database '{dbname}' already exists.")

setup_cur.close()
setup_conn.close()

# Connect to the target database
conn = psycopg2.connect(host=host, user=user, password=password, dbname=dbname)
register_vector(conn)
cur = conn.cursor()

# Ensure the pgvector extension is available
cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
conn.commit()

# Get the embedding dimension from the first test
print("Getting embedding dimension...")
test_embedding = get_embedding("test")
embedding_dim = len(test_embedding)
print(f"Embedding dimension: {embedding_dim}")

# Drop the table if it exists (to recreate with correct dimensions)
cur.execute("DROP TABLE IF EXISTS items CASCADE;")

# Create the table with the correct embedding dimension
cur.execute(f"""
    CREATE TABLE IF NOT EXISTS items (
        id serial PRIMARY KEY,
        content text,
        embedding vector({embedding_dim})
    );
""")

# Create an HNSW index for faster similarity searches (cosine similarity)
cur.execute("""
    CREATE INDEX IF NOT EXISTS items_embedding_idx
    ON items USING hnsw (embedding vector_cosine_ops);
""")

conn.commit()
print("Table created successfully")

# Sample data
contents = [
    "The quick brown fox jumps over the lazy dog.",
    "A cat sits on the mat.",
    "Birds fly high in the sky.",
    "Python is a great programming language."
]

# Generate real embeddings using OpenRouter
print("\nGenerating embeddings for sample data...")
embeddings = []
for i, content in enumerate(contents):
    print(f"  Embedding {i+1}/{len(contents)}: {content[:50]}...")
    embedding = get_embedding(content)
    embeddings.append(embedding)

# Insert sample data
print("\nInserting data into database...")
for content, embedding in zip(contents, embeddings):
    cur.execute("""
        INSERT INTO items (content, embedding)
        VALUES (%s, %s);
    """, (content, embedding))

# Commit the inserts
conn.commit()
print(f"Inserted {len(contents)} items")

# Perform a similarity search
query_text = "What is the best programming language?"
print(f"\nQuery: '{query_text}'")
print("Generating query embedding...")
query_embedding = get_embedding(query_text)

# Query for the top 2 most similar items using cosine distance
cur.execute("""
    SELECT id, content, embedding <=> %s::vector AS distance
    FROM items
    ORDER BY distance
    LIMIT 2;
""", (query_embedding,))

results = cur.fetchall()

# Print the results
print("\nSearch Results (most similar items):")
for i, row in enumerate(results, 1):
    print(f"\n{i}. ID: {row[0]}")
    print(f"   Content: {row[1]}")
    print(f"   Distance: {row[2]:.4f}")

# Close the cursor and connection
cur.close()
conn.close()
print("\nDone!")
