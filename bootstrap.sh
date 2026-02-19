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
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] bootstrap.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: ./bootstrap.sh --host <ip_or_host> [options]

Options:
  --host <host>              VPS IP or hostname (required)
  --initial-user <user>      Initial SSH user for first login (default: root)
  --root-user <user>         Initial privileged SSH user (default: root)
  --openclaw-user <user>     Service user to create/use (default: openclaw)
  --ssh-key <path>           SSH private key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --extra-keys <count>       Generate and authorize extra SSH keys (default: 0)
  --show-extra-private-keys  Print extra private keys to terminal output (dangerous: also saved to log)
  --no-harden-ssh            Do not change sshd auth settings
  --no-upgrade               Skip apt upgrade/full-upgrade on server
  -h, --help                 Show this help
USAGE
}

USE_COLOR=0
if [[ "${FORCE_COLOR:-}" == "1" ]]; then
  USE_COLOR=1
elif [[ "$ORIG_STDOUT_IS_TTY" -eq 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  USE_COLOR=1
fi

if [[ "$USE_COLOR" -eq 1 ]]; then
  C_RESET=$'\033[0m'
  C_INFO=$'\033[1;36m'
  C_WARN=$'\033[1;33m'
  C_ERR=$'\033[1;31m'
  C_STEP=$'\033[1;35m'
  C_OK=$'\033[1;32m'
  C_TITLE=$'\033[1;34m'
else
  C_RESET=""
  C_INFO=""
  C_WARN=""
  C_ERR=""
  C_STEP=""
  C_OK=""
  C_TITLE=""
fi

print_banner() {
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
  printf '%b\n' "${C_TITLE} OpenClaw VPS Bootstrap${C_RESET}"
  printf '%b\n' "${C_TITLE} Подготовка: SSH + user + hardening + OpenClaw${C_RESET}"
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
}

info() {
  printf '%b[INFO]%b %s\n' "$C_INFO" "$C_RESET" "$*"
}

warn() {
  printf '%b[WARN]%b %s\n' "$C_WARN" "$C_RESET" "$*"
}

fail() {
  printf '%b[ERROR]%b %s\n' "$C_ERR" "$C_RESET" "$*" >&2
  exit 1
}

step() {
  printf '%b[STEP %s/%s]%b %s\n' "$C_STEP" "$1" "$2" "$C_RESET" "$3"
}

ok() {
  printf '%b[OK]%b %s\n' "$C_OK" "$C_RESET" "$*"
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

validate_count() {
  local value="$1"
  local opt_name="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "Invalid ${opt_name} value: $value"
}

HOST=""
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="~/.ssh/openclaw_vps_ed25519"
SSH_PORT="22"
HARDEN_SSH="yes"
UPGRADE_SYSTEM="yes"
EXTRA_KEYS="0"
EXTRA_KEY_PREFIX="openclaw_vps_extra"
SHOW_EXTRA_PRIVATE_KEYS="no"

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
    --extra-keys)
      require_value "$1" "${2-}"
      EXTRA_KEYS="$2"
      shift 2
      ;;
    --show-extra-private-keys)
      SHOW_EXTRA_PRIVATE_KEYS="yes"
      shift 1
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

validate_host "$HOST"
validate_user "$ROOT_USER" "--initial-user/--root-user"
validate_user "$OPENCLAW_USER" "--openclaw-user"
validate_port "$SSH_PORT"
validate_count "$EXTRA_KEYS" "--extra-keys"

print_banner
info "Лог bootstrap: $LOG_FILE"
if [[ "$SHOW_EXTRA_PRIVATE_KEYS" == "yes" ]]; then
  warn "Extra private keys will be printed into terminal and saved in log."
  warn "Дополнительные private keys будут выведены в терминал и сохранены в лог."
fi

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  fail "Run this script from your local Mac/Linux terminal, not inside VPS shell."
fi

SSH_KEY="${SSH_KEY/#\~/$HOME}"
PUB_KEY="${SSH_KEY}.pub"
ROOT_CONN="${ROOT_USER}@${HOST}"
OPENCLAW_CONN="${OPENCLAW_USER}@${HOST}"
EXTRA_KEY_DIR="$(dirname "$SSH_KEY")"
EXTRA_KEYS_MANIFEST="$LOG_DIR/extra-ssh-keys-$(date +%Y%m%d-%H%M%S).txt"
declare -a EXTRA_PRIVATE_KEYS=()
declare -a EXTRA_PUBLIC_KEYS=()
CONTROL_DIR="/tmp/ocw-cm-${USER:-user}"
mkdir -p "$CONTROL_DIR"
chmod 700 "$CONTROL_DIR" >/dev/null 2>&1 || true
CONTROL_PATH="$CONTROL_DIR/%C"

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
  -o ConnectionAttempts=3
  -o ConnectTimeout=20
  -o ServerAliveInterval=20
  -o ServerAliveCountMax=3
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$CONTROL_PATH"
)
SSH_OPTS_NO_MUX=("${SSH_OPTS[@]}" -o ControlMaster=no -o ControlPath=none)
PUBKEY_ONLY_OPTS=(
  -o PreferredAuthentications=publickey
  -o PasswordAuthentication=no
  -o KbdInteractiveAuthentication=no
)
ROOT_EXEC_OPTS=("${SSH_OPTS[@]}")
ROOT_EXEC_OPTS_NO_MUX=("${ROOT_EXEC_OPTS[@]}" -o ControlMaster=no -o ControlPath=none)
SSH_RETRY_ATTEMPTS=3
SSH_RETRY_BASE_DELAY=4

