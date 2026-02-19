#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: ./scripts/connect.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --user <user>              SSH user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

HOST=""
USER_NAME="openclaw"
SSH_KEY="~/.ssh/openclaw_vps_ed25519"
SSH_PORT="22"

require_value() {
  local opt="$1"
  local value="${2-}"
  [[ -n "$value" ]] || { echo "Missing value for ${opt}" >&2; exit 1; }
}

validate_host() {
  local host="$1"
  [[ -n "$host" ]] || { echo "--host is required" >&2; exit 1; }
  [[ "$host" != -* ]] || { echo "Invalid --host value: $host" >&2; exit 1; }
  [[ "$host" =~ ^[A-Za-z0-9._:-]+$ ]] || { echo "Invalid --host value: $host" >&2; exit 1; }
}

validate_user() {
  local user="$1"
  [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid --user value: $user" >&2; exit 1; }
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || { echo "Invalid --ssh-port value: $port" >&2; exit 1; }
  ((port >= 1 && port <= 65535)) || { echo "Invalid --ssh-port value: $port" >&2; exit 1; }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) require_value "$1" "${2-}"; HOST="$2"; shift 2 ;;
    --user) require_value "$1" "${2-}"; USER_NAME="$2"; shift 2 ;;
    --ssh-key) require_value "$1" "${2-}"; SSH_KEY="$2"; shift 2 ;;
    --ssh-port) require_value "$1" "${2-}"; SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

validate_host "$HOST"
validate_user "$USER_NAME"
validate_port "$SSH_PORT"
[[ -z "${SSH_CONNECTION:-}" ]] || { echo "Run connect.sh from local terminal" >&2; exit 1; }

SSH_KEY="${SSH_KEY/#\~/$HOME}"
exec ssh -p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "${USER_NAME}@${HOST}"
