# 1-Input

## About

In this stage we are really just marshalling our date sources.   For me this is generally
either to a graph or to lanceDB.  Lance is an arrow based columnar store and
enables full text indexing and embedding search.  So when combined with a graph,
gives my core trifecta of stores I am after.  With things like Qlever also allowing
some spatial and basic temporal elements.


### [jsonld2lance.py](jsonld2lance.py)

Converts the jsonld in stores/input into a lancedb instance along with embeddings for
vector search


### [jsonld2nt.py](jsonld2nt.py)

Converts the JSON-LD in stores/input into a RDF graph.   Output is hard coded to ../stores/output.nt


## [pdf2Markdown.py](pdf2Markdown.py)

```
python pdf2Markdown.py --source /home/fils/src/Projects/NIAID/domainAssessment/sof/source_docs/reports/BV_BRC_BriefSummary_OfBlueprintAlignment_Revised_.pdf --text-output out.md --tables-output tables.md
```

NOT USED: Converts the PDF in stores/input into a markdown file.
