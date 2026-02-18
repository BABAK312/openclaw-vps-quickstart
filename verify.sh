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
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/verify-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<USAGE
Usage: ./verify.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --root-user <user>         Privileged SSH user (default: root)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH private key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --repair                   Attempt automatic repairs (permissions + token mismatch reset)
  -h, --help                 Show help
USAGE
}

info() {
  printf "${CYAN}[INFO]${NC} %s\n" "$*"
}

ok() {
  printf "${GREEN}[OK]${NC} %s\n" "$*"
}

warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$*"
}

fail() {
  printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
  exit 1
}

section() {
  printf "\n${BOLD}${BLUE}== %s ==${NC}\n" "$*"
}

HOST=""
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"
REPAIR="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --root-user)
      ROOT_USER="$2"
      shift 2
      ;;
    --openclaw-user)
      OPENCLAW_USER="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --repair)
      REPAIR="yes"
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$HOST" ]] || fail "--host is required"

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  fail "Run verify.sh from your local terminal, not inside VPS shell"
fi

SSH_KEY="${SSH_KEY/#\~/$HOME}"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
CONTROL_PATH="${TMPDIR:-/tmp}/ocw-%C.sock"

SSH_OPTS=(
  -p "$SSH_PORT"
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=20
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$CONTROL_PATH"
)

cleanup() {
  ssh "${SSH_OPTS[@]}" -O exit "$ROOT_CONN" >/dev/null 2>&1 || true
  ssh "${SSH_OPTS[@]}" -O exit "$OPENCLAW_CONN" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '\n'
printf '%s\n' "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${CYAN}${BOLD}║           OpenClaw VPS Verification                         ║${NC}"
printf '%s\n' "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'

section "Linger"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "loginctl show-user ${OPENCLAW_USER} -p Linger"

section "Gateway/Status"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "~/.openclaw/bin/openclaw gateway status || true; ~/.openclaw/bin/openclaw status || true"

section "Permissions"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions 2>/dev/null || true"

section "Hardened restriction traces"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "grep -niE 'allowlist|squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals|tools.yaml' ~/.openclaw/openclaw.json ~/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true"

section "Legacy hardened containers check"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "podman ps --format '{{.Names}}' 2>/dev/null | grep -E 'openclaw-squid|openclaw-litellm|openclaw-agent' || true"

if [[ "$REPAIR" == "yes" ]]; then
  section "Repair mode"
  ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "bash -s" <<'REMOTE_REPAIR'
set -euo pipefail

OCC="$HOME/.openclaw/bin/openclaw"
TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  $OCC doctor --generate-gateway-token >/dev/null 2>&1 || true
  TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
fi

$OCC config set gateway.mode local || true
$OCC config set gateway.bind loopback || true
$OCC gateway stop || true

chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents ~/.openclaw/agents/main ~/.openclaw/agents/main/sessions || true
$OCC doctor --fix --yes --non-interactive || true

if $OCC status 2>&1 | grep -q 'device token mismatch'; then
  rm -f ~/.openclaw/identity/device.json ~/.openclaw/identity/device-auth.json
  rm -f ~/.openclaw/devices/paired.json ~/.openclaw/devices/pending.json
  rm -f ~/.openclaw/nodes/paired.json ~/.openclaw/nodes/pending.json
  $OCC doctor --fix --yes --non-interactive || true
fi

$OCC gateway install --force
$OCC gateway restart
$OCC gateway status || true
$OCC status || true
echo "Gateway token: $TOKEN"
REMOTE_REPAIR
fi

printf '\n'
printf '%s\n' "${GREEN}${BOLD}Verification complete!${NC}"
printf 'Log file: %s\n' "$LOG_FILE"
