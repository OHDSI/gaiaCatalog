"""Tests for the pure (non-Docker) parts of defs/validate_ingest.py."""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'defs'))

import validate_ingest as vi  # noqa: E402


def make_source(root: Path, name: str, deps=None, script: str = '') -> None:
    """Create a minimal catalog entry under root."""
    (root / name / 'etl').mkdir(parents=True)
    etl = {'table': name, 'dependency': deps or []}
    (root / name / f'meta_etl_{name}.json').write_text(json.dumps(etl))
    (root / name / 'etl' / f'{name}_osgeo.sh').write_text(script)


def test_judge_steps_pass() -> None:
    steps = [('metadata_load', 'success', 'ok'), ('complete', 'success', 'done')]
    assert vi.judge_steps(steps) == (vi.PASS, '', 'done')


def test_judge_steps_error_reports_first_error() -> None:
    steps = [('ingestion', 'error', 'boom'), ('postgis', 'skipped', 'skip')]
    assert vi.judge_steps(steps) == (vi.FAIL, 'ingestion', 'boom')


def test_judge_steps_incomplete() -> None:
    status, step, _ = vi.judge_steps([('postgis', 'in_progress', 'running')])
    assert (status, step) == (vi.FAIL, 'postgis')


def test_dependency_closure_and_missing(tmp_path: Path) -> None:
    make_source(tmp_path, 'a', deps=['b', 'ghost'])
    make_source(tmp_path, 'b', deps=['a'])
    ids, missing = vi.dependency_closure(tmp_path, 'a')
    assert sorted(ids) == ['a', 'b']
    assert missing == ['ghost']


def test_find_credentials_ignores_boilerplate_export(tmp_path: Path) -> None:
    boiler = 'export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)\n'
    make_source(tmp_path, 'plain', script=boiler)
    make_source(tmp_path, 'keyed', script=boiler + 'wget "x?key=$CENSUS_API_KEY"\n')
    assert vi.find_credentials(tmp_path, ['plain']) == []
    assert vi.find_credentials(tmp_path, ['keyed']) == ['CENSUS_API_KEY']


def test_deferral_reason_covers_dependencies(tmp_path: Path) -> None:
    make_source(tmp_path, 'child', deps=['parent'])
    make_source(tmp_path, 'parent')
    reason = vi.deferral_reason(tmp_path, ['child', 'parent'], {'parent': 'closed'})
    assert 'parent: closed' in reason
    assert vi.deferral_reason(tmp_path, ['child'], {}) == ''


def test_stage_sources_drops_downloads_and_datestamp(tmp_path: Path) -> None:
    make_source(tmp_path / 'src', 'a')
    (tmp_path / 'src' / 'a' / 'download').mkdir()
    (tmp_path / 'src' / 'a' / 'download' / 'big.gdb').write_text('x')
    (tmp_path / 'src' / 'a' / 'datestamp').write_text('2026-01-01')
    dest = tmp_path / 'dest'
    dest.mkdir()
    vi.stage_sources(tmp_path / 'src', ['a'], dest)
    assert (dest / 'a' / 'meta_etl_a.json').exists()
    assert not (dest / 'a' / 'download').exists()
    assert not (dest / 'a' / 'datestamp').exists()


def test_render_and_update_readme(tmp_path: Path) -> None:
    report = {
        'generated_at': '2026-11-17 12:00 UTC',
        'image': 'ohdsi/gaia-db:main',
        'image_id': 'sha256:abc',
        'results': [
            {'source': 'good', 'structure': 'vector', 'status': vi.PASS,
             'failed_step': '', 'message': 'fine', 'warnings': []},
            {'source': 'bad', 'structure': 'raster', 'status': vi.FAIL,
             'failed_step': 'ingestion', 'message': 'a | b\nc', 'warnings': []},
            {'source': 'later', 'structure': 'vector', 'status': vi.SKIPPED,
             'failed_step': 'deferred', 'message': 'needs key', 'warnings': []},
        ],
    }
    readme = tmp_path / 'README.md'
    readme.write_text(f'intro\n{vi.README_START}\nold\n{vi.README_END}\noutro\n')
    vi.update_readme(report, readme)
    text = readme.read_text()
    assert text.startswith('intro\n') and text.endswith(f'{vi.README_END}\noutro\n')
    assert '1 of 2 sources ingest' in text
    assert 'deferred, needs credentials or local data: 1' in text
    assert text.index('| bad ') < text.index('| good ')
    assert 'a / b c' in text and 'old' not in text


def test_update_readme_requires_markers(tmp_path: Path) -> None:
    readme = tmp_path / 'README.md'
    readme.write_text('no markers')
    with pytest.raises(ValueError):
        vi.update_readme({'results': []}, readme)


def test_local_data_sources_need_download_dir(tmp_path: Path) -> None:
    make_source(tmp_path, 'manual')
    etl = tmp_path / 'manual' / 'meta_etl_manual.json'
    etl.write_text(json.dumps({'download': 'local'}))
    assert vi.local_data_ids(tmp_path, ['manual']) == ['manual']
    assert 'supplied manually' in vi.deferral_reason(tmp_path, ['manual'], {})
    (tmp_path / 'manual' / 'download').mkdir()
    (tmp_path / 'manual' / 'download' / 'data.nc').write_text('x')
    assert vi.deferral_reason(tmp_path, ['manual'], {}) == ''
    dest = tmp_path / 'dest'
    dest.mkdir()
    vi.stage_sources(tmp_path, ['manual'], dest, ['manual'])
    assert (dest / 'manual' / 'download' / 'data.nc').exists()


def test_merge_reports_later_file_wins(tmp_path: Path) -> None:
    first, second = tmp_path / 'a.json', tmp_path / 'b.json'
    first.write_text(json.dumps({'results': [{'source': 's', 'status': 'FAIL'}]}))
    second.write_text(json.dumps({'results': [{'source': 's', 'status': 'PASS'}]}))
    merged = vi.merge_reports([first, second])
    assert [r['status'] for r in merged['results']] == ['PASS']