can_login_key_batch() {
  ssh "${SSH_OPTS[@]}" "${PUBKEY_ONLY_OPTS[@]}" -o BatchMode=yes "$ROOT_CONN" 'echo key-auth-ok' >/dev/null 2>&1
}

can_login_key_interactive() {
  ssh "${SSH_OPTS[@]}" "${PUBKEY_ONLY_OPTS[@]}" "$ROOT_CONN" 'echo key-auth-ok' >/dev/null
}

ssh_root_retry() {
  local remote_cmd="$1"
  local attempt rc delay
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if ssh "${ROOT_EXEC_OPTS_NO_MUX[@]}" -o BatchMode=yes "$ROOT_CONN" "$remote_cmd"; then
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    warn "SSH to ${ROOT_CONN} failed (exit ${rc}), retry ${attempt}/${SSH_RETRY_ATTEMPTS} in ${delay}s..."
    sleep "$delay"
  done
  return 1
}

ssh_root_capture_retry() {
  local remote_cmd="$1"
  local attempt rc delay output=""
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if output="$(ssh "${ROOT_EXEC_OPTS_NO_MUX[@]}" -o BatchMode=yes "$ROOT_CONN" "$remote_cmd" 2>/dev/null)"; then
      printf '%s' "$output"
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    warn "SSH to ${ROOT_CONN} failed (exit ${rc}), retry ${attempt}/${SSH_RETRY_ATTEMPTS} in ${delay}s..." >&2
    sleep "$delay"
  done
  return 1
}

ssh_openclaw_retry() {
  local remote_cmd="$1"
  local attempt rc delay
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if ssh "${SSH_OPTS_NO_MUX[@]}" -o BatchMode=yes "$OPENCLAW_CONN" "$remote_cmd"; then
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    warn "SSH to ${OPENCLAW_CONN} failed (exit ${rc}), retry ${attempt}/${SSH_RETRY_ATTEMPTS} in ${delay}s..."
    sleep "$delay"
  done
  return 1
}

ssh_openclaw_capture_retry() {
  local remote_cmd="$1"
  local attempt rc delay output=""
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if output="$(ssh "${SSH_OPTS_NO_MUX[@]}" -o BatchMode=yes "$OPENCLAW_CONN" "$remote_cmd" 2>/dev/null)"; then
      printf '%s' "$output"
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    warn "SSH to ${OPENCLAW_CONN} failed (exit ${rc}), retry ${attempt}/${SSH_RETRY_ATTEMPTS} in ${delay}s..." >&2
    sleep "$delay"
  done
  return 1
}

