#!/usr/bin/env bash
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# Log to file (without colors)
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<USAGE
Usage: ./bootstrap.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --root-user <user>         Initial privileged SSH user (default: root)
  --openclaw-user <user>     Service user to create/use (default: openclaw)
  --ssh-key <path>           SSH private key path (default: ~/.ssh/id_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --no-harden-ssh            Do not change sshd auth settings
  --no-upgrade               Skip apt upgrade/full-upgrade on server
  -h, --help                 Show this help
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

step() {
  printf "\n${BOLD}${BLUE}[%s]${NC} %s\n" "$1" "$2"
}

HOST=""
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/id_ed25519"
SSH_PORT="22"
HARDEN_SSH="yes"
UPGRADE_SYSTEM="yes"

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
    --no-harden-ssh)
      HARDEN_SSH="no"
      shift 1
      ;;
    --no-upgrade)
      UPGRADE_SYSTEM="no"
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
  fail "Run this script from your local Mac/Linux terminal, not inside VPS shell."
fi

# Print banner
printf '\n'
printf '%s\n' "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${CYAN}${BOLD}║           OpenClaw VPS Quickstart v1.0.0                   ║${NC}"
printf '%s\n' "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'

SSH_KEY="${SSH_KEY/#\~/$HOME}"
PUB_KEY="${SSH_KEY}.pub"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
CONTROL_PATH="${TMPDIR:-/tmp}/ocw-%C.sock"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

require_cmd ssh
require_cmd ssh-keygen
require_cmd grep
require_cmd sort

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

if [[ ! -f "$SSH_KEY" ]]; then
  info "No SSH key found at $SSH_KEY; generating new ed25519 key"
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -t ed25519 -C "openclaw-vps" -f "$SSH_KEY"
fi

[[ -f "$PUB_KEY" ]] || fail "Public key not found: $PUB_KEY"

copy_pubkey_to_root() {
  info "Copying public key to $ROOT_CONN (password prompt may appear once)"

  if command -v ssh-copy-id >/dev/null 2>&1; then
    ssh-copy-id -i "$PUB_KEY" -p "$SSH_PORT" "$ROOT_CONN"
    return
  fi

  warn "ssh-copy-id is not installed; using manual key append fallback"
  cat "$PUB_KEY" | ssh -p "$SSH_PORT" -o StrictHostKeyChecking=accept-new "$ROOT_CONN" \
    "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"
}

info "[1/8] Checking root key-based SSH access"
if ! ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROOT_CONN" 'echo key-auth-ok' >/dev/null 2>&1; then
  copy_pubkey_to_root
fi
ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$ROOT_CONN" 'echo key-auth-ok' >/dev/null
ok "SSH key authentication verified"

step "2/8" "Bootstrapping remote host as $ROOT_CONN"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "OPENCLAW_USER='$OPENCLAW_USER' HARDEN_SSH='$HARDEN_SSH' UPGRADE_SYSTEM='$UPGRADE_SYSTEM' bash -s" <<'REMOTE'
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_HOME="/home/${OPENCLAW_USER}"
HARDEN_SSH="${HARDEN_SSH:-yes}"
UPGRADE_SYSTEM="${UPGRADE_SYSTEM:-yes}"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  if [[ "$UPGRADE_SYSTEM" == "yes" ]]; then
    apt-get upgrade -y
  fi
  apt-get install -y curl ca-certificates sudo
fi

if [[ -f /var/run/reboot-required ]]; then
  echo "[WARN] Server reboot is required after package upgrades." >&2
fi

if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$OPENCLAW_USER"
fi

usermod -aG sudo "$OPENCLAW_USER"
install -d -m 700 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" "$OPENCLAW_HOME/.ssh"

if [[ -f /root/.ssh/authorized_keys ]]; then
  touch "$OPENCLAW_HOME/.ssh/authorized_keys"
  cat /root/.ssh/authorized_keys >> "$OPENCLAW_HOME/.ssh/authorized_keys"
  sort -u "$OPENCLAW_HOME/.ssh/authorized_keys" -o "$OPENCLAW_HOME/.ssh/authorized_keys"
fi

chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_HOME/.ssh"
chmod 700 "$OPENCLAW_HOME/.ssh"
chmod 600 "$OPENCLAW_HOME/.ssh/authorized_keys" || true

