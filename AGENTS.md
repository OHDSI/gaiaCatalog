# AGENTS.md
## Purpose
This file provides instructions for agentic coding tools (e.g., opencode, Cursor AI, Copilot)
operating in the Gaia Catalog repository. It details commands for build/lint/test,
code style conventions (inferred from codebase since no explicit configs like ruff.toml,
.pre-commit-hooks, or ESLint exist), and best practices. Always follow these to maintain
consistency. No existing AGENTS.md, Cursor rules (.cursor/rules/, .cursorrules), or
Copilot instructions (.github/copilot-instructions.md) found.

## Environment Setup
- Python: 3.13+ (see `.python-version`)
- Deps: uv-based (`pyproject.toml`, `uv.lock`)
  - Install: `uv sync`
  - Add dep: `uv add <pkg>`
  - After dep changes: `uv sync && pytest`
- No virtualenv needed (uv handles)
- Data dirs: `stores/input/` (JSON-LD/PDF), `stores/lance/db/` (outputs), `datastore/` (raw/gitignored)
- ETL skills: `datastore/data/*/etl/skills.md` (dataset ETL pipelines: GDB→PostGIS). Use `workdir=etl_dir bash command=&quot;./script.sh&quot;`.

## Build/Deploy Commands
No Makefile/npm. Use CLI pipelines via `architecture/masterControl.py`.

### Core Pipelines
```
python architecture/masterControl.py jsonld2lance --json_dir ./stores/input/ --db_path ./stores/lance/db --table_name source
```
(Converts JSON-LD files to LanceDB table `source`)

```
python architecture/masterControl.py gliner2lance --db_path ./stores/lance/db --source_table source --output_table entities
```
(GLiNER NER → LanceDB `entities`)

```
python architecture/masterControl.py jsonld2ntfile --input_dir ./stores/input/ --output_file ./stores/sourceinput.nt
```
(JSON-LD → N-Triples RDF)

```
python architecture/masterControl.py lance_list --db_path ./stores/lance/db
```
(List LanceDB tables)

```
python architecture/masterControl.py lance_head --db_path ./stores/lance/db --table_name source --n 10
```
(View table head)

```
python architecture/masterControl.py pdf2markdown --source path/to.pdf --text-output output.md
```

```
python architecture/masterControl.py pdf2table --source path/to.pdf --tables-output tables.md
```

### RDF/Qlever (Graph Index/UI)
```
qlever -q architecture/7-Deployment/qlever/Qleverfile get-data
qlever -q architecture/7-Deployment/qlever/Qleverfile index --overwrite-existing
qlever -q architecture/7-Deployment/qlever/Qleverfile start
qlever -q architecture/7-Deployment/qlever/Qleverfile ui
```

### Docker Services
- Solr: `docker build -t solr-gaia docker/solr/ && docker run ...`
- Repo UI: `docker build -t repo-ui docker/repository/`
- ParadeDB/pgvector: `docker run --name paradedb-demo -e POSTGRES_PASSWORD=mysecretpassword -p 5432:5432 -d paradedb/paradedb:latest`
- Gradio UI: Docker in `architecture/6-UserInterfaces/gradio/Dockerfile`

### Lance-MCP (DSPy Subproject)
`cd architecture/7-Deployment/lance-mcp && uv sync`

## Data ETL Skills
See `datastore/data/&lt;dataset&gt;/etl/skills.md` for bash pipelines (e.g., ma_2018_svi_tract):
- Download FileGDB, ogr2ogr to PostGIS.
- Geom clean (ST_MakeValid), local EPSG/index.
- pg_dump + tar export w/ DCAT metadata.
- **Run:** `workdir=/path/to/etl bash command=&quot;./ma_2018_svi_tract_osgeo.sh&quot;`
- **Full:** Chain scripts sequentially.
Mimic for new datasets (no .py changes).

## Lint & Format Commands
**No explicit configs (no ruff.toml, black, isort, mypy).**
- Infer style from code (see Style Guide).
- Lint suggestion: Install ruff `uv add --dev ruff`, run `ruff check .`
- Format: `uv add --dev black ruff black .`
- Typecheck: `uv add --dev mypy mypy . --strict` (add gradually)

**Always run before commit:**
```
uv sync && ruff check . && pytest
```
(Adapt if no ruff; grep code for issues manually.)

## Test Commands
Pytest (dev deps in lance-mcp/pyproject.toml). No pytest.ini/conftest.py.

### All Tests
```
pytest
```
(Runs `architecture/7-Deployment/lance-mcp/tests/test_modules.py`)

```
python architecture/testing/pgvector/pgvector_test.py
```
(Pgvector HNSW demo)

### Single File
```
pytest architecture/7-Deployment/lance-mcp/tests/test_modules.py -v
```

### Single Test/Class/Function
```
pytest tests/test_modules.py::test_module_forward -v
```
```
pytest tests/test_modules.py::TestLanceMcp -v
```
```
pytest tests/test_modules.py::TestLanceMcp::test_forward -v
```

