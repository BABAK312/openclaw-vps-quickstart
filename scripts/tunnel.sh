#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: ./scripts/tunnel.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --user <user>              SSH user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --remote-port <port>       Remote gateway port (default: 18789)
  --local-port <port>        Local forwarded port (default: 18789)
  -h, --help                 Show help
USAGE
}

HOST=""
USER_NAME="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"
REMOTE_PORT="18789"
LOCAL_PORT="18789"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --remote-port) REMOTE_PORT="$2"; shift 2 ;;
    --local-port) LOCAL_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { echo "--host is required" >&2; exit 1; }
[[ -z "${SSH_CONNECTION:-}" ]] || { echo "Run tunnel.sh from local terminal" >&2; exit 1; }

SSH_KEY="${SSH_KEY/#\~/$HOME}"

echo "Forwarding: http://127.0.0.1:${LOCAL_PORT} -> ${HOST}:127.0.0.1:${REMOTE_PORT}"
exec ssh -N -p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" "${USER_NAME}@${HOST}"
