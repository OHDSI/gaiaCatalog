# 1-Input

## About

In this stage we are really just marshalling our date sources.   For me this is generally
either to a graph or to lanceDB.  Lance is an arrow based columnar store and 
enables full text indexing and embedding search.  So when combined with a graph, 
gives my core trifecta of stores I am after.  With things like Qlever also allowing
some spatial and basic temporal elements.


### [jsonld2lanceDuckDB.py](jsonld2lanceDuckDB.py)

Converts the jsonld in stores/input into a lancedb instance along with embeddings for 
vector search


### [rdfBuilder.py](rdfBuilder.py)

Converts the JSON-LD in stores/input into a RDF graph.   Output is hard coded to ../stores/output.nt


## [pdf2MarkdownAndTables.py](pdf2MarkdownAndTables.py)

NOT USED: Converts the PDF in stores/input into a markdown file.


