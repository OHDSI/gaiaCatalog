import geopandas as gpd
import sys
import argparse
import morph_kgc
import pandas as pd

def print_info(parquet_file):
    gdf = gpd.read_parquet(parquet_file)

    # Print len
    print("Length:", len(gdf))

    # Print all columns
    print("Columns:", list(gdf.columns))

    # Select some columns to test with
    selected_cols = ['id', 'title', 'depth_max_in_meters', 'description', 'geometry', 'mission', 'themes']
    if all(col in gdf.columns for col in selected_cols):
        subset_gdf = gdf[selected_cols]
        print(subset_gdf.head(10))
    else:
        missing = [col for col in selected_cols if col not in gdf.columns]
        print(f"One or more columns not found: {missing}. Full columns: {list(gdf.columns)}")

    ## TODO add in the elements to convert the dataframe to RDF via RML

def rml_mapping(parquet_file, template):
    gdf = gpd.read_parquet(parquet_file)

    # Convert geometry to WKT strings for RML compatibility
    # gdf['geometry'] = gdf['geometry'].apply(lambda geom: geom.wkt if geom else '')
    gdf2 = gdf.drop(columns='geometry')
    df = pd.DataFrame(gdf2)

    data_dict = {"variable1": df}

    config = f"""
        [DataSource]
        mappings={template}
        output_format=nt
        number_of_processes=1
    """

    g_rdflib = morph_kgc.materialize(config) # ), data_dict)

    # Ensure we get text N-Triples serialization
    nt = g_rdflib.serialize(format="nt")
    if isinstance(nt, bytes):  # depending on rdflib version
        nt = nt.decode("utf-8")
    return nt

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Geoparquet processing tool")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Available commands")

    # 'info' subcommand
    info_parser = subparsers.add_parser("info", help="Print parquet file info")
    info_parser.add_argument("-parquet", required=True, help="Path to the parquet file")

    # 'rml' subcommand
    rml_parser = subparsers.add_parser("rml", help="Run RML mapping")
    rml_parser.add_argument("-parquet", required=True, help="Path to the parquet file")
    rml_parser.add_argument("-mapping", required=True, help="Path to the mapping template file")

    args = parser.parse_args()

    if args.command == "info":
        print_info(getattr(args, "parquet"))
    elif args.command == "rml":
        result = rml_mapping(getattr(args, "parquet"), getattr(args, "mapping"))
        print(result)
