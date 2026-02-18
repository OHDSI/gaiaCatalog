import polars as pl
import lancedb

# this code and other places where I do these types
# of actions with lance could be done with
# duckdb.
# See: https://lance.org/integrations/duckdb/#vector-search


def list_tables_and_columns(db_path: str, table_name: str = None):
    """
    Connects to a LanceDB database and lists tables and their columns.
    If an optional table_name is provided, only lists columns for that table.

    Args:
        db_path (str): Path to the LanceDB database.
        table_name (str, optional): Specific table name to list columns for.

    Returns:
        dict: A dictionary where keys are table names and values are lists of column names.
    """
    db = lancedb.connect(db_path)

    if table_name:
        if table_name not in db.table_names():
            raise ValueError(f"Table '{table_name}' does not exist in the database.")
        table = db.open_table(table_name)
        columns = table.schema.names  # PyArrow schema provides column names
        result = {table_name: columns}
    else:
        result = {}
        table_names = db.table_names()
        for name in table_names:
            table = db.open_table(name)
            columns = table.schema.names
            result[name] = columns

    return result

def pretty_table_print(result: dict):
    """Print the database structure in a nice, readable format."""
    print("=" * 60)
    print("DATABASE STRUCTURE")
    print("=" * 60)

    for table_name, columns in result.items():
        print(f"\n📋 Table: {table_name}")
        print("-" * (len(table_name) + 10))
        print(f"Columns ({len(columns)}):")

        for i, column in enumerate(columns, 1):
            print(f"  {i:2d}. {column}")

        if len(result) > 1:  # Only add separator if there are multiple tables
            print("\n" + "." * 40)

    print("\n" + "=" * 60)

def lance_list(db_path: str, table_name: str = None):
    if table_name:
        result_specific = list_tables_and_columns(db_path, table_name)
        pretty_table_print(result_specific)
    else:
        result = list_tables_and_columns(db_path)
        pretty_table_print(result)

def lance_head(db_path: str, table_name: str, n: int = 10):
    """
    Read the first N rows from a LanceDB table into a Polars DataFrame and print it.

    Args:
        db_path (str): Path to the LanceDB database.
        table_name (str): Name of the table to read.
        n (int): Number of rows to read (default: 10).
    """
    try:
        # Connect to the database
        db = lancedb.connect(db_path)

        # Check if table exists
        if table_name not in db.table_names():
            print(f"Error: Table '{table_name}' does not exist in the database.")
            print(f"Available tables: {', '.join(db.table_names())}")
            return

        # Open the table and read first N rows
        table = db.open_table(table_name)

        # Convert to Polars DataFrame - limit to first N rows
        df = table.to_pandas().head(n)  # First convert to pandas with limit
        polars_df = pl.from_pandas(df)  # Then convert to polars

        print(f"\nFirst {min(n, len(polars_df))} rows from table '{table_name}':")
        print("=" * 80)
        
        # Configure Polars to show all columns
        with pl.Config(tbl_cols=-1):  # -1 means show all columns
            print(polars_df)
            
        print("=" * 80)
        print(f"Shape: {polars_df.shape} (showing {min(n, len(polars_df))} of {table.count_rows()} total rows)")

    except Exception as e:
        print(f"Error reading table: {e}")