ssh_openclaw_pipe_retry() {
  local stdin_file="$1"
  local remote_cmd="$2"
  local attempt rc delay
  for ((attempt = 1; attempt <= SSH_RETRY_ATTEMPTS; attempt++)); do
    if ssh "${SSH_OPTS_NO_MUX[@]}" -o BatchMode=yes "$OPENCLAW_CONN" "$remote_cmd" < "$stdin_file"; then
      return 0
    fi
    rc=$?
    if ((attempt >= SSH_RETRY_ATTEMPTS || rc != 255)); then
      return "$rc"
    fi
    delay=$((attempt * SSH_RETRY_BASE_DELAY))
    warn "SSH to ${OPENCLAW_CONN} failed while streaming input (exit ${rc}), retry ${attempt}/${SSH_RETRY_ATTEMPTS} in ${delay}s..."
    sleep "$delay"
  done
  return 1
}

cleanup() {
  ssh "${SSH_OPTS[@]}" -O exit "$ROOT_CONN" >/dev/null 2>&1 || true
  ssh "${SSH_OPTS[@]}" -O exit "$OPENCLAW_CONN" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ ! -f "$SSH_KEY" ]]; then
  info "No SSH key found at $SSH_KEY; generating new ed25519 key"
  warn "Creating key with empty passphrase for quickest first-time setup."
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -q -t ed25519 -C "openclaw-vps" -f "$SSH_KEY" -N ""
else
  if ! ssh-keygen -y -P "" -f "$SSH_KEY" >/dev/null 2>&1; then
    warn "SSH key $SSH_KEY is passphrase-protected (recommended by security guides)."
    warn "If key auth check fails, run: ssh-add \"$SSH_KEY\""
  fi
fi

[[ -f "$PUB_KEY" ]] || fail "Public key not found: $PUB_KEY"

generate_extra_keys() {
  local idx key_path pub_path
  ((EXTRA_KEYS > 0)) || return 0

  mkdir -p "$EXTRA_KEY_DIR"
  warn "Generating ${EXTRA_KEYS} extra SSH key(s) without passphrase for quick mobile import."
  : > "$EXTRA_KEYS_MANIFEST"
  chmod 600 "$EXTRA_KEYS_MANIFEST" || true

  {
    printf 'OpenClaw VPS extra SSH keys\n'
    printf 'Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'Host: %s\n\n' "$HOST"
  } >> "$EXTRA_KEYS_MANIFEST"

  for ((idx = 1; idx <= EXTRA_KEYS; idx++)); do
    key_path="${EXTRA_KEY_DIR}/${EXTRA_KEY_PREFIX}_${idx}_ed25519"
    pub_path="${key_path}.pub"

    if [[ ! -f "$key_path" ]]; then
      info "Generating extra key: $key_path"
      ssh-keygen -q -t ed25519 -C "openclaw-vps-extra-${idx}" -f "$key_path" -N ""
    else
      warn "Extra key already exists, reusing: $key_path"
    fi

    [[ -f "$pub_path" ]] || fail "Extra public key not found: $pub_path"
    EXTRA_PRIVATE_KEYS+=("$key_path")
    EXTRA_PUBLIC_KEYS+=("$pub_path")

    {
      printf 'Key %s\n' "$idx"
      printf 'Private: %s\n' "$key_path"
      printf 'Public:  %s\n' "$pub_path"
      printf 'Use in Termius: import private key, then connect as %s@%s (port %s).\n\n' "$OPENCLAW_USER" "$HOST" "$SSH_PORT"
    } >> "$EXTRA_KEYS_MANIFEST"
  done
}

authorize_extra_keys() {
  local pub_path
  ((EXTRA_KEYS > 0)) || return 0

  for pub_path in "${EXTRA_PUBLIC_KEYS[@]}"; do
    if ! ssh_openclaw_pipe_retry "$pub_path" "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"; then
      fail "Failed to add extra key on ${OPENCLAW_CONN}. Retry manually: cat \"$pub_path\" | ssh -i \"$SSH_KEY\" -p \"$SSH_PORT\" \"$OPENCLAW_CONN\" \"umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys\""
    fi
  done
}

