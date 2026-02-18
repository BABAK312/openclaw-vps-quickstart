#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/repair-token-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<USAGE
Usage: ./scripts/repair-token-mismatch.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

HOST=""
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --openclaw-user) OPENCLAW_USER="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { echo "--host is required" >&2; exit 1; }
[[ -z "${SSH_CONNECTION:-}" ]] || { echo "Run from local terminal" >&2; exit 1; }

SSH_KEY="${SSH_KEY/#\~/$HOME}"
CONN="${OPENCLAW_USER}@${HOST}"
SSH_OPTS=(-p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

ssh "${SSH_OPTS[@]}" "$CONN" "bash -s" <<'REMOTE'
set -euo pipefail

OCC="$HOME/.openclaw/bin/openclaw"
$OCC gateway stop || true
rm -f "$HOME/.openclaw/identity/device.json" "$HOME/.openclaw/identity/device-auth.json"
rm -f "$HOME/.openclaw/devices/paired.json" "$HOME/.openclaw/devices/pending.json"
rm -f "$HOME/.openclaw/nodes/paired.json" "$HOME/.openclaw/nodes/pending.json"
chmod 700 "$HOME/.openclaw" "$HOME/.openclaw/credentials" "$HOME/.openclaw/agents" "$HOME/.openclaw/agents/main" "$HOME/.openclaw/agents/main/sessions" || true
$OCC doctor --fix --yes --non-interactive || true
$OCC gateway install --force
$OCC gateway restart
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
