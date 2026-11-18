"""Tests for the draft recipe profile (schema/gaia_recipe_v0_1.yaml).

The example recipes in schema/recipes must validate, and each planted error must be caught.
The planted errors include the ones CDIF's own schema lets through (a misspelt gaia: key, a
bad value for a gaia: term).
"""
import copy
import json
from pathlib import Path

import pytest

jsonschema = pytest.importorskip('jsonschema')

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / 'schema/generated/gaia_recipe_v0_1.schema.json').read_text())
RECIPES = sorted((ROOT / 'schema/recipes').glob('*.jsonld'))
PM25 = 'us_2014_2019_monthly_pm25_by_county_cdc'
VALIDATOR = jsonschema.Draft202012Validator(SCHEMA)


def load(name):
    return json.loads((ROOT / f'schema/recipes/{name}.jsonld').read_text())


def errors(doc):
    return [e.message for e in VALIDATOR.iter_errors(doc)]


@pytest.mark.parametrize('path', RECIPES, ids=[p.stem for p in RECIPES])
def test_example_recipes_are_valid(path):
    assert errors(json.loads(path.read_text())) == []


def test_there_are_examples_of_each_representation():
    kinds = {json.loads(p.read_text())['gaia:representation'] for p in RECIPES}
    assert kinds == {'vector', 'raster', 'table'}


def drop(*keys):
    def f(doc):
        node = doc
        for k in keys[:-1]:
            node = node[k]
        del node[keys[-1]]
    return f


def put(keys, value):
    def f(doc):
        node = doc
        for k in keys[:-1]:
            node = node[k]
        node[keys[-1]] = value
    return f


def rename(old, new):
    def f(doc):
        doc[new] = doc.pop(old)
    return f


# (name, recipe, change, text that must appear in an error)
PLANTED = [
    ('misspelt gaia key', PM25, rename('gaia:joinsTo', 'gaia:joinTo'), 'gaia:joinTo'),
    ('misspelt key inside a gaia object', PM25,
     lambda d: d['gaia:joinsTo'].update({'gaia:joinkey': d['gaia:joinsTo'].pop('gaia:joinKey')}), 'gaia:joinkey'),
    ('retrieval method not in the list', PM25, put(['gaia:retrieval', 'gaia:method'], 'wget'), 'wget'),
    ('vector without a label column', 'mdc_hospitals', drop('gaia:labelColumn'), 'gaia:labelColumn'),
    ('vector without a geometry type', 'mdc_hospitals', drop('gaia:geometryType'), 'gaia:geometryType'),
    ('table without a join target', PM25, drop('gaia:joinsTo'), 'gaia:joinsTo'),
    ('raster without a CRS', 'synthetic_raster_annual', drop('geosparql:crs'), 'geosparql:crs'),
    ('raster without files', 'synthetic_raster_annual', drop('gaia:files'), 'gaia:files'),
    ('no validity', 'mdc_hospitals', drop('gaia:validity'), 'gaia:validity'),
    ('validity written as one string', 'synthetic_raster_annual', put(['gaia:validity'], '2014/2019'), '2014/2019'),
    ('validity with a start only', 'synthetic_raster_annual',
     put(['gaia:validity'], {'gaia:start': '2014'}), 'is not valid under any of the given schemas'),
    ('neither retrieval nor derivation', 'mdc_hospitals', drop('gaia:retrieval'), 'is not valid under any of the given schemas'),
    ('both retrieval and derivation', 'mdc_2021_nlcd_land_cover',
     put(['gaia:retrieval'], {'gaia:method': 'manual'}), 'is valid under each of'),
    ('download without a URL', 'synthetic_raster_annual', drop('gaia:retrieval', 'gaia:url'), 'is not valid under any of the given schemas'),
    ('credential that is a value, not a name', PM25, put(['gaia:retrieval', 'gaia:credential'], 'my token 123'), 'my token 123'),
    ('Postgres type with the xsd prefix', 'mdc_hospitals',
     lambda d: d['schema:variableMeasured'][0].update({'cdif:physicalDataType': 'xsd:int4'}), 'xsd:int4'),
    ('min value as a string', 'mdc_hospitals',
     lambda d: d['schema:variableMeasured'][0].update({'schema:minValue': '1'}), "'1'"),
    ('concept id as a bare integer', 'synthetic_raster_annual',
     lambda d: d['schema:variableMeasured'][0].update({'schema:propertyID': [2052499839]}), '2052499839'),
    ('malformed checksum', 'synthetic_raster_annual',
     lambda d: d['gaia:files'][0].update({'spdx:checksum': 'TBD'}), 'TBD'),
    ('no declared profile', 'mdc_hospitals', drop('schema:subjectOf'), 'schema:subjectOf'),
    ('unknown derivation method', 'mdc_2021_nlcd_land_cover', put(['gaia:derivation', 'gaia:method'], 'blur'), 'blur'),
    ('version that is not a date', 'synthetic_raster_annual', put(['schema:version'], '1'), "'1'"),
    ('CRS as a bare code', 'mdc_hospitals', put(['geosparql:crs'], {'@id': 'EPSG:4326'}), 'EPSG:4326'),
]


@pytest.mark.parametrize('name,recipe,change,expected', PLANTED, ids=[p[0] for p in PLANTED])
def test_planted_error_is_caught(name, recipe, change, expected):
    doc = copy.deepcopy(load(recipe))
    change(doc)
    found = errors(doc)
    assert found, f'{name}: nothing reported'
    assert any(expected in m for m in found), f'{name}: expected {expected!r} in {found}'


def test_generated_schema_is_current():
    pytest.importorskip('linkml')
    import importlib.util
    spec = importlib.util.spec_from_file_location('build_recipe_schema', ROOT / 'architecture/defs/build_recipe_schema.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert (ROOT / 'schema/generated/gaia_recipe_v0_1.schema.json').read_text() == module.build()