print_extra_keys_summary() {
  local idx priv_path pub_path fp line
  ((EXTRA_KEYS > 0)) || return 0

  printf '\n'
  warn "================ EXTRA DEVICE SSH KEYS ================"
  warn "============ ДОПОЛНИТЕЛЬНЫЕ SSH-КЛЮЧИ ================"
  warn "Copy and store private keys safely."
  warn "Скопируйте private keys и сохраните в безопасном месте."

  for idx in "${!EXTRA_PRIVATE_KEYS[@]}"; do
    priv_path="${EXTRA_PRIVATE_KEYS[$idx]}"
    pub_path="${EXTRA_PUBLIC_KEYS[$idx]}"
    fp="$(ssh-keygen -lf "$pub_path" 2>/dev/null || true)"
    printf 'Key %s / Ключ %s\n' "$((idx + 1))" "$((idx + 1))"
    printf 'Private path / Путь private key: %s\n' "$priv_path"
    if [[ -n "$fp" ]]; then
      printf 'Fingerprint / Отпечаток: %s\n' "$fp"
    fi
    printf 'Phone import (Termius) / Ключ для телефона (Termius): %s\n' "$priv_path"
    printf 'Public key / Публичный ключ:\n'
    cat "$pub_path"
    printf '\n'
    if command -v pbcopy >/dev/null 2>&1; then
      printf 'macOS copy command / Команда копирования:\n'
      printf '   pbcopy < %s\n' "$priv_path"
    fi
    if [[ "$SHOW_EXTRA_PRIVATE_KEYS" == "yes" ]]; then
      warn "PRIVATE KEY TEXT (FOR MANUAL IMPORT) / PRIVATE KEY ТЕКСТ (ДЛЯ РУЧНОГО ИМПОРТА):"
      warn "Treat as secret. It is also written into this run log."
      warn "Секретный ключ. Он также попадет в лог этого запуска."
      while IFS= read -r line || [[ -n "$line" ]]; do
        printf '%b%s%b\n' "$C_ERR" "$line" "$C_RESET"
      done < "$priv_path"
    fi
    printf '\n'
  done

  info "Manifest file / Файл-памятка: $EXTRA_KEYS_MANIFEST"
  warn "Anyone with a private key can SSH into your VPS."
  warn "Любой, у кого есть private key, сможет зайти на ваш VPS."
}

copy_pubkey_to_root() {
  info "Copying public key to $ROOT_CONN"
  warn "Now enter VPS login password from provider panel for ${ROOT_CONN}."
  warn "Do NOT enter SSH key passphrase here."

  if command -v ssh-copy-id >/dev/null 2>&1; then
    if ! ssh-copy-id \
      -o PreferredAuthentications=password \
      -o PubkeyAuthentication=no \
      -o KbdInteractiveAuthentication=yes \
      -o IdentitiesOnly=yes \
      -i "$PUB_KEY" -p "$SSH_PORT" "$ROOT_CONN"; then
      fail "Authentication failed for ${ROOT_CONN}. Use VPS password from provider panel for this SSH user. If initial SSH user is not root, rerun with --initial-user <user>."
    fi
    return
  fi

  warn "ssh-copy-id is not installed; using manual key append fallback"
  if ! cat "$PUB_KEY" | ssh -p "$SSH_PORT" -o StrictHostKeyChecking=accept-new "$ROOT_CONN" \
    "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"; then
    fail "Authentication failed for ${ROOT_CONN}. Use VPS password from provider panel for this SSH user. If initial SSH user is not root, rerun with --initial-user <user>."
  fi
}

step 1 10 "Проверка SSH-ключевого доступа initial user"
KEY_AUTH_CONFIRMED="no"
if can_login_key_batch; then
  KEY_AUTH_CONFIRMED="yes"
else
  copy_pubkey_to_root
fi

if [[ "$KEY_AUTH_CONFIRMED" != "yes" ]] && can_login_key_batch; then
  KEY_AUTH_CONFIRMED="yes"
fi

if [[ "$KEY_AUTH_CONFIRMED" != "yes" ]]; then
  warn "Batch key check failed. Trying interactive key-only login check."
  if can_login_key_interactive; then
    KEY_AUTH_CONFIRMED="yes"
  fi
fi

if [[ "$KEY_AUTH_CONFIRMED" != "yes" ]]; then
  if [[ "$HARDEN_SSH" == "yes" ]]; then
    fail "Cannot confirm SSH key login for ${ROOT_CONN}. Refusing to continue while SSH hardening is enabled (to avoid lockout)."
  fi
  warn "Key auth is not confirmed, but SSH hardening is disabled (--no-harden-ssh), continuing."
