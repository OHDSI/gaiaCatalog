"""Check that every catalog source ingests into gaiaDB.

For each source in datastore/data, a fresh ohdsi/gaia-db container is started
with a clean copy of the source (and the sources it depends on) mounted at
/data. backbone.ingest_datasource(table_id) is then run inside the container
and the (step, status, message) rows it returns are turned into a verdict.
Results are written as JSON and can be rendered as a table in the README.
"""
import argparse
import json
import logging
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_IMAGE = 'ohdsi/gaia-db:main'
PG_USER = 'postgres'
PG_DB = 'gaiacore'
PG_PASSWORD = 'secret'
FIELD_SEP = '\x1f'
RECORD_SEP = '\x1e'
IDENT_RE = re.compile(r'^[a-z0-9_]+$')
STAGE_IGNORE = ('download', 'derived', 'derivative', 'datestamp')
CREDENTIAL_VARS = (
    'CDC_APP_TOKEN',
    'AIRNOW_API_KEY',
    'USGS_USER',
    'USGS_PASSWORD',
    'CENSUS_API_KEY',
)
SKIP_FILE = Path(__file__).with_name('ingest_skip.json')
README_START = '<!-- ingest-report:start -->'
README_END = '<!-- ingest-report:end -->'

PASS = 'PASS'
FAIL = 'FAIL'
TIMEOUT = 'TIMEOUT'
SKIPPED = 'SKIPPED'


@dataclass
class SourceResult:
    """Outcome of one ingest attempt."""

    source: str
    structure: str = ''
    status: str = FAIL
    failed_step: str = ''
    message: str = ''
    warnings: List[str] = field(default_factory=list)
    duration_s: float = 0.0
    rows: Optional[int] = None


def list_sources(data_dir: Path) -> Tuple[List[str], List[str]]:
    """Split catalog directories into ingestible sources and the rest.

    Args:
        data_dir: The datastore/data directory.

    Returns:
        Tuple of (sources with a meta_etl file, directories without one).
    """
    sources: List[str] = []
    unregistered: List[str] = []
    for path in sorted(p for p in data_dir.iterdir() if p.is_dir()):
        if (path / f'meta_etl_{path.name}.json').exists():
            sources.append(path.name)
        else:
            unregistered.append(path.name)
    return sources, unregistered


