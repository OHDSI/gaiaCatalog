#!/bin/sh
# Validate only the catalog entries that a branch adds or changes.
#
# The existing entries are not checked, so a clean-up is not needed before the gate can run;
# it only stops new debt. Errors fail the check, warnings are reported.
#
# Usage: architecture/defs/check_changed_entries.sh [base-ref]     (default: origin/main)
# Needs the schema requirements installed (schema/requirements.txt).
set -eu

BASE="${1:-origin/main}"
PYTHON="${PYTHON:-python3}"
cd "$(git rev-parse --show-toplevel)"

MERGE_BASE="$(git merge-base "$BASE" HEAD)"
# added, copied, modified or renamed JSON-LD files (deleted ones have nothing to check)
SOURCES="$(git diff --name-only --diff-filter=ACMR "$MERGE_BASE" HEAD -- 'datastore/data/*/meta_json-ld_*.json' \
  | awk -F/ '{print $3}' | sort -u)"

if [ -z "$SOURCES" ]; then
  echo "No catalog entries added or changed since $BASE: nothing to validate."
  exit 0
fi

echo "Validating $(echo "$SOURCES" | wc -l | tr -d ' ') changed entr(y/ies):"
echo "$SOURCES" | sed 's/^/  /'

set --
for s in $SOURCES; do set -- "$@" --source "$s"; done

RESULTS="$(mktemp)"
trap 'rm -f "$RESULTS"' EXIT
"$PYTHON" architecture/defs/validate_catalog.py validate_catalog \
  --data_dir datastore/data --results_file "$RESULTS" "$@"
