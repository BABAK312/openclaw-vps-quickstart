#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

ORIG_STDOUT_IS_TTY=0
if [[ -t 1 ]]; then
  ORIG_STDOUT_IS_TTY=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/verify-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] verify.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: ./verify.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --initial-user <user>      Initial SSH user for first login (default: root)
  --root-user <user>         Privileged SSH user (default: root)
  --openclaw-user <user>     OpenClaw user (default: openclaw)
  --ssh-key <path>           SSH private key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --repair                   Attempt automatic repairs (permissions + token mismatch reset)
  -h, --help                 Show help
USAGE
}

USE_COLOR=0
if [[ "$ORIG_STDOUT_IS_TTY" -eq 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  USE_COLOR=1
fi

if [[ "$USE_COLOR" -eq 1 ]]; then
  C_RESET=$'\033[0m'
  C_INFO=$'\033[1;36m'
  C_ERR=$'\033[1;31m'
  C_TITLE=$'\033[1;34m'
else
  C_RESET=""
  C_INFO=""
  C_ERR=""
  C_TITLE=""
fi

print_banner() {
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
  printf '%b\n' "${C_TITLE} OpenClaw VPS Verify${C_RESET}"
  printf '%b\n' "${C_TITLE} Диагностика состояния сервера${C_RESET}"
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
}

info() {
  printf '%b[INFO]%b %s\n' "$C_INFO" "$C_RESET" "$*"
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
REPAIR="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      require_value "$1" "${2-}"
      HOST="$2"
      shift 2
      ;;
    --initial-user)
      require_value "$1" "${2-}"
      ROOT_USER="$2"
      shift 2
      ;;
    --root-user)
      require_value "$1" "${2-}"
      ROOT_USER="$2"
      shift 2
      ;;
    --openclaw-user)
      require_value "$1" "${2-}"
      OPENCLAW_USER="$2"
      shift 2
      ;;
    --ssh-key)
      require_value "$1" "${2-}"
      SSH_KEY="$2"
      shift 2
      ;;
    --ssh-port)
      require_value "$1" "${2-}"
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

validate_host "$HOST"
validate_user "$ROOT_USER" "--initial-user/--root-user"
validate_user "$OPENCLAW_USER" "--openclaw-user"
validate_port "$SSH_PORT"
print_banner
info "Лог verify: $LOG_FILE"

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  fail "Run verify.sh from your local terminal, not inside VPS shell"
fi

SSH_KEY="${SSH_KEY/#\~/$HOME}"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
CONTROL_DIR="/tmp/ocw-cm-${USER:-user}"
mkdir -p "$CONTROL_DIR"
chmod 700 "$CONTROL_DIR" >/dev/null 2>&1 || true
CONTROL_PATH="$CONTROL_DIR/%C"

SSH_OPTS=(
  -p "$SSH_PORT"
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectionAttempts=3
  -o ConnectTimeout=20
  -o ServerAliveInterval=20
  -o ServerAliveCountMax=3
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$CONTROL_PATH"
)
SSH_OPTS_NO_MUX=("${SSH_OPTS[@]}" -o ControlMaster=no -o ControlPath=none)
SSH_RETRY_ATTEMPTS=3
SSH_RETRY_BASE_DELAY=4

ssh_retry_exec() {
  local conn="$1"
  local remote_cmd="$2"
  local attempt rc delay
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if ssh "${SSH_OPTS_NO_MUX[@]}" -o BatchMode=yes "$conn" "$remote_cmd"; then
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    printf '%b[INFO]%b SSH transient error to %s (exit %s), retry %s/%s in %ss...\n' \
      "$C_INFO" "$C_RESET" "$conn" "$rc" "$attempt" "$SSH_RETRY_ATTEMPTS" "$delay"
    sleep "$delay"
  done
  return 1
}

ssh_root_retry() {
  ssh_retry_exec "$ROOT_CONN" "$1"
}

ssh_openclaw_retry() {
  ssh_retry_exec "$OPENCLAW_CONN" "$1"
}

cleanup() {
  ssh "${SSH_OPTS[@]}" -O exit "$ROOT_CONN" >/dev/null 2>&1 || true
  ssh "${SSH_OPTS[@]}" -O exit "$OPENCLAW_CONN" >/dev/null 2>&1 || true
}
trap cleanup EXIT

info "== Linger =="
ssh_root_retry "loginctl show-user ${OPENCLAW_USER} -p Linger"

info "== OpenClaw user =="
ssh_root_retry "id ${OPENCLAW_USER}"

info "== Server reboot-required status =="
ssh_root_retry "if [[ -f /var/run/reboot-required ]]; then echo 'reboot-required: yes'; else echo 'reboot-required: no'; fi"

info "== Host hardening baseline (UFW/Fail2ban/Auto-updates) =="
ssh_root_retry "echo 'UFW:'; ufw status verbose | sed -n '1,12p'; echo; echo 'Fail2ban:'; systemctl is-enabled fail2ban 2>/dev/null || true; systemctl is-active fail2ban 2>/dev/null || true; fail2ban-client status sshd 2>/dev/null || true; echo; echo 'Unattended upgrades:'; systemctl is-enabled unattended-upgrades 2>/dev/null || true"

info "== Gateway/Status =="
ssh_openclaw_retry "export XDG_RUNTIME_DIR=/run/user/\$(id -u); export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus; ~/.openclaw/bin/openclaw gateway status || true; ~/.openclaw/bin/openclaw status || true"

info "== Permissions =="
ssh_openclaw_retry "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions 2>/dev/null || true"

info "== Hardened restriction traces in active config =="
ssh_openclaw_retry "grep -niE 'squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals\\.json|tools\\.yaml|allowlist\\.txt|openclaw-squid|openclaw-litellm' ~/.openclaw/openclaw.json ~/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true"

info "== Legacy hardened containers check =="
ssh_root_retry "podman ps --format '{{.Names}}' 2>/dev/null | grep -E 'openclaw-squid|openclaw-litellm|openclaw-agent' || true"

if [[ "$REPAIR" == "yes" ]]; then
  info "== Repair mode =="
  ssh "${SSH_OPTS_NO_MUX[@]}" -o BatchMode=yes "$OPENCLAW_CONN" "bash -s" <<'REMOTE_REPAIR'
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

TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
sync_gateway_service_token "$TOKEN"
$OCC gateway install --force
$OCC gateway restart || $OCC gateway start || true
chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents ~/.openclaw/agents/main ~/.openclaw/agents/main/sessions || true
TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
$OCC gateway status || true
$OCC status || true
echo "Gateway token: $TOKEN"
REMOTE_REPAIR
fi

printf '\nLog file: %s\n' "$LOG_FILE"
