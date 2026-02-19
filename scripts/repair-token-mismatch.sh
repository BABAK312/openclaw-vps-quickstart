#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/repair-token-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] repair-token-mismatch.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: ./scripts/repair-token-mismatch.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_value() {
  local opt="$1"
  local value="${2-}"
  [[ -n "$value" ]] || fail "Missing value for ${opt}"
}

validate_host() {
  local host="$1"
  [[ -n "$host" ]] || fail "--host is required"
  [[ "$host" != -* ]] || fail "Invalid --host value: $host"
  [[ "$host" =~ ^[A-Za-z0-9._:-]+$ ]] || fail "Invalid --host value: $host"
}

validate_user() {
  local user="$1"
  local opt_name="$2"
  [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail "Invalid ${opt_name} value: $user"
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || fail "Invalid --ssh-port value: $port"
  ((port >= 1 && port <= 65535)) || fail "Invalid --ssh-port value: $port"
}

HOST=""
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/openclaw_vps_ed25519"
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) require_value "$1" "${2-}"; HOST="$2"; shift 2 ;;
    --openclaw-user) require_value "$1" "${2-}"; OPENCLAW_USER="$2"; shift 2 ;;
    --ssh-key) require_value "$1" "${2-}"; SSH_KEY="$2"; shift 2 ;;
    --ssh-port) require_value "$1" "${2-}"; SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

validate_host "$HOST"
validate_user "$OPENCLAW_USER" "--openclaw-user"
validate_port "$SSH_PORT"
[[ -z "${SSH_CONNECTION:-}" ]] || fail "Run from local terminal"

SSH_KEY="${SSH_KEY/#\~/$HOME}"
CONN="${OPENCLAW_USER}@${HOST}"
SSH_OPTS=(-p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

ssh "${SSH_OPTS[@]}" "$CONN" "bash -s" <<'REMOTE'
set -euo pipefail

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

OCC="$HOME/.openclaw/bin/openclaw"
if [[ ! -x "$OCC" ]]; then
  echo "OpenClaw CLI not found at $OCC" >&2
  exit 1
fi

sync_gateway_service_token() {
  local token="$1"
  [[ -n "$token" && "$token" != "null" ]] || return 0
  local dropin_dir="$HOME/.config/systemd/user/openclaw-gateway.service.d"
  mkdir -p "$dropin_dir"
  cat > "$dropin_dir/override.conf" <<EOF
[Service]
Environment=OPENCLAW_GATEWAY_TOKEN=$token
EOF
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

$OCC gateway stop || true
rm -f "$HOME/.openclaw/identity/device.json" "$HOME/.openclaw/identity/device-auth.json"
rm -f "$HOME/.openclaw/devices/paired.json" "$HOME/.openclaw/devices/pending.json"
rm -f "$HOME/.openclaw/nodes/paired.json" "$HOME/.openclaw/nodes/pending.json"
chmod 700 "$HOME/.openclaw" "$HOME/.openclaw/credentials" "$HOME/.openclaw/agents" "$HOME/.openclaw/agents/main" "$HOME/.openclaw/agents/main/sessions" || true
$OCC doctor --fix --yes --non-interactive || true
TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
sync_gateway_service_token "$TOKEN"
$OCC gateway install --force
$OCC gateway restart || $OCC gateway start || true
TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
echo "Gateway token: $TOKEN"
$OCC gateway status || true
$OCC status || true
REMOTE

echo
echo "If browser still shows token/device mismatch:"
echo "1) Close old dashboard tabs"
echo "2) Open a private/incognito window"
echo "3) Open http://127.0.0.1:18789 via SSH tunnel and paste latest token"
echo "Log: $LOG_FILE"
