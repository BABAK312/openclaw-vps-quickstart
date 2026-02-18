#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: ./scripts/connect.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --user <user>              SSH user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

HOST=""
USER_NAME="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { echo "--host is required" >&2; exit 1; }
[[ -z "${SSH_CONNECTION:-}" ]] || { echo "Run connect.sh from local terminal" >&2; exit 1; }

SSH_KEY="${SSH_KEY/#\~/$HOME}"
exec ssh -p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "${USER_NAME}@${HOST}"
