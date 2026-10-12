# sourced by bin/dev-ai-server-up
# Firewall name is fixed: one ruleset, attached to whatever NAME is running.
FIREWALL_NAME="dev-ai-ts"

# Interpolated into user-data. Reject anything that could break the shell line.
check_authkey() {
  case "$1" in
    tskey-auth-*) ;;
    *)
      echo "tailscale/authkey must be one tskey-auth- token with no spaces." >&2
      return 1
      ;;
  esac
  # case globs are not regexes: reject any char outside the token set, including spaces.
  case "$1" in
    *[!A-Za-z0-9_-]*)
      echo "tailscale/authkey must be one tskey-auth- token with no spaces." >&2
      return 1
      ;;
  esac
}

# $1 template, $2 auth key, $3 tailscale hostname. Prints cloud-config.
# Fails if the template has no tailscale-join marker.
render_user_data() {
  local template=$1 key=$2 name=$3 out
  check_authkey "$key" || return 1
  case "$name" in
    "" | *[!A-Za-z0-9-]*)
      echo "NAME must be letters, digits, and dashes." >&2
      return 1
      ;;
  esac
  out=$(awk -v key="$key" -v name="$name" '
    $0 == "  - \"true\" # tailscale-join" {
      print "  - curl -fsSL https://tailscale.com/install.sh | sh"
      print "  - install -d -m 700 /etc/tailscale"
      print "  - printf %s " key " > /etc/tailscale/authkey"
      print "  - chmod 600 /etc/tailscale/authkey"
      # Not --ssh: that ignores authorized_keys and breaks key bootstrap.
      # Not ephemeral: the next boot reuses /var/lib/tailscale from the snapshot.
      print "  - tailscale up --auth-key=file:/etc/tailscale/authkey --hostname=" name " --accept-dns=false --timeout=120s"
      print "  - rm -f /etc/tailscale/authkey"
      next
    }
    { print }
  ' "$template")
  printf '%s\n' "$out" | grep -q -- "--hostname=${name} " || {
    echo "cloud-config.yaml is missing the tailscale-join marker." >&2
    return 1
  }
  printf '%s\n' "$out"
}

# stdin: `tailscale status --json`. $1 hostname. Prints the IPv4, or nothing.
# shortcut: first online peer with this hostname wins. Delete stale nodes if SSH hits the wrong one.
ts_peer_ip() {
  jq -r --arg n "$1" '
    [ .Peer[]? | select(.HostName == $n and .Online == true) | .TailscaleIPs[]? | select(contains(".")) ]
    | first // empty
  '
}
