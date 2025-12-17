import os
import json
import hashlib
from rdflib import ConjunctiveGraph, URIRef, plugin
from rdflib.serializer import Serializer

# TODO:  rdflib, not the best.  Would be good to move to pyoxigraph

# This script converts JSON-LD files to N-Triples format (.nt).
# It processes all .json files in the specified input directory and saves the
# output to a single .nt file in the output directory.
# The script handles blank nodes by ensuring they are unique across all processed files.

def jsonld2ntfile(input_dir: str = None, output_file: str = None):
    # Create an RDF graph to hold the combined data from all JSON-LD files.
    # pyoxigraph would be a better choice for this, but rdflib is simpler.
    g = ConjunctiveGraph()

    # Iterate over all files in the input directory.
    for filename in os.listdir(input_dir):
        if filename.endswith('.json'):
            file_path = os.path.join(input_dir, filename)

            # Read the JSON-LD data from the file.
            with open(file_path, 'r') as f:
                data = json.load(f)

            print(f"Processing {input_dir + filename}")
            file_hash = hashlib.sha256(str(input_dir + filename).encode()).hexdigest()
            graph_name = URIRef(f"http://ohdsi_gis.org/source/{file_hash}")

            # Parse the JSON-LD data into the graph.
            # The graph will automatically handle blank node naming to avoid conflicts.
            g.get_context(graph_name).parse(data=json.dumps(data), format='json-ld')

    # Serialize the entire graph to N-Triples format.
    with open(output_file, 'wb') as f:
        g.serialize(destination=f, format='nquads')

    print(f"Conversion complete. All JSON-LD files have been converted to {output_file}")
