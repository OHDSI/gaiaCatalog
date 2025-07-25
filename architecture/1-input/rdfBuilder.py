import os
import json
from rdflib import Graph, plugin
from rdflib.serializer import Serializer

# This script converts JSON-LD files to N-Triples format (.nt).
# It processes all .json files in the specified input directory and saves the
# output to a single .nt file in the output directory.
# The script handles blank nodes by ensuring they are unique across all processed files.

# Define the input and output directories relative to the script's location.
script_dir = os.path.dirname(os.path.abspath(__file__))
input_dir = os.path.join(script_dir, '../stores/input')
output_dir = script_dir

# Define the output file path.
output_file = os.path.join(output_dir, 'output.nt')

# Create an RDF graph to hold the combined data from all JSON-LD files.
g = Graph()

# Iterate over all files in the input directory.
for filename in os.listdir(input_dir):
    if filename.endswith('.json'):
        file_path = os.path.join(input_dir, filename)

        # Read the JSON-LD data from the file.
        with open(file_path, 'r') as f:
            data = json.load(f)

        # Parse the JSON-LD data into the graph.
        # The graph will automatically handle blank node naming to avoid conflicts.
        g.parse(data=json.dumps(data), format='json-ld')

# Serialize the entire graph to N-Triples format.
with open(output_file, 'wb') as f:
    g.serialize(destination=f, format='nt')

print(f"Conversion complete. All JSON-LD files have been converted to {output_file}")