fi

step 2 10 "Подготовка дополнительных SSH-ключей (опционально)"
if ((EXTRA_KEYS > 0)); then
  generate_extra_keys
else
  info "No extra keys requested (--extra-keys 0)."
fi

REMOTE_UID="$(ssh_root_capture_retry "id -u" | tr -d '[:space:]')"
[[ "$REMOTE_UID" =~ ^[0-9]+$ ]] || fail "Failed to detect remote uid for ${ROOT_CONN}"
REMOTE_BOOT_CMD="OPENCLAW_USER='$OPENCLAW_USER' HARDEN_SSH='$HARDEN_SSH' UPGRADE_SYSTEM='$UPGRADE_SYSTEM' SSH_PORT='$SSH_PORT' bash -s"
if [[ "$REMOTE_UID" != "0" ]]; then
  info "Initial SSH user is non-root (uid=${REMOTE_UID}); checking passwordless sudo"
  if ! ssh_root_retry "sudo -n true" >/dev/null 2>&1; then
    fail "Initial SSH user ${ROOT_CONN} requires interactive sudo password. Use root for bootstrap or configure passwordless sudo."
  fi
  REMOTE_BOOT_CMD="sudo -n OPENCLAW_USER='$OPENCLAW_USER' HARDEN_SSH='$HARDEN_SSH' UPGRADE_SYSTEM='$UPGRADE_SYSTEM' SSH_PORT='$SSH_PORT' bash -s"
fi

