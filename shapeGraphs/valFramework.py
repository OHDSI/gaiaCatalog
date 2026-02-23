from pyshacl import validate

conforms, results_graph, results_text = validate(
    data_graph,
    shacl_graph=shapes_graph,
    advanced=True,  # enables SPARQL-based targets
)


