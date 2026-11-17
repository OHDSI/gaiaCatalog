"""Tests for the checks in defs/validate_catalog.py that do not need linkml."""
import sys
from pathlib import Path
from typing import Any, Dict, List

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'defs'))

import validate_catalog as vc  # noqa: E402


def term(set_name: str, code: str) -> Dict[str, Any]:
    """A measurementTechnique term."""
    return {'termCode': code, 'inDefinedTermSet': {'name': set_name}}


def good_doc() -> Dict[str, Any]:
    """A minimal document that passes the semantic checks."""
    return {
        '@context': {'@vocab': 'https://schema.org/'},
        '@id': 'https://example.org/detail/thing',
        'type': 'Vector Dataset',
        'measurementTechnique': [
            term('dataRepresentation', 'vector'),
            term('vectorGeometry', 'point'),
        ],
        'additionalProperty': [
            {'propertyID': 'http://dbpedia.org/resource/Spatial_reference_system',
             'value': 'https://epsg.io/4269'},
        ],
        'variableMeasured': [{'name': 'a'}, {'name': 'b'}],
    }


def issues(doc: Dict[str, Any], etl: Dict[str, Any] = None) -> List[str]:
    """The issue labels from the semantic layer."""
    return [f.issue for f in vc.check_semantics(doc, 'thing', etl or {})]


def test_good_document_has_no_semantic_findings() -> None:
    assert issues(good_doc()) == []


def test_vector_needs_geometry_and_srs() -> None:
    doc = good_doc()
    doc['measurementTechnique'] = [term('dataRepresentation', 'vector')]
    doc['additionalProperty'] = []
    assert set(issues(doc)) == {'vector without geometry', 'no spatial reference'}


def test_raster_needs_neither() -> None:
    doc = good_doc()
    doc['type'] = 'Raster Dataset'
    doc['measurementTechnique'] = [term('dataRepresentation', 'raster')]
    doc['additionalProperty'] = []
    assert issues(doc) == []


def test_type_must_agree_with_structure() -> None:
    doc = good_doc()
    doc['type'] = 'Raster Dataset'
    assert issues(doc) == ['type disagrees with structure']


def test_stray_whitespace_and_duplicates() -> None:
    doc = good_doc()
    doc['variableMeasured'] = [{'name': '\ncounty'}, {'name': 'county'}]
    assert set(issues(doc)) == {'name has stray whitespace', 'duplicate variable'}


def test_year_in_unit_or_min_column_is_flagged() -> None:
    doc = good_doc()
    doc['variableMeasured'] = [
        {'name': 'a', 'unitCode': '2016', 'minValue': '2020'},
        {'name': 'b', 'minValue': '2082', 'maxValue': '2339622'},   # a real minimum
    ]
    found = [f.path for f in vc.check_semantics(doc, 'thing', {})]
    assert found == ['variableMeasured[].unitCode', 'variableMeasured[].minValue']


def test_dates_reversed_and_min_above_max() -> None:
    doc = good_doc()
    doc['variableMeasured'] = [
        {'name': 'a', 'startDate': '2020-12-31', 'endDate': '2020-01-01'},
        {'name': 'b', 'minValue': '5', 'maxValue': '1'},
    ]
    assert set(issues(doc)) == {'dates reversed', 'min above max'}


def test_id_must_end_with_folder() -> None:
    doc = good_doc()
    doc['@id'] = 'https://example.org/detail/other'
    assert issues(doc) == ['id does not match folder']


def test_variables_compared_with_meta_etl() -> None:
    etl = {'attributes': ['a;desc;x;int4', 'c;desc;x;int4']}
    assert issues(good_doc(), etl) == ['variables differ from meta_etl']


def test_generalize_and_split_path() -> None:
    assert vc.split_path("'x' is a required property in /variableMeasured/3") == (
        '/variableMeasured/3', "'x' is a required property")
    assert vc.generalize('/variableMeasured/3', "'qudt:dataType' is a required property") == (
        'variableMeasured[].qudt:dataType')
    assert vc.generalize('/', "'license' is a required property") == 'license'


def test_render_markdown_orders_errors_first() -> None:
    report = {
        'generated_at': 'now', 'schema': 's.yaml',
        'sources': [
            {'source': 'ok', 'status': 'PASS', 'errors': 0, 'warnings': 0, 'findings': []},
            {'source': 'bad', 'status': 'FAIL', 'errors': 1, 'warnings': 1, 'findings': [
                {'severity': 'ERROR', 'layer': 'schema', 'path': 'license',
                 'issue': 'missing required slot', 'message': 'x'},
                {'severity': 'WARNING', 'layer': 'recommended', 'path': 'type',
                 'issue': 'recommended slot missing', 'message': 'y'}]},
        ],
    }
    text = vc.render_markdown(report)
    assert '1 pass' in text and '1 with errors' in text
    assert text.index('| ERROR |') < text.index('| WARNING |')
    assert text.index('| bad |') < text.index('| ok |')