run_remote_bootstrap_once() {
ssh "${ROOT_EXEC_OPTS_NO_MUX[@]}" "$ROOT_CONN" "$REMOTE_BOOT_CMD" <<'REMOTE'
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_HOME="/home/${OPENCLAW_USER}"
HARDEN_SSH="${HARDEN_SSH:-yes}"
UPGRADE_SYSTEM="${UPGRADE_SYSTEM:-yes}"
SSH_PORT="${SSH_PORT:-22}"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  if [[ "$UPGRADE_SYSTEM" == "yes" ]]; then
    apt-get upgrade -y
  fi
  apt-get install -y curl ca-certificates sudo ufw fail2ban unattended-upgrades
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
AUTO_UPGRADES
  systemctl enable unattended-upgrades >/dev/null 2>&1 || true
  systemctl restart unattended-upgrades >/dev/null 2>&1 || true
fi

if [[ -f /var/run/reboot-required ]]; then
  echo "[WARN] Server reboot is required after package upgrades." >&2
fi

if command -v ufw >/dev/null 2>&1; then
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"
  ufw --force enable
fi

if command -v fail2ban-client >/dev/null 2>&1; then
  install -d -m 755 /etc/fail2ban/jail.d
  cat >/etc/fail2ban/jail.d/openclaw-sshd.local <<FAIL2BAN_JAIL
[sshd]
enabled = true
port = ${SSH_PORT}
maxretry = 5
findtime = 10m
bantime = 1h
FAIL2BAN_JAIL
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban >/dev/null 2>&1 || systemctl start fail2ban >/dev/null 2>&1 || true
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

OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
loginctl enable-linger "$OPENCLAW_USER" || true
loginctl start-user "$OPENCLAW_USER" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do
  if [[ -S "/run/user/${OPENCLAW_UID}/bus" ]]; then
    break
  fi
  sleep 1
  loginctl start-user "$OPENCLAW_USER" >/dev/null 2>&1 || true
done

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

  install -d -m 755 /run/sshd
  if command -v sshd >/dev/null 2>&1 && ! sshd -t; then
    echo "[ERROR] sshd configuration validation failed; refusing to reload SSH service." >&2
    exit 1
  fi

  if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
    systemctl reload ssh || systemctl restart ssh
  elif systemctl list-unit-files 2>/dev/null | grep -q '^sshd.service'; then
    systemctl reload sshd || systemctl restart sshd
  fi
fi

sudo -iu "$OPENCLAW_USER" env \
  XDG_RUNTIME_DIR="/run/user/${OPENCLAW_UID}" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${OPENCLAW_UID}/bus" \
  bash <<'SU_SCRIPT'
set -euo pipefail

umask 077

install_or_update_openclaw() {
  local occ="$HOME/.openclaw/bin/openclaw"
  local npm_bin=""
  local current=""
  local latest=""
  local install_attempt=""

  if [[ -x "$occ" ]]; then
    current="$("$occ" --version 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
    npm_bin="$(ls -1 "$HOME"/.openclaw/tools/node-v*/bin/npm 2>/dev/null | head -n1 || true)"
    if [[ -x "$npm_bin" ]]; then
      latest="$("$npm_bin" view openclaw version 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
    fi
  fi

  if [[ -x "$occ" && -n "$current" && -n "$latest" && "$current" == "$latest" ]]; then
    echo "OpenClaw already up-to-date (${current}); skipping reinstall."
    return 0
  fi

  if [[ -x "$occ" && -n "$current" && -z "$latest" ]]; then
    echo "OpenClaw already installed (${current}); latest version check unavailable, skipping reinstall."
    return 0
  fi

  if [[ -x "$occ" && -n "$current" && -n "$latest" && "$current" != "$latest" ]]; then
    echo "Updating OpenClaw ${current} -> ${latest}..."
  else
    echo "Installing OpenClaw (latest)..."
  fi

  for install_attempt in 1 2; do
    if curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh | bash; then
      return 0
    fi
    if [[ "$install_attempt" -ge 2 ]]; then
      return 1
    fi
    echo "[WARN] OpenClaw install script failed; retrying once in 3s..." >&2
    sleep 3
  done
}

install_or_update_openclaw

if ! grep -q '"$HOME/.openclaw/bin"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.openclaw/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.openclaw/bin:$PATH"
OCC="$HOME/.openclaw/bin/openclaw"

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

$OCC config set gateway.mode local
$OCC config set gateway.bind loopback

mkdir -p "$HOME/.openclaw/credentials" "$HOME/.openclaw/agents/main/sessions"
chmod 700 "$HOME/.openclaw" || true
chmod 700 "$HOME/.openclaw/credentials" || true
chmod 700 "$HOME/.openclaw/agents" "$HOME/.openclaw/agents/main" "$HOME/.openclaw/agents/main/sessions" || true

$OCC doctor --fix --yes --non-interactive || true

if ! $OCC gateway install --force; then
  echo "[WARN] gateway install failed on first try; retrying..." >&2
  sleep 2
  $OCC gateway install --force || true
fi
$OCC gateway restart || $OCC gateway start || true

TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  $OCC doctor --generate-gateway-token >/dev/null 2>&1 || true
  $OCC doctor --fix --yes --non-interactive || true
fi
TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
sync_gateway_service_token "$TOKEN"

if $OCC status 2>&1 | grep -q 'device token mismatch'; then
  $OCC gateway stop || true
  rm -f "$HOME/.openclaw/identity/device.json" "$HOME/.openclaw/identity/device-auth.json"
  rm -f "$HOME/.openclaw/devices/paired.json" "$HOME/.openclaw/devices/pending.json"
  rm -f "$HOME/.openclaw/nodes/paired.json" "$HOME/.openclaw/nodes/pending.json"
  $OCC doctor --fix --yes --non-interactive || true
  $OCC gateway install --force
  $OCC gateway start || true
fi

TOKEN="$($OCC config get gateway.auth.token 2>/dev/null || true)"
sync_gateway_service_token "$TOKEN"
$OCC gateway install --force || true
$OCC gateway restart || $OCC gateway start || true

chmod 700 "$HOME/.openclaw" "$HOME/.openclaw/credentials" || true
chmod 700 "$HOME/.openclaw/agents" "$HOME/.openclaw/agents/main" "$HOME/.openclaw/agents/main/sessions" || true
SU_SCRIPT
REMOTE
}

