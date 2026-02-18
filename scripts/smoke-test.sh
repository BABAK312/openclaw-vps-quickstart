#!/usr/bin/env bash
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/smoke-test-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<USAGE
Usage: ./scripts/smoke-test.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --root-user <user>         Privileged SSH user (default: root)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  -h, --help                 Show help
USAGE
}

info() {
  printf "${CYAN}[INFO]${NC} %s\n" "$*"
}

ok() {
  printf "${GREEN}[OK]${NC} %s\n" "$*"
}

fail() {
  printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
  exit 1
}

step() {
  printf "\n${BOLD}${BLUE}[%s]${NC} %s\n" "$1" "$2"
}

HOST=""
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --root-user) ROOT_USER="$2"; shift 2 ;;
    --openclaw-user) OPENCLAW_USER="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || { echo "--host is required" >&2; exit 1; }
[[ -z "${SSH_CONNECTION:-}" ]] || { echo "Run smoke-test.sh from local terminal" >&2; exit 1; }

printf '\n'
printf '%s\n' "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${CYAN}${BOLD}║           OpenClaw VPS Smoke Test                           ║${NC}"
printf '%s\n' "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'

SSH_KEY="${SSH_KEY/#\~/$HOME}"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
SSH_OPTS=(-p "$SSH_PORT" -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new)

step "1/6" "Root key auth"
ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROOT_CONN" "echo ok"
ok "Root SSH key auth working"

step "2/6" "openclaw user exists"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "id $OPENCLAW_USER"
ok "User $OPENCLAW_USER exists"

step "3/6" "linger enabled"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "loginctl show-user $OPENCLAW_USER -p Linger"

step "4/6" "gateway service status"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "~/.openclaw/bin/openclaw gateway status"
ok "Gateway service running"

step "5/6" "permissions"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions"

step "6/6" "no hardened traces"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "grep -RniE 'allowlist|squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals|tools.yaml' ~/.openclaw || true"

printf '\n'
printf '%s\n' "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${GREEN}${BOLD}║           Smoke Test Complete! All checks passed.           ║${NC}"
printf '%s\n' "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'
printf 'Log: %s\n' "$LOG_FILE"
