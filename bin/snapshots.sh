# sourced by dev-ai-server-up and dev-ai-server-down
# Caller sets SNAPSHOT_LABEL. Hetzner bills every snapshot until it is deleted.

KEEP_SNAPSHOTS=2

# Ids to delete: available snapshots past the newest $1. Skip delete-protected.
snapshot_ids_beyond() {
  jq -r --argjson keep "$1" '
    [ .[] | select(.status == "available") ]
    | sort_by(.created) | reverse
    | .[$keep:][]
    | select((.protection.delete // false) | not)
    | .id
  '
}

newest_snapshot_id() {
  jq -r '
    [ .[] | select(.status == "available") ]
    | sort_by(.created) | reverse
    | if length == 0 then empty else .[0].id end
  '
}

# Sets NEWEST_SNAPSHOT_ID from the list before deletes (that image is kept).
prune_snapshots() {
  local snapshots old_ids
  snapshots=$(hcloud image list --type snapshot --selector "$SNAPSHOT_LABEL" -o json)
  old_ids=$(printf '%s' "$snapshots" | snapshot_ids_beyond "$KEEP_SNAPSHOTS")
  if [ -n "$old_ids" ]; then
    echo "Deleting old snapshots: ${old_ids//$'\n'/ }"
    # Ids are numeric.
    # shellcheck disable=SC2086
    hcloud image delete $old_ids
  fi
  NEWEST_SNAPSHOT_ID=$(printf '%s' "$snapshots" | newest_snapshot_id)
}

# Deletes every unprotected available snapshot. Fails if any remain.
delete_snapshots() {
  local snapshots ids left
  snapshots=$(hcloud image list --type snapshot --selector "$SNAPSHOT_LABEL" -o json)
  ids=$(printf '%s' "$snapshots" | snapshot_ids_beyond 0)
  if [ -n "$ids" ]; then
    echo "Deleting snapshots: ${ids//$'\n'/ }"
    # shellcheck disable=SC2086
    hcloud image delete $ids
  fi
  left=$(hcloud image list --type snapshot --selector "$SNAPSHOT_LABEL" -o json \
    | jq '[.[] | select(.status == "available" or .status == "creating")] | length')
  if [ "$left" != 0 ]; then
    echo "Snapshots for $SNAPSHOT_LABEL still exist (delete-protected or still creating). Not booting." >&2
    exit 1
  fi
  NEWEST_SNAPSHOT_ID=
}
