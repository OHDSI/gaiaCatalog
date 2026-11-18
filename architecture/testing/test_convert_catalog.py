"""Tests for defs/convert_catalog.py."""
import copy
import json
import sys
from pathlib import Path
from typing import Any, Dict

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'defs'))

import convert_catalog as cc  # noqa: E402

DATA = Path(__file__).resolve().parents[2] / 'datastore' / 'data'


def sample() -> Dict[str, Any]:
    """A small flat document that uses every mapping."""
    return {
        '@context': cc.V1_CONTEXT,
        '@type': 'Dataset',
        '@id': 'https://gdsc.idsc.miami.edu/detail/thing',
        'name': 'Thing',
        'description': 'A thing.',
        'version': '2026-10-09',
        'url': 'https://example.org/thing',
        '@language': 'en',
        'type': 'Vector Dataset',
        'creator': [{'@type': 'Organization', 'name': 'CDC', 'identifier': 'https://ror.org/x'}],
        'provider': [{'@type': 'Organization', 'name': 'CDC'}],
        'spatialCoverage': [
            {'@id': 'https://www.geonames.org/6254926', '@type': 'Place', 'name': 'Massachusetts'},
            {'@type': 'Place', 'name': 'bbox', 'geo': {
                '@type': 'GeoShape',
                'polygon': '41.2 -73.5 41.2 -69.9 42.8 -69.9 42.8 -73.5 41.2 -73.5'}},
        ],
        'keywords': ['a', 'b'],
        'datePublished': '2020-10-22',
        'dateModified': '2026-07-17 10:55:47',
        'measurementTechnique': [
            {'@type': 'DefinedTerm', 'termCode': 'vector',
             'inDefinedTermSet': {'@type': 'DefinedTermSet', 'name': 'dataRepresentation'}},
            {'@type': 'DefinedTerm', 'termCode': 'multipolygon',
             'inDefinedTermSet': {'@type': 'DefinedTermSet', 'name': 'vectorGeometry'}},
        ],
        'additionalProperty': [
            {'@type': 'PropertyValue', 'propertyID': cc.SRS_PROPERTY_ID,
             'value': 'https://epsg.io/4269'},
            {'@type': 'PropertyValue', 'name': 'temporalDimension', 'value': 'static'},
        ],
        'about': [{'@type': 'Event', 'name': 'ETL process'}],
        'distribution': ['/data/thing/'],
        'variableMeasured': [
            {'@type': 'PropertyValue', 'name': 'e_afam', 'description': 'Persons',
             'propertyID': '2052499783', 'qudt:dataType': 'int4', 'unitText': 'persons',
             'minValue': '0', 'maxValue': '5439',
             'startDate': '2020-01-01', 'endDate': '2020-12-31'},
            {'@type': 'PropertyValue', 'name': 'old', 'qudt:dataType': 'int4',
             'startDate': '1/1/18', 'endDate': '12/31/18'},
        ],
    }


def test_v2_shape() -> None:
    v2 = cc.flat_to_v2(sample())
    node = v2['@graph'][0]
    assert node['@type'] == 'schema:Dataset' and v2['@context']['@language'] == 'en'
    assert node['creator'][0]['roleName'] == 'creator'
    assert node['creator'][0]['creator']['name'] == 'CDC'
    place = node['spatialCoverage'][0]
    props = {p['name']: p for p in place['additionalProperty']}
    assert props['geonames']['value'] == '6254926'
    assert props['Spatial Reference System']['value'].endswith('/EPSG/0/4269')
    assert props['extent']['value'] == 'ENVELOPE(-73.5,-69.9,42.8,41.2)'
    assert '"geo"' not in json.dumps(node['spatialCoverage'])
    assert node['distribution'] == [
        {'@type': 'DataDownload', 'name': 'Source distribution', 'contentUrl': '/data/thing/'}]
    assert node['additionalType'] == 'Vector Dataset' and node['inLanguage'] == 'en'
    assert [p['name'] for p in node['additionalProperty']] == ['temporalDimension']


def test_variables_in_v2() -> None:
    first, second = cc.flat_to_v2(sample())['@graph'][0]['variableMeasured']
    assert first['qudt:dataType'] == 'xsd:int4' and first['alternateName'] == '2052499783'
    assert first['additionalProperty'] == [
        {'@type': 'PropertyValue', 'name': 'temporal_interval',
         'value': '2020-01-01/2020-12-31'}]
    assert first['minValue'] == '0' and first['maxValue'] == '5439'
    # a date that is not ISO is kept as written, not glued into an interval
    assert [p['name'] for p in second['additionalProperty']] == ['startDate', 'endDate']


def test_round_trip_is_lossless() -> None:
    assert cc.round_trip_diff(sample()) == []
    back = cc.v2_to_flat(cc.flat_to_v2(sample()))
    assert back['spatialCoverage'][-1]['geo']['polygon'] == (
        '41.2 -73.5 41.2 -69.9 42.8 -69.9 42.8 -73.5 41.2 -73.5')
    assert back['variableMeasured'][1]['startDate'] == '1/1/18'


def test_non_rectangular_polygon_is_kept() -> None:
    flat = sample()
    flat['spatialCoverage'][1]['geo']['polygon'] = 'TBD'
    assert cc.round_trip_diff(flat) == []


def test_unknown_keys_are_refused() -> None:
    flat = sample()
    flat['surprise'] = 1
    with pytest.raises(cc.ConversionError):
        cc.flat_to_v2(flat)


def test_v2_only_values_are_dropped_and_version_is_derived() -> None:
    v2 = cc.flat_to_v2(sample())
    node = v2['@graph'][0]
    node.update({'funder': [{'@type': 'Organization', 'name': 'IDSC'}], 'usageInfo': 'text'})
    node['additionalProperty'].append({'@type': 'PropertyValue', 'name': 'kobo_record_id', 'value': '1'})
    del node['version']
    flat = cc.v2_to_flat(v2)
    assert 'funder' not in flat and 'usageInfo' not in flat
    assert [p.get('name') or p['propertyID'] for p in flat['additionalProperty']] == [
        cc.SRS_PROPERTY_ID, 'temporalDimension']
    assert flat['version'] == '2026-07-17'


def test_v2_accepts_the_single_object_forms_of_4589614() -> None:
    node = cc.flat_to_v2(sample())['@graph'][0]
    node['provider'] = node['provider'][0]
    node['spatialCoverage'] = node['spatialCoverage'][0]
    flat = cc.v2_to_flat({'@context': {}, '@graph': [node]})
    assert flat['provider'] == [{'@type': 'Organization', 'name': 'CDC'}]
    assert flat['spatialCoverage'][0]['name'] == 'Massachusetts'


def test_etl_enrichment() -> None:
    etl = {'update_frequency': 'Never', 'table': 'thing', 'download': 'wget', 'custom_etl': ''}
    node = cc.flat_to_v2(sample(), etl)['@graph'][0]
    assert node['dct:accrualPeriodicity'] == 'Never'
    assert [p['name'] for p in node['additionalProperty']] == [
        'postgis_table', 'download_method', 'temporalDimension']
    assert cc.round_trip_diff(sample()) == []


@pytest.mark.skipif(not DATA.is_dir(), reason='datastore not present')
def test_every_catalog_entry_round_trips() -> None:
    bad = []
    for path in sorted(DATA.glob('*/meta_json-ld_*.json')):
        flat = json.loads(path.read_text(encoding='utf-8'))
        if cc.round_trip_diff(copy.deepcopy(flat)):
            bad.append(path.parent.name)
    assert bad == []
