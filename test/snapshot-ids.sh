#!/bin/bash
# Assert snapshot selection. No Hetzner calls.
set -euo pipefail

BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
# shellcheck disable=SC1091
source "$BIN/snapshots.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

ids() { printf '%s' "$1" | snapshot_ids_beyond 2 | tr '\n' ' '; }
newest() { printf '%s' "$1" | newest_snapshot_id; }

empty='[]'
[ -z "$(ids "$empty")" ] || fail "empty should delete nothing"
[ -z "$(newest "$empty")" ] || fail "empty has no newest"

one='[
  {"id":1,"status":"available","created":"2026-01-01T00:00:00Z","protection":{"delete":false}}
]'
[ -z "$(ids "$one")" ] || fail "one snapshot should be kept"
[ "$(newest "$one")" = 1 ] || fail "newest of one"

three='[
  {"id":2,"status":"available","created":"2026-01-02T00:00:00Z","protection":{"delete":false}},
  {"id":1,"status":"available","created":"2026-01-01T00:00:00Z","protection":{"delete":false}},
  {"id":3,"status":"available","created":"2026-01-03T00:00:00Z","protection":{"delete":false}}
]'
[ "$(ids "$three")" = "1 " ] || fail "should drop only the oldest, got [$(ids "$three")]"
[ "$(newest "$three")" = 3 ] || fail "newest should be 3"
[ "$(printf '%s' "$three" | snapshot_ids_beyond 0 | tr '\n' ' ')" = "3 2 1 " ] || fail "keep 0 should list all"

mixed='[
  {"id":9,"status":"creating","created":"2026-02-01T00:00:00Z","protection":{"delete":false}},
  {"id":4,"status":"available","created":"2026-01-04T00:00:00Z","protection":{"delete":true}},
  {"id":3,"status":"available","created":"2026-01-03T00:00:00Z","protection":{"delete":false}},
  {"id":2,"status":"available","created":"2026-01-02T00:00:00Z","protection":{"delete":false}},
  {"id":1,"status":"available","created":"2026-01-01T00:00:00Z"}
]'
# newest available are 4 and 3; delete 2 and 1 (4 is protected, 9 is not available)
[ "$(ids "$mixed")" = "2 1 " ] || fail "mixed prune, got [$(ids "$mixed")]"
[ "$(newest "$mixed")" = 4 ] || fail "newest available should ignore creating"

grep -q 'dev-ai-server=$NAME' "$BIN/dev-ai-server-up" || fail "up label"
grep -q 'dev-ai-server=$NAME' "$BIN/dev-ai-server-down" || fail "down label"
grep -q 'KEEP_SNAPSHOTS=2' "$BIN/snapshots.sh" || fail "keep count"
grep -q 'prune_snapshots' "$BIN/dev-ai-server-up" || fail "up does not prune"
grep -q 'prune_snapshots' "$BIN/dev-ai-server-down" || fail "down does not prune"
grep -q 'delete_snapshots' "$BIN/dev-ai-server-up" || fail "up has no clean wipe"
grep -q 'CLEAN:-' "$BIN/dev-ai-server-up" || fail "up has no CLEAN switch"

echo "ok"