loginctl enable-linger "$OPENCLAW_USER" || true

if [[ "$HARDEN_SSH" == "yes" ]] && [[ -f /etc/ssh/sshd_config ]]; then
  set_sshd_option() {
    local key="$1"
    local value="$2"
    local file="/etc/ssh/sshd_config"
    if grep -qiE "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
      sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|I" "$file"
    else
      printf "%s %s\n" "$key" "$value" >> "$file"
    fi
  }

  set_sshd_option "PubkeyAuthentication" "yes"
  set_sshd_option "PasswordAuthentication" "no"
  set_sshd_option "KbdInteractiveAuthentication" "no"
  set_sshd_option "PermitRootLogin" "prohibit-password"

  if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
    systemctl restart ssh
  elif systemctl list-unit-files 2>/dev/null | grep -q '^sshd.service'; then
    systemctl restart sshd
  fi
fi

sudo -iu "$OPENCLAW_USER" bash <<'SU_SCRIPT'
set -euo pipefail

curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh | bash

if ! grep -q '"$HOME/.openclaw/bin"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.openclaw/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.openclaw/bin:$PATH"

openclaw config set gateway.mode local
openclaw config set gateway.bind loopback
openclaw doctor --fix --yes --non-interactive || true

mkdir -p "$HOME/.openclaw/credentials" "$HOME/.openclaw/agents/main/sessions"
chmod 700 "$HOME/.openclaw" || true
chmod 700 "$HOME/.openclaw/credentials" || true
chmod 700 "$HOME/.openclaw/agents" "$HOME/.openclaw/agents/main" "$HOME/.openclaw/agents/main/sessions" || true

openclaw gateway install --force
openclaw gateway restart

TOKEN="$(openclaw config get gateway.auth.token 2>/dev/null || true)"
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  openclaw doctor --generate-gateway-token >/dev/null 2>&1 || true
  openclaw doctor --fix --yes --non-interactive || true
fi

if openclaw status 2>&1 | grep -q 'device token mismatch'; then
  openclaw gateway stop || true
  rm -f "$HOME/.openclaw/identity/device.json" "$HOME/.openclaw/identity/device-auth.json"
  rm -f "$HOME/.openclaw/devices/paired.json" "$HOME/.openclaw/devices/pending.json"
  rm -f "$HOME/.openclaw/nodes/paired.json" "$HOME/.openclaw/nodes/pending.json"
  openclaw doctor --fix --yes --non-interactive || true
  openclaw gateway install --force
  openclaw gateway start || true
fi
SU_SCRIPT
REMOTE

step "3/8" "Verifying linger and service state"
ssh "${SSH_OPTS[@]}" "$ROOT_CONN" "loginctl show-user $OPENCLAW_USER -p Linger"

step "4/8" "Verifying OpenClaw gateway/status"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "~/.openclaw/bin/openclaw gateway status || true; ~/.openclaw/bin/openclaw status || true"

step "5/8" "Verifying permissions"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions"

step "6/8" "Checking for hardened allowlist/proxy traces"
ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "grep -niE 'allowlist|squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals|tools.yaml' ~/.openclaw/openclaw.json ~/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true"

step "7/8" "Retrieving gateway token"
TOKEN=$(ssh "${SSH_OPTS[@]}" "$OPENCLAW_CONN" "~/.openclaw/bin/openclaw config get gateway.auth.token 2>/dev/null || true")
[[ -n "$TOKEN" ]] && info "Gateway token: ${GREEN}${TOKEN}${NC}"

step "8/8" "Bootstrap complete"
printf '\n'
printf '%s\n' "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${GREEN}${BOLD}║         OpenClaw VPS Bootstrap Complete!                   ║${NC}"
printf '%s\n' "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'
printf '${CYAN}Next steps:${NC}\n'
printf '  1. Create SSH tunnel from your local terminal:\n'
printf '     ${YELLOW}ssh -i %s -N -L 18789:127.0.0.1:18789 %s${NC}\n' "$SSH_KEY" "$OPENCLAW_CONN"
printf '\n'
printf '  2. Open in browser: ${GREEN}http://127.0.0.1:18789${NC}\n'
printf '\n'
printf '  3. When ready to connect providers/channels:\n'
printf '     ${YELLOW}openclaw onboard${NC}\n'
printf '\n'
printf 'Log file: %s\n' "$LOG_FILE"