def load_skip_list(path: Path = SKIP_FILE) -> Dict[str, str]:
    """Load the {source: reason} map of sources deferred for known reasons."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as e:
        logging.warning(f'No skip list loaded from {path}: {e}')
        return {}


def find_credentials(data_dir: Path, ids: List[str]) -> List[str]:
    """Find credential variables that the ETL scripts really use.

    Every generated script exports all credential variables from secret files
    as boilerplate, so only uses outside those export lines count.
    """
    found = set()
    for source in ids:
        for script in sorted((data_dir / source / 'etl').glob('*.sh')):
            for line in script.read_text(errors='replace').splitlines():
                for var in CREDENTIAL_VARS:
                    if line.startswith(f'export {var}='):
                        continue
                    if re.search(rf'\$\{{?{var}(?![A-Za-z0-9_])', line):
                        found.add(var)
    return sorted(found)


def local_data_ids(data_dir: Path, ids: List[str]) -> List[str]:
    """Find sources whose data is supplied by hand rather than downloaded.

    Their ETL scripts contain no download step (meta_etl download is 'local',
    or the data comes from external code such as 'github_code'), so a clean
    checkout cannot ingest them.
    """
    found = []
    for source in ids:
        etl = read_etl(data_dir, source)
        if etl.get('download') == 'local' or etl.get('custom_etl') == 'github_code':
            found.append(source)
    return found


def has_local_download(data_dir: Path, source: str) -> bool:
    """True if the source has a non-empty download directory on this machine."""
    path = data_dir / source / 'download'
    return path.is_dir() and any(path.iterdir())


def deferral_reason(
    data_dir: Path, ids: List[str], skip: Dict[str, str]
) -> str:
    """Explain why a source (with its dependencies) is not tested, or ''."""
    reasons = []
    for source in ids:
        if source in skip:
            reasons.append(f'{source}: {skip[source]}')
    for source in local_data_ids(data_dir, ids):
        if not has_local_download(data_dir, source):
            reasons.append(f'{source}: data is supplied manually (no download step) '
                           f'and {source}/download is not present')
    creds = find_credentials(data_dir, ids)
    if creds:
        reasons.append(f'ETL scripts use credentials ({", ".join(creds)})')
    return '; '.join(reasons)


def read_etl(data_dir: Path, source: str) -> Dict[str, Any]:
    """Read meta_etl_<source>.json, returning {} if absent or unparsable."""
    try:
        text = (data_dir / source / f'meta_etl_{source}.json').read_text()
        return json.loads(text)
    except (OSError, ValueError) as e:
        logging.error(f'Cannot read meta_etl for {source}: {e}')
        return {}


def dependency_closure(
    data_dir: Path, source: str
) -> Tuple[List[str], List[str]]:
    """Find a source plus everything it depends on, transitively.

    Returns:
        Tuple of (ids to stage, dependency ids that have no directory).
    """
    needed: List[str] = []
    missing: List[str] = []
    todo = [source]
    while todo:
        current = todo.pop()
        if current in needed or current in missing:
            continue
        if not (data_dir / current).is_dir():
            missing.append(current)
            continue
        needed.append(current)
        deps = read_etl(data_dir, current).get('dependency') or []
        todo.extend(d for d in deps if isinstance(d, str))
    return needed, missing


def stage_sources(
    data_dir: Path, ids: List[str], dest: Path, keep_download: Optional[List[str]] = None
) -> None:
    """Copy source directories without downloads or datestamps.

    Sources listed in keep_download (data supplied manually) keep their
    download directory, since nothing would fetch it otherwise.

    A leftover datestamp makes the ETL scripts skip their download, so the
    copy must not carry one if the download is to be tested.
    """
    drop = shutil.ignore_patterns(*STAGE_IGNORE)
    drop_keep = shutil.ignore_patterns(*(p for p in STAGE_IGNORE if p != 'download'))
    for source in ids:
        ignore = drop_keep if source in (keep_download or []) else drop
        shutil.copytree(data_dir / source, dest / source, ignore=ignore)
    # the container user (uid 70) must be able to write into the mount
    subprocess.run(['chmod', '-R', 'a+rwX', str(dest)], check=False)


def _docker(
    args: List[str], timeout: Optional[float] = None
) -> subprocess.CompletedProcess:
    """Run a docker CLI command and capture its output."""
    return subprocess.run(
        ['docker', *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def start_container(
    name: str,
    image: str,
    data_path: Path,
    secret_path: Path,
    platform: Optional[str] = None,
) -> None:
    """Start a gaiaDB container whose /data is the staged directory."""
    cmd = ['run', '-d', '--name', name, '--hostname', 'gaia-db']
    if platform:
        cmd += ['--platform', platform]
    env = {
        'POSTGRES_PASSWORD': PG_PASSWORD,
        'DB_AUTHENTICATOR_PASSWORD': PG_PASSWORD,
        'POSTGRES_USER': PG_USER,
        'POSTGRES_DB': PG_DB,
        'POSTGRES_PORT': '5432',
        'INIT_WITH_DATASOURCE_MOUNT': 'TRUE',
        'PG_PASSWORD_FILE': '/run/pgpw',
    }
    for key, value in env.items():
        cmd += ['-e', f'{key}={value}']
    cmd += ['-v', f'{data_path}:/data', '-v', f'{secret_path}:/run/pgpw:ro']
    proc = _docker([*cmd, image])
    if proc.returncode != 0:
        raise RuntimeError(f'docker run failed: {proc.stderr.strip()}')


def psql(
    name: str, sql: str, timeout: Optional[float] = None
) -> subprocess.CompletedProcess:
    """Run one SQL statement in the container and return the process."""
    return _docker(
        [
            'exec', name, 'psql', '-U', PG_USER, '-d', PG_DB, '-h', 'localhost',
            '-X', '-A', '-t', '-F', FIELD_SEP, '-R', RECORD_SEP, '-c', sql,
        ],
        timeout=timeout,
    )


def psql_rows(name: str, sql: str, timeout: Optional[float] = None) -> List[List[str]]:
    """Run SQL and parse the result into rows of fields."""
    proc = psql(name, sql, timeout)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or 'psql failed')
    records = [r.strip('\n') for r in proc.stdout.split(RECORD_SEP)]
    return [r.split(FIELD_SEP) for r in records if r.strip()]


def wait_ready(name: str, timeout: float) -> None:
    """Wait until the server is up and the gaiaDB functions are loaded."""
    probe = (
        "select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace "
        "where n.nspname = 'backbone' and p.proname = 'ingest_datasource'"
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            proc = psql(name, probe, timeout=30)
            if proc.returncode == 0 and proc.stdout.strip() not in ('', '0'):
                return
        except subprocess.TimeoutExpired:
            pass
        time.sleep(3)
    raise RuntimeError(f'gaiaDB not ready after {timeout:.0f}s')


def judge_steps(steps: List[Tuple[str, str, str]]) -> Tuple[str, str, str]:
    """Turn ingest_datasource rows into (status, failed_step, message)."""
    for step, status, message in steps:
        if status == 'error':
            return FAIL, step, message
    if steps and steps[-1][0] == 'complete' and steps[-1][1] == 'success':
        return PASS, '', steps[-1][2]
    last = steps[-1] if steps else ('', '', 'ingest_datasource returned no rows')
    return FAIL, last[0] or 'incomplete', last[2] or 'did not reach complete'


def diagnose_script(
    name: str, steps: List[Tuple[str, str, str]], timeout: float
) -> str:
    """Re-run the ETL script that failed to recover its own output.

    gaiaDB's plsh wrapper only reports "script exited with status N", so the
    script is run again directly and the tail of its output is returned.
    """
    scripts = [m.split('Running: ', 1)[1] for _, s, m in steps
               if s == 'in_progress' and 'Running: ' in m]
    if not scripts:
        return ''
    try:
        proc = _docker(
            [
                'exec', '-u', 'postgres', '-e', f'POSTGRES_USER={PG_USER}',
                '-e', f'POSTGRES_DB={PG_DB}', '-e', 'POSTGRES_PORT=5432',
                '-e', 'PG_PASSWORD_FILE=/run/pgpw', name, '/bin/sh', scripts[-1],
            ],
            timeout=min(timeout, 900),
        )
    except subprocess.TimeoutExpired:
        return ''
    lines = [ln.strip() for ln in (proc.stdout + proc.stderr).splitlines()]
    detail = ' / '.join([ln for ln in lines if ln][-3:])
    # An ETL step can "succeed" after downloading an error page instead of
    # data (e.g. an API now requiring a token); show small downloads.
    source_id = scripts[-1].split('/')[2] if scripts[-1].count('/') > 2 else ''
    if IDENT_RE.match(source_id):
        peek = _docker(
            [
                'exec', name, 'sh', '-c',
                f'for f in /data/{source_id}/download/*; do [ -f "$f" ] && '
                f'[ "$(wc -c < "$f")" -lt 2048 ] && head -c 200 "$f"; done',
            ],
            timeout=60,
        )
        small = ' '.join(peek.stdout.split())
        if small:
            detail = f'{detail}; small download: {small}'
    return detail


def check_result(
    name: str, table: str, etl: Dict[str, Any]
) -> Tuple[Optional[int], str, List[str]]:
    """Assert the ingested table exists and has rows, and collect warnings.

    Returns:
        Tuple of (row count, hard failure message or '', warnings).
    """
    warnings: List[str] = []
    if not IDENT_RE.match(table):
        return None, f'table name {table!r} is not a plain identifier', warnings
    exists = psql_rows(name, f"select to_regclass('public.{table}') is not null", 60)
    if not exists or exists[0][0] != 't':
        return None, f'public.{table} does not exist after ingest', warnings
    rows = int(psql_rows(name, f'select count(*) from public.{table}', 600)[0][0])
    if rows == 0:
        return rows, f'public.{table} has no rows', warnings

    cols_sql = (
        'select column_name from information_schema.columns '
        f"where table_schema = 'public' and table_name = '{table}'"
    )
    columns = {r[0].lower() for r in psql_rows(name, cols_sql, 60)}
    structure = etl.get('structure')
    if structure == 'raster':
        if 'rast' not in columns:
            warnings.append('no rast column')
        return rows, '', warnings
    absent = [f for f in etl.get('fields') or [] if f.lower() not in columns]
    if absent:
        warnings.append(f'fields not in table: {", ".join(absent[:5])}')
    if etl.get('geometry') and 'geom' in columns:
        sql = (
            "select type, srid from geometry_columns where f_table_name = "
            f"'{table}' and f_geometry_column = 'geom'"
        )
        found = psql_rows(name, sql, 60)
        want_srid = str(etl.get('epsg', '')).split(':')[-1]
        if found and not found[0][0].lower().startswith(etl['geometry']):
            warnings.append(f'geometry {found[0][0]} != {etl["geometry"]}')
        if found and want_srid.isdigit() and found[0][1] != want_srid:
            warnings.append(f'srid {found[0][1]} != {want_srid}')
    return rows, '', warnings


def validate_source(
    data_dir: Path,
    source: str,
    image: str,
    timeout: float,
    ready_timeout: float,
    platform: Optional[str] = None,
    work_dir: Optional[Path] = None,
    skip: Optional[Dict[str, str]] = None,
) -> SourceResult:
    """Ingest one source in a throwaway gaiaDB container and judge it."""
    etl = read_etl(data_dir, source)
    result = SourceResult(source=source, structure=str(etl.get('structure', '')))
    started = time.monotonic()
    ids, missing = dependency_closure(data_dir, source)
    if missing:
        result.failed_step = 'dependency'
        result.message = f'dependency directory missing: {", ".join(missing)}'
        return result

    reason = deferral_reason(data_dir, ids, skip) if skip is not None else ''
    if reason:
        result.status = SKIPPED
        result.failed_step = 'deferred'
        result.message = f'deferred, test later: {reason}'
        return result

    name = f'gaiachk-{source[:40]}-{uuid.uuid4().hex[:6]}'.replace('_', '-')
    tmp = Path(tempfile.mkdtemp(prefix='gaiachk-', dir=work_dir))
    try:
        stage = tmp / 'data'
        stage.mkdir()
        stage_sources(data_dir, ids, stage, local_data_ids(data_dir, ids))
        secret = tmp / 'pgpw'
        secret.write_text(PG_PASSWORD)
        secret.chmod(0o644)

        start_container(name, image, stage, secret, platform)
        wait_ready(name, ready_timeout)
        try:
            rows = psql_rows(
                name,
                f"select step, status, message from backbone.ingest_datasource('{source}')",
                timeout,
            )
        except subprocess.TimeoutExpired:
            result.status = TIMEOUT
            result.failed_step = 'ingest'
            result.message = f'no result after {timeout:.0f}s'
            return result
        steps = [(r[0], r[1], r[2] if len(r) > 2 else '') for r in rows]
        result.status, result.failed_step, result.message = judge_steps(steps)
        if result.status == FAIL and result.failed_step in ('ingestion', 'postgis'):
            detail = diagnose_script(name, steps, timeout)
            if detail:
                result.message = f'{result.message}; script output: {detail}'
        if result.status == PASS:
            table = str(etl.get('table') or source)
            count, problem, warns = check_result(name, table, etl)
            result.rows, result.warnings = count, warns
            if problem:
                result.status = FAIL
                result.failed_step = 'assert'
                result.message = problem
    except Exception as e:
        result.status = FAIL
        result.failed_step = result.failed_step or 'harness'
        result.message = str(e)
    finally:
        _docker(['rm', '-f', '-v', name])
        shutil.rmtree(tmp, ignore_errors=True)
        result.duration_s = round(time.monotonic() - started, 1)
    return result


def run_validation(
    data_dir: Path,
    results_file: Path,
    image: str = DEFAULT_IMAGE,
    only: Optional[List[str]] = None,
    exclude: Optional[List[str]] = None,
    jobs: int = 2,
    timeout: float = 1800,
    ready_timeout: float = 300,
    platform: Optional[str] = None,
    work_dir: Optional[Path] = None,
    include_deferred: bool = False,
) -> Dict[str, Any]:
    """Validate sources in parallel and write the results JSON.

    Returns:
        The report dictionary that was written to results_file.
    """
    sources, unregistered = list_sources(data_dir)
    if only:
        sources = [s for s in sources if s in only]
        unregistered = []
    sources = [s for s in sources if s not in (exclude or [])]
    skip = None if include_deferred else load_skip_list()
    logging.info(f'Validating {len(sources)} source(s) with {image}')

    def work(source: str) -> SourceResult:
        res = validate_source(
            data_dir, source, image, timeout, ready_timeout, platform, work_dir, skip
        )
        logging.info(f'{res.status:8} {source} {res.failed_step} {res.message[:80]}')
        return res

    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        results = list(pool.map(work, sources))
    for name in unregistered:
        results.append(
            SourceResult(
                source=name,
                status=SKIPPED,
                failed_step='metadata',
                message=f'no meta_etl_{name}.json; not an ingestible source',
            )
        )

    inspect = _docker(['image', 'inspect', '--format', '{{.Id}}', image])
    report = {
        'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        'image': image,
        'image_id': inspect.stdout.strip() if inspect.returncode == 0 else '',
        'results': [asdict(r) for r in results],
    }
    results_file.write_text(json.dumps(report, indent=2) + '\n')
    return report


def merge_reports(paths: List[Path]) -> Dict[str, Any]:
    """Combine several results files (e.g. CI shards) into one report."""
    merged: Dict[str, Any] = {}
    by_source: Dict[str, Any] = {}
    for path in paths:
        part = json.loads(path.read_text())
        for res in part.get('results', []):
            by_source[res['source']] = res  # later files override earlier ones
        for key in ('generated_at', 'image', 'image_id'):
            merged[key] = part.get(key, '')
    merged['results'] = [by_source[k] for k in sorted(by_source)]
    return merged


def _cell(text: str, limit: int = 200) -> str:
    """Make text safe for a markdown table cell."""
    text = ' '.join(text.split()).replace('|', '/')
    return text if len(text) <= limit else text[: limit - 3] + '...'


def render_table(report: Dict[str, Any]) -> str:
    """Render the report as a markdown summary plus table."""
    results = report.get('results', [])
    counts = {s: sum(1 for r in results if r['status'] == s)
              for s in (PASS, FAIL, TIMEOUT, SKIPPED)}
    deferred = sum(1 for r in results if r['failed_step'] == 'deferred')
    other_skipped = counts[SKIPPED] - deferred
    attempted = len(results) - counts[SKIPPED]
    image_id = str(report.get('image_id', ''))[:19]
    lines = [
        f'{counts[PASS]} of {attempted} sources ingest into gaiaDB '
        f'(fail: {counts[FAIL]}, timeout: {counts[TIMEOUT]}, '
        f'deferred, needs credentials or local data: {deferred}, '
        f'not ingestible: {other_skipped}).',
        '',
        f'Last run: {report.get("generated_at", "")} using '
        f'`{report.get("image", "")}` {image_id}',
        '',
        '| Source | Structure | Status | Failed step | Message | Warnings |',
        '|--------|-----------|--------|-------------|---------|----------|',
    ]
    order = {FAIL: 0, TIMEOUT: 1, SKIPPED: 2, PASS: 3}
    for r in sorted(results, key=lambda r: (order.get(r['status'], 9), r['source'])):
        message = '' if r['status'] == PASS else _cell(r['message'])
        lines.append(
            f'| {r["source"]} | {r["structure"]} | {r["status"]} | '
            f'{r["failed_step"]} | {message} | {_cell("; ".join(r["warnings"]), 60)} |'
        )
    return '\n'.join(lines)


def update_readme(report: Dict[str, Any], readme: Path) -> None:
    """Replace the region between the ingest-report markers in the README."""
    text = readme.read_text()
    start, end = text.find(README_START), text.find(README_END)
    if start == -1 or end == -1 or end < start:
        raise ValueError(f'{readme} has no {README_START} ... {README_END} markers')
    block = f'{README_START}\n{render_table(report)}\n'
    readme.write_text(text[:start] + block + text[end:])


def add_subcommands(subparsers: Any) -> None:
    """Register the validate_ingest and ingest_report sub-commands."""
    vi = subparsers.add_parser(
        'validate_ingest', help='Test that catalog sources ingest into gaiaDB'
    )
    vi.add_argument('--data_dir', default='./datastore/data', help='Path to datastore/data')
    vi.add_argument('--results_file', default='./ingest_results.json', help='Output JSON file')
    vi.add_argument('--image', default=DEFAULT_IMAGE, help='gaiaDB image')
    vi.add_argument('--source', action='append', help='Only this source (repeatable)')
    vi.add_argument('--exclude', action='append', help='Skip this source (repeatable)')
    vi.add_argument('--jobs', type=int, default=2, help='Parallel containers')
    vi.add_argument('--timeout', type=float, default=1800, help='Seconds allowed per source')
    vi.add_argument('--platform', default=None, help='Docker platform, e.g. linux/amd64')
    vi.add_argument('--work_dir', default=None, help='Parent directory for staged copies')
    vi.add_argument('--readme', default=None, help='README to update with the table')
    vi.add_argument('--include_deferred', action='store_true', help='Also run sources needing credentials')
    vi.add_argument('--exit_zero', action='store_true', help='Exit 0 even if sources fail')

    ir = subparsers.add_parser(
        'ingest_report', help='Render ingest result files into the README'
    )
    ir.add_argument('--results', nargs='+', required=True, help='Results JSON file(s)')
    ir.add_argument('--readme', required=True, help='README containing the markers')


def dispatch(args: argparse.Namespace) -> int:
    """Run the sub-command named in args and return a process exit code."""
    if args.command == 'ingest_report':
        report = merge_reports([Path(p) for p in args.results])
        update_readme(report, Path(args.readme))
        return 0
    logging.basicConfig(level=logging.INFO)
    report = run_validation(
        Path(args.data_dir),
        Path(args.results_file),
        image=args.image,
        only=args.source,
        exclude=args.exclude,
        jobs=args.jobs,
        timeout=args.timeout,
        platform=args.platform,
        work_dir=Path(args.work_dir) if args.work_dir else None,
        include_deferred=args.include_deferred,
    )
    if args.readme:
        update_readme(report, Path(args.readme))
    failed = [r for r in report['results'] if r['status'] in (FAIL, TIMEOUT)]
    return 0 if args.exit_zero or not failed else 1


if __name__ == '__main__':
    # Standalone use without the heavy masterControl dependencies.
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    add_subcommands(sub)
    sys.exit(dispatch(parser.parse_args()))
