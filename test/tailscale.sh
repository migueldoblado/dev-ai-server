#!/bin/bash
# Assert user-data rendering and peer selection. No Hetzner or Tailscale calls.
set -euo pipefail

BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
# shellcheck disable=SC1091
source "$BIN/tailscale.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<'EOF'
runcmd:
  - systemctl reload ssh
  - "true" # tailscale-join

final_message: "ok"
EOF

out=$(render_user_data "$tmp" tskey-auth-abc_DEF-123 dev-ai)
printf '%s\n' "$out" | grep -q 'tailscale-join' && fail "marker should be replaced"
printf '%s\n' "$out" | grep -q -- '--hostname=dev-ai ' || fail "hostname missing"
printf '%s\n' "$out" | grep -q 'printf %s tskey-auth-abc_DEF-123 > /etc/tailscale/authkey' || fail "key line"
printf '%s\n' "$out" | grep -q 'rm -f /etc/tailscale/authkey' || fail "key should be removed after join"
printf '%s\n' "$out" | grep -q -- '--ssh' && fail "tailscale ssh must stay off"
printf '%s\n' "$out" | grep -q 'final_message:' || fail "rest of template dropped"

if render_user_data "$tmp" 'tskey-auth-has space' dev-ai >/dev/null 2>&1; then
  fail "key with a space should be rejected"
fi
if render_user_data "$tmp" 'not-a-key' dev-ai >/dev/null 2>&1; then
  fail "non auth key should be rejected"
fi
if render_user_data "$tmp" tskey-auth-ok 'bad name' >/dev/null 2>&1; then
  fail "bad NAME should be rejected"
fi

online='{"Peer":{"nodekey:1":{"HostName":"dev-ai","Online":true,"TailscaleIPs":["100.64.0.2","fd7a::1"]},"nodekey:2":{"HostName":"other","Online":true,"TailscaleIPs":["100.64.0.3"]}}}'
[ "$(printf '%s' "$online" | ts_peer_ip dev-ai)" = "100.64.0.2" ] || fail "online peer"
offline='{"Peer":{"nodekey:1":{"HostName":"dev-ai","Online":false,"TailscaleIPs":["100.64.0.2"]}}}'
[ -z "$(printf '%s' "$offline" | ts_peer_ip dev-ai)" ] || fail "offline peer should be ignored"

grep -q 'tailscale/authkey' "$BIN/dev-ai-server-up" || fail "up does not read the auth key"
grep -q 'FIREWALL_NAME' "$BIN/dev-ai-server-up" || fail "up does not attach the firewall"
grep -q 'tailscale-join' "$BIN/../cloud-config.yaml" || fail "cloud-config marker"

echo "ok"