step 3 10 "Удалённая подготовка сервера и установка OpenClaw"
REMOTE_ATTEMPT=1
REMOTE_ATTEMPT_MAX=2
while true; do
  if run_remote_bootstrap_once; then
    break
  fi
  REMOTE_RC=$?
  if (( REMOTE_ATTEMPT >= REMOTE_ATTEMPT_MAX )); then
    fail "Remote bootstrap failed after ${REMOTE_ATTEMPT} attempt(s) with exit ${REMOTE_RC}."
  fi
  if [[ "$REMOTE_RC" != "255" ]]; then
    fail "Remote bootstrap failed with non-transient exit ${REMOTE_RC}. Retry was skipped by policy."
  fi
  warn "SSH connection dropped during remote bootstrap (exit 255). Retrying once after short wait..."
  sleep 6
  ((REMOTE_ATTEMPT++))
done

step 4 10 "Дополнительные SSH-ключи для устройств"
if ((EXTRA_KEYS > 0)); then
  authorize_extra_keys
  ok "Added ${EXTRA_KEYS} extra key(s) for ${OPENCLAW_USER}@${HOST}"
  print_extra_keys_summary
else
  info "No extra keys to add."
fi

step 5 10 "Проверка linger для user-systemd"
ssh_root_retry "loginctl show-user $OPENCLAW_USER -p Linger"

step 6 10 "Проверка статуса OpenClaw gateway"
ssh_openclaw_retry "export XDG_RUNTIME_DIR=/run/user/\$(id -u); export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus; ~/.openclaw/bin/openclaw gateway status || true; ~/.openclaw/bin/openclaw status || true"

step 7 10 "Проверка прав доступа на ~/.openclaw"
ssh_openclaw_retry "stat -c '%a %n' ~/.openclaw ~/.openclaw/credentials ~/.openclaw/agents/main/sessions"

step 8 10 "Проверка host hardening (UFW/Fail2ban/Auto-updates)"
ssh_root_retry "echo 'UFW:'; ufw status verbose | sed -n '1,12p'; echo; echo 'Fail2ban:'; systemctl is-enabled fail2ban 2>/dev/null || true; systemctl is-active fail2ban 2>/dev/null || true; fail2ban-client status sshd 2>/dev/null || true; echo; echo 'Unattended upgrades:'; systemctl is-enabled unattended-upgrades 2>/dev/null || true"

step 9 10 "Проверка отсутствия hardened-ограничений в активном конфиге"
ssh_openclaw_retry "grep -niE 'squid|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|exec-approvals\\.json|tools\\.yaml|allowlist\\.txt|openclaw-squid|openclaw-litellm' ~/.openclaw/openclaw.json ~/.config/systemd/user/openclaw-gateway.service 2>/dev/null || true"

step 10 10 "Получение gateway token и завершение"
GATEWAY_TOKEN="$(
  ssh_openclaw_capture_retry \
    "export XDG_RUNTIME_DIR=/run/user/\$(id -u); export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus; ~/.openclaw/bin/openclaw config get gateway.auth.token || true" \
    | tr -d '\r' | tail -n1
)"
if [[ -n "$GATEWAY_TOKEN" && "$GATEWAY_TOKEN" != "null" ]]; then
  ok "Gateway token / Токен gateway:"
  printf '%s\n' "$GATEWAY_TOKEN"
  ok "Control UI quick URL / Быстрая ссылка Control UI:"
  printf 'http://127.0.0.1:18789/#token=%s\n' "$GATEWAY_TOKEN"
  warn "Save this token now. You will need it in Control UI if asked."
  warn "Сохраните токен сейчас. Он нужен в Control UI при запросе."
  warn "If you see disconnect, open private/incognito and use URL above."
  warn "Если видите disconnect, откройте private/incognito и используйте ссылку выше."
else
  warn "Gateway token not available in output right now."
  warn "Токен gateway не удалось получить в текущем выводе."
fi

ok "VPS подготовлен и OpenClaw запущен."
printf '\n'
printf 'Log file: %s\n' "$LOG_FILE"
if ((EXTRA_KEYS > 0)); then
  printf 'Extra keys manifest: %s\n' "$EXTRA_KEYS_MANIFEST"
fi
printf 'Next: create local tunnel from your Mac/Linux terminal:\n'
printf 'ssh -i %s -N -L 18789:127.0.0.1:18789 %s\n' "$SSH_KEY" "$OPENCLAW_CONN"
printf 'Then open: http://127.0.0.1:18789\n\n'
printf 'When ready to connect providers/channels on VPS:\nopenclaw onboard\n'
