# Shapes


## Shapegraph

This section addresses some uses of SHACL for GaiaCatalog.  Be sure you have installed
[pyshacl](https://pypi.org/project/pyshacl/) first.   


```json
"@context": {
    "@vocab": "https://schema.org/"
  }
```

since the original context has some issues around the resolution of 
the context name space. 

We can use the pyshacl tool to test this.   A command like 

```bash
pyshacl -s gaiaShape1.ttl -sf turtle -df json-ld -f table example.json
```

will test example.json using the shape graph in gaiaShape1.ttl and 
provide the results in a table format. Example of the output can be seen below.  

Note, this shape file was intentionally designed to return some warnings.  Just as 
a demonstration.   It may well be that none of these _warnings_ are of concern. 
Once we have a working process flow, we can work to generate the constraints in the
shape file that are relevant.  

For example, it does look for a variable _latitude_ and _longitude_ in this case. 
Which this test passes.  If you remove or find an example without these, you should
see those errors raised as well.  

Errors can have three levels: WARNING, VIOLATION and RECOMMENDED.  So we can design the shape file with these various levels in mind.  

```bash
(.venv) ➜  shapeGraphs git:(master) ✗ pyshacl -s gaiaShape1.ttl -sf turtle -df json-ld -f table example.json

+----------+
| Conforms |
+----------+
|  False   |
+----------+

+-----+----------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+
| No. | Severity | Focus Node                | Result Path               | Message                   | Component                 | Shape                     | Value                     |
+-----+----------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+
| 1   | Warning  | N3fda2b31d0d5458b90a7a10f | https://schema.org/contac | Contact information shoul | MinCountConstraintCompone | https://oceans.collaboriu | -                         |
|     |          | e1eb1f5d                  | ts                        | d be provided             | nt                        | m.io/voc/validation/1.0.1 |                           |
|     |          |                           |                           |                           |                           | /shacl#coreContacts       |                           |
|     |          |                           |                           |                           |                           |                           |                           |
| 2   | Warning  | N3fda2b31d0d5458b90a7a10f | https://schema.org/citati | Citation information shou | MinCountConstraintCompone | https://oceans.collaboriu | -                         |
|     |          | e1eb1f5d                  | on                        | ld be provided            | nt                        | m.io/voc/validation/1.0.1 |                           |
|     |          |                           |                           |                           |                           | /shacl#coreCitation       |                           |
|     |          |                           |                           |                           |                           |                           |                           |
| 3   | Warning  | N3fda2b31d0d5458b90a7a10f | https://schema.org/measur | measurement method check  | MinCountConstraintCompone | https://oceans.collaboriu | -                         |
|     |          | e1eb1f5d                  | ementMethod               |                           | nt                        | m.io/voc/validation/1.0.1 |                           |
|     |          |                           |                           |                           |                           | /shacl#recMesMethod       |                           |
|     |          |                           |                           |                           |                           |                           |                           |
| 4   | Warning  | N3fda2b31d0d5458b90a7a10f | -                         | Graph requires ID         | NodeKindConstraintCompone | https://oceans.collaboriu | N3fda2b31d0d5458b90a7a10f |
|     |          | e1eb1f5d                  |                           |                           | nt                        | m.io/voc/validation/1.0.1 | e1eb1f5d                  |
|     |          |                           |                           |                           |                           | /shacl#IDShape            |                           |
|     |          |                           |                           |                           |                           |                           |                           |
+-----+----------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+---------------------------+%                             
```
       

## Appendix

### Current testing

```bash
 pyshacl -s ./gaiaRequirements.ttl -sf turtle -df json-ld -f table /home/fils/src/Projects/CODATA/INSPIRE/OHDSI-GIS-Metadata-Mapping/input/repo/mdc_private_schools/meta_json-ld_mdc_private_schools.json
 ```