### With Coverage
```
pytest --cov=src/lance_mcp --cov-report=html
```

**After code changes: Always run `pytest -v` to verify.**

## Code Style Guidelines
**Inferred from top files: masterControl.py, defs/*.py (jsonldFile2Lance.py etc.),
lance_mcp_predict.py, baml_client/*.py, test_modules.py, pgvector_test.py.**
Mimic exactly. 4-space indents, <100 char lines, type hints everywhere.

### Imports
**Order (absolute, no relatives):**
1. Stdlib (`import os`, `import sys`, `import argparse`, `import logging`, `from typing import ...`)
2. Third-party (`import lancedb`, `from sentence_transformers import ...`, `import duckdb`, `import dspy`, `import psycopg2`)
3. Local (`from architecture.defs import jsonldFile2Lance`, `from lance_mcp.signatures.lance_mcp import ...`)

**Examples:**
```python
import argparse
import hashlib
import logging
import os
import warnings
from pathlib import Path
from typing import List, Optional

import duckdb
import lancedb
from sentence_transformers import SentenceTransformer
import dspy

from architecture.defs.jsonldFile2Lance import process_jsonld_to_lance
```

- Group `import` before `from ... import`
- `warnings.filterwarnings("ignore", ...)` for deps
- No unused imports (grep check)

### Formatting & Whitespace
- **Black-like**: single quotes `'str'`, trailing commas in args/lists.
- 4-space indents.
- Lines: <88 chars (PEP8-ish).
- Blank lines: 2 between top-level funcs/classes, 1 between methods.
- Docstrings: Google/numpy style for public funcs.
```python
def process_dir(json_dir: str) -> None:
    &quot;&quot;&quot;Process JSON-LD dir to LanceDB.&quot;&quot;&quot;
    ...
```

### Types & Annotations
- **Mandatory**: All funcs/args/returns (`def foo(bar: str) -> List[Dict[str, Any]]:`)
- Common: `List[str]`, `Optional[str]`, `Path`, `TypedDict`, Pydantic `BaseModel`
- Embeddings: `Vector(512)` (jinaai/jina-embeddings-v2-small-en)
- LanceDB: `LanceModel` schemas
```python
from lance.vector import Vector
from pydantic import BaseModel

class DocVector(LanceModel):
    text: str = lance_field()
    embeddings: Vector(512) = lance_field()
```

### Naming Conventions
| Element | Convention | Examples |
|---------|------------|----------|
| Functions/Vars/Args | snake_case | `json_dir`, `process_jsonld_to_lance()`, `full_text` |
| Classes | CamelCase | `LanceMcpPredict(dspy.Module)`, `DocVector` |
| Modules/Files | snake_case | `jsonldFile2Lance.py`, `lance_mcp_predict.py` |
| Tables/Cols | snake_case | `source`, `entities`, `embeddings` |
| CLI Args | kebab-case | `--json_dir`, `--db_path` |

### Error Handling
- `try/except Exception as e: logging.error(f&quot;Error: {e}&quot;)` (broad, log & continue)
- Fallbacks: bulk insert → row-by-row
- Checks: `if df.empty: return []`
- HTTP: `response.raise_for_status()`
```python
try:
    tbl = lancedb.connect(db_path).open_table(table_name)
except Exception as e:
    logging.error(f&quot;Failed to open {table_name}: {e}&quot;)
    return
```

### Folder Structure & Patterns
```
architecture/
├── defs/          # Utils: jsonld2lance.py, gliner2lance.py, lance_utils.py
├── 6-UserInterfaces/
│   ├── gradio/    # BAML client, UIs
│   └── chainlit/
├── 7-Deployment/
│   ├── lance-mcp/ # DSPy: src/lance_mcp/, tests/, signatures/*.baml
│   └── qlever/    # RDF index
└── testing/       # pgvector_test.py
```
- **New files**: Place in `architecture/defs/` or `src/` pkg.
- **BAML prompts**: `*.baml` in `baml_src/`
- **DSPy**: Inherit `dspy.Module`, use `dspy.ChainOfThought()`
- **LanceDB**: Use `LanceModel`, `add()` with `mode='append'`
- **Logging**: `logging.basicConfig(level=logging.INFO)`

### Security & Best Practices
- No secrets in code/repos (use .env)
- Validate inputs: `Path(json_dir).exists()`
- Idempotent: `--overwrite` flags
- Verify changes: `pytest && python architecture/masterControl.py lance_head ...`
- Git: No commits unless asked. Stage thoughtfully.
- No new deps without `uv add` + rationale.

## Agent Workflow
1. Read relevant files (e.g., `read architecture/masterControl.py`)
2. Mimic patterns (imports, LanceModel, error handling)
3. Edit/write following style
4. Test: `pytest -v`
5. Lint: `ruff check .` (if installed)
6. Pipeline verify: Run affected `masterControl.py` subcmd
7. Update this AGENTS.md if new conventions emerge.

**Line count: ~170** (expand as needed)