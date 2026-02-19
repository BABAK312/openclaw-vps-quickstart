#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

ORIG_STDOUT_IS_TTY=0
if [[ -t 1 ]]; then
  ORIG_STDOUT_IS_TTY=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/smoke-test-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] smoke-test.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: ./scripts/smoke-test.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --initial-user <user>      Initial SSH user for first login (default: root)
  --root-user <user>         Privileged SSH user (default: root)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

USE_COLOR=0
if [[ "$ORIG_STDOUT_IS_TTY" -eq 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  USE_COLOR=1
fi

if [[ "$USE_COLOR" -eq 1 ]]; then
  C_RESET=$'\033[0m'
  C_ERR=$'\033[1;31m'
  C_STEP=$'\033[1;35m'
  C_TITLE=$'\033[1;34m'
  C_OK=$'\033[1;32m'
else
  C_RESET=""
  C_ERR=""
  C_STEP=""
  C_TITLE=""
  C_OK=""
fi

print_banner() {
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
  printf '%b\n' "${C_TITLE} OpenClaw VPS Smoke Test${C_RESET}"
  printf '%b\n' "${C_TITLE} Быстрый контроль ключевых проверок${C_RESET}"
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
}

fail() {
  printf '%b[ERROR]%b %s\n' "$C_ERR" "$C_RESET" "$*" >&2
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
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/openclaw_vps_ed25519"
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) require_value "$1" "${2-}"; HOST="$2"; shift 2 ;;
    --initial-user) require_value "$1" "${2-}"; ROOT_USER="$2"; shift 2 ;;
    --root-user) require_value "$1" "${2-}"; ROOT_USER="$2"; shift 2 ;;
    --openclaw-user) require_value "$1" "${2-}"; OPENCLAW_USER="$2"; shift 2 ;;
    --ssh-key) require_value "$1" "${2-}"; SSH_KEY="$2"; shift 2 ;;
    --ssh-port) require_value "$1" "${2-}"; SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

validate_host "$HOST"
validate_user "$ROOT_USER" "--initial-user/--root-user"
validate_user "$OPENCLAW_USER" "--openclaw-user"
validate_port "$SSH_PORT"
[[ -z "${SSH_CONNECTION:-}" ]] || fail "Run smoke-test.sh from local terminal, not inside VPS shell"
print_banner
printf '%b[INFO]%b Лог smoke-test: %s\n' "$C_STEP" "$C_RESET" "$LOG_FILE"

SSH_KEY="${SSH_KEY/#\~/$HOME}"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
SSH_OPTS=(-p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

printf '%b[1/7]%b Root key auth\n' "$C_STEP" "$C_RESET"
ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROOT_CONN" "echo ok"

printf '%b[2/7]%b openclaw user exists\n' "$C_STEP" "$C_RESET"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "id $OPENCLAW_USER"

printf '%b[3/7]%b linger enabled\n' "$C_STEP" "$C_RESET"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "loginctl show-user $OPENCLAW_USER -p Linger"

printf '%b[4/7]%b gateway service status\n' "$C_STEP" "$C_RESET"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "export XDG_RUNTIME_DIR=/run/user/\$(id -u); export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus; ~/.openclaw/bin/openclaw gateway status"

printf '%b[5/7]%b permissions\n' "$C_STEP" "$C_RESET"
PERM_OUT="$(ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions")"
echo "$PERM_OUT"
if ! awk '{ if ($1 != 700) bad=1 } END { exit bad }' <<<"$PERM_OUT"; then
  echo "ERROR: permissions are not strict (expected 700 on all listed paths)" >&2
  exit 1
fi

printf '%b[6/7]%b host hardening baseline\n' "$C_STEP" "$C_RESET"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "echo 'UFW:'; ufw status | head -n2; echo 'Fail2ban:'; systemctl is-active fail2ban 2>/dev/null || true; echo 'Unattended upgrades:'; systemctl is-enabled unattended-upgrades 2>/dev/null || true"

printf '%b[7/7]%b no hardened traces\n' "$C_STEP" "$C_RESET"
TRACES="$(ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "grep -niE 'squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals\\.json|tools\\.yaml|allowlist\\.txt|openclaw-squid|openclaw-litellm' ~/.openclaw/openclaw.json ~/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true")"
if [[ -n "$TRACES" ]]; then
  echo "$TRACES"
  echo "ERROR: hardened proxy/allowlist traces found in active config" >&2
  exit 1
fi

echo
printf '%bSmoke test complete%b\n' "$C_OK" "$C_RESET"
echo "Log: $LOG_FILE"
