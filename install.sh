#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

ORIG_STDOUT_IS_TTY=0
if [[ -t 1 ]]; then
  ORIG_STDOUT_IS_TTY=1
fi

LOG_DIR="${TMPDIR:-/tmp}"
LOG_FILE="${LOG_DIR%/}/openclaw-vps-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] install.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: curl -fsSL <raw-install-url> | bash -s -- --host <ip_or_host> [options]

Required:
  --host <host>              VPS IP or hostname

Options:
  --repo-url <url>           Git repo URL (default: https://github.com/BABAK312/openclaw-vps-quickstart.git)
  --dir <path>               Local directory for repo (default: current quickstart dir or ~/openclaw-vps-quickstart)
  --initial-user <user>      Initial SSH user for first login (default: root)
  --root-user <user>         Initial privileged SSH user (default: root)
  --openclaw-user <user>     OpenClaw service user (default: openclaw)
  --ssh-key <path>           SSH key path (default: ~/.ssh/openclaw_vps_ed25519)
  --ssh-port <port>          SSH port (default: 22)
  --ssh-alias <name>         Add/update local SSH alias in ~/.ssh/config (example: openclaw-1)
  --extra-keys <count>       Generate and authorize extra SSH keys (default: 0)
  --show-extra-private-keys  Print extra private keys to terminal output (dangerous: also saved to log)
  --no-harden-ssh            Do not change sshd auth settings on VPS
  --no-upgrade               Skip apt upgrade on VPS
  --no-auto-reboot           Do not auto-reboot when /var/run/reboot-required is present
  --reboot-wait-timeout <s>  Auto-reboot wait timeout in seconds (default: 420)
  --skip-verify              Skip verify --repair step
  -h, --help                 Show help
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
  printf '%b\n' "${C_TITLE} OpenClaw VPS Quickstart Installer${C_RESET}"
  printf '%b\n' "${C_TITLE} Версия: локальный запуск${C_RESET}"
  printf '%b\n' "${C_TITLE}========================================${C_RESET}"
}

info() { printf '%b[INFO]%b %s\n' "$C_INFO" "$C_RESET" "$*"; }
warn() { printf '%b[WARN]%b %s\n' "$C_WARN" "$C_RESET" "$*"; }
fail() { printf '%b[ERROR]%b %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }
step() { printf '%b[STEP %s/%s]%b %s\n' "$C_STEP" "$1" "$2" "$C_RESET" "$3"; }
ok() { printf '%b[OK]%b %s\n' "$C_OK" "$C_RESET" "$*"; }

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

validate_alias() {
  local alias_name="$1"
  [[ "$alias_name" != -* ]] || fail "Invalid --ssh-alias value: $alias_name"
  [[ "$alias_name" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Invalid --ssh-alias value: $alias_name"
}

wait_for_ssh_after_reboot() {
  local user_name="$1"
  local before_boot_id="$2"
  local deadline boot_id
  local seen_disconnect=0

  deadline=$((SECONDS + REBOOT_WAIT_TIMEOUT))
  while ((SECONDS < deadline)); do
    # During reboot SSH will fail transiently; treat that as expected signal, not fatal error.
    boot_id="$(
      ssh "${REBOOT_WAIT_OPTS[@]}" "${user_name}@${HOST}" "cat /proc/sys/kernel/random/boot_id" 2>/dev/null \
        || printf '__SSH_REBOOT_PENDING__'
    )"
    if [[ "$boot_id" != "__SSH_REBOOT_PENDING__" ]]; then
      boot_id="${boot_id//$'\r'/}"
      boot_id="${boot_id//$'\n'/}"
      if [[ -n "$before_boot_id" ]]; then
        if [[ "$boot_id" != "$before_boot_id" ]]; then
          return 0
        fi
      elif ((seen_disconnect)); then
        return 0
      fi
    else
      seen_disconnect=1
    fi
    sleep 3
  done
  return 1
}

setup_ssh_alias() {
  local alias_name="$1"
  local ssh_dir ssh_cfg tmp_cfg start_marker end_marker
  local host_line_regex

  ssh_dir="$HOME/.ssh"
  ssh_cfg="$ssh_dir/config"
  start_marker="# >>> openclaw-vps-quickstart alias ${alias_name} >>>"
  end_marker="# <<< openclaw-vps-quickstart alias ${alias_name} <<<"
  host_line_regex="^[[:space:]]*Host[[:space:]]+${alias_name//./\\.}[[:space:]]*$"

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$ssh_cfg"
  chmod 600 "$ssh_cfg"

  if grep -Eq "$host_line_regex" "$ssh_cfg" && ! grep -Fq "$start_marker" "$ssh_cfg"; then
    fail "Found existing unmanaged SSH alias '${alias_name}' in ~/.ssh/config. Choose another alias or remove existing Host block."
  fi

  tmp_cfg="$(mktemp)"
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$ssh_cfg" > "$tmp_cfg"

  {
    printf '\n%s\n' "$start_marker"
    printf 'Host %s\n' "$alias_name"
    printf '  HostName %s\n' "$HOST"
    printf '  User %s\n' "$OPENCLAW_USER"
    printf '  Port %s\n' "$SSH_PORT"
    printf '  IdentityFile %s\n' "$SSH_KEY"
    printf '  IdentitiesOnly yes\n'
    printf '%s\n' "$end_marker"
  } >> "$tmp_cfg"

  mv "$tmp_cfg" "$ssh_cfg"
  chmod 600 "$ssh_cfg"
}

HOST=""
REPO_URL="https://github.com/BABAK312/openclaw-vps-quickstart.git"
DEFAULT_TARGET_DIR="$HOME/openclaw-vps-quickstart"
if [[ -f "$PWD/install.sh" && -f "$PWD/bootstrap.sh" && -f "$PWD/verify.sh" && -d "$PWD/scripts" ]]; then
  TARGET_DIR="$PWD"
else
  TARGET_DIR="$DEFAULT_TARGET_DIR"
fi
ROOT_USER="root"
OPENCLAW_USER="openclaw"
SSH_KEY="$HOME/.ssh/openclaw_vps_ed25519"
SSH_PORT="22"
HARDEN_SSH="yes"
UPGRADE_SYSTEM="yes"
AUTO_REBOOT="yes"
REBOOT_WAIT_TIMEOUT="420"
SKIP_VERIFY="no"
SSH_ALIAS=""
EXTRA_KEYS="0"
SHOW_EXTRA_PRIVATE_KEYS="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) require_value "$1" "${2-}"; HOST="$2"; shift 2 ;;
    --repo-url) require_value "$1" "${2-}"; REPO_URL="$2"; shift 2 ;;
    --dir) require_value "$1" "${2-}"; TARGET_DIR="$2"; shift 2 ;;
    --initial-user) require_value "$1" "${2-}"; ROOT_USER="$2"; shift 2 ;;
    --root-user) require_value "$1" "${2-}"; ROOT_USER="$2"; shift 2 ;;
    --openclaw-user) require_value "$1" "${2-}"; OPENCLAW_USER="$2"; shift 2 ;;
    --ssh-key) require_value "$1" "${2-}"; SSH_KEY="${2/#\~/$HOME}"; shift 2 ;;
    --ssh-port) require_value "$1" "${2-}"; SSH_PORT="$2"; shift 2 ;;
    --ssh-alias) require_value "$1" "${2-}"; SSH_ALIAS="$2"; shift 2 ;;
    --extra-keys) require_value "$1" "${2-}"; EXTRA_KEYS="$2"; shift 2 ;;
    --show-extra-private-keys) SHOW_EXTRA_PRIVATE_KEYS="yes"; shift 1 ;;
    --no-harden-ssh) HARDEN_SSH="no"; shift 1 ;;
    --no-upgrade) UPGRADE_SYSTEM="no"; shift 1 ;;
    --no-auto-reboot) AUTO_REBOOT="no"; shift 1 ;;
    --reboot-wait-timeout) require_value "$1" "${2-}"; REBOOT_WAIT_TIMEOUT="$2"; shift 2 ;;
    --skip-verify) SKIP_VERIFY="yes"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

validate_host "$HOST"
validate_user "$ROOT_USER" "--initial-user/--root-user"
validate_user "$OPENCLAW_USER" "--openclaw-user"
validate_port "$SSH_PORT"
validate_count "$EXTRA_KEYS" "--extra-keys"
validate_count "$REBOOT_WAIT_TIMEOUT" "--reboot-wait-timeout"
((REBOOT_WAIT_TIMEOUT >= 30 && REBOOT_WAIT_TIMEOUT <= 3600)) || fail "Invalid --reboot-wait-timeout value: $REBOOT_WAIT_TIMEOUT (expected 30..3600)"
if [[ -n "$SSH_ALIAS" ]]; then
  validate_alias "$SSH_ALIAS"
fi
[[ -z "${SSH_CONNECTION:-}" ]] || fail "Run this from local terminal, not from inside SSH session."

print_banner
info "Лог установки: $LOG_FILE"

step 1 6 "Проверка локальных зависимостей"
command -v bash >/dev/null 2>&1 || fail "bash is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

REMOTE_CHECK_OPTS=(
  -p "$SSH_PORT"
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=20
)
REBOOT_WAIT_OPTS=(
  -p "$SSH_PORT"
  -i "$SSH_KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectionAttempts=1
  -o ConnectTimeout=5
)

# Reinstalled VPS on same IP often causes known_hosts mismatch; refresh entry.
step 2 6 "Обновление known_hosts для целевого сервера"
ssh-keygen -R "$HOST" >/dev/null 2>&1 || true
if [[ "$SSH_PORT" != "22" ]]; then
  ssh-keygen -R "[$HOST]:$SSH_PORT" >/dev/null 2>&1 || true
fi

download_repo_without_git() {
  local url="$1"
  local target="$2"
  local owner repo tarball tmpdir

  if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/.]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    fail "git is not installed and repo URL is not a supported GitHub HTTPS URL: $url"
  fi

  tarball="https://github.com/${owner}/${repo}/archive/refs/heads/main.tar.gz"
  tmpdir="$(mktemp -d)"

  info "git not found; downloading source archive $tarball"
  curl -fsSL "$tarball" -o "$tmpdir/repo.tar.gz"
  tar -xzf "$tmpdir/repo.tar.gz" -C "$tmpdir"

  if [[ ! -d "$tmpdir/${repo}-main" ]]; then
    rm -rf "$tmpdir"
    fail "Unexpected archive layout while downloading $tarball"
  fi

  mv "$tmpdir/${repo}-main" "$target"
  rm -rf "$tmpdir"
}

if [[ -d "$TARGET_DIR" && ! -d "$TARGET_DIR/.git" ]]; then
  step 3 6 "Используем существующую рабочую папку"
  if [[ -f "$TARGET_DIR/bootstrap.sh" && -f "$TARGET_DIR/verify.sh" ]]; then
    warn "Using existing non-git directory: $TARGET_DIR"
  else
    fail "Directory exists but does not look like quickstart repo: $TARGET_DIR"
  fi
elif [[ -d "$TARGET_DIR/.git" ]]; then
  step 3 6 "Обновляем локальный репозиторий quickstart"
  if command -v git >/dev/null 2>&1; then
    info "Updating existing repo in $TARGET_DIR"
    if ! git -C "$TARGET_DIR" pull --ff-only; then
      fail "Failed to update existing repo in $TARGET_DIR. If you changed files manually, use a clean folder via --dir <path>."
    fi
  else
    warn "git not found; using existing clone as-is: $TARGET_DIR"
  fi
else
  step 3 6 "Скачиваем quickstart репозиторий"
  if command -v git >/dev/null 2>&1; then
    info "Cloning $REPO_URL -> $TARGET_DIR"
    git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
  else
    download_repo_without_git "$REPO_URL" "$TARGET_DIR"
  fi
fi

chmod +x "$TARGET_DIR/bootstrap.sh" "$TARGET_DIR/verify.sh" "$TARGET_DIR"/scripts/*.sh || true

BOOT_ARGS=(
  --host "$HOST"
  --initial-user "$ROOT_USER"
  --openclaw-user "$OPENCLAW_USER"
  --ssh-key "$SSH_KEY"
  --ssh-port "$SSH_PORT"
)

if [[ "$HARDEN_SSH" == "no" ]]; then
  BOOT_ARGS+=(--no-harden-ssh)
fi
if [[ "$UPGRADE_SYSTEM" == "no" ]]; then
  BOOT_ARGS+=(--no-upgrade)
fi
if [[ "$EXTRA_KEYS" != "0" ]]; then
  BOOT_ARGS+=(--extra-keys "$EXTRA_KEYS")
fi
if [[ "$SHOW_EXTRA_PRIVATE_KEYS" == "yes" ]]; then
  BOOT_ARGS+=(--show-extra-private-keys)
fi

step 4 6 "Запуск bootstrap на VPS"
info "Running bootstrap"
info "When prompted by ssh-copy-id, enter VPS password for initial SSH user from provider panel."
bash "$TARGET_DIR/bootstrap.sh" "${BOOT_ARGS[@]}"

if [[ "$SKIP_VERIFY" != "yes" ]]; then
  step 5 6 "Пост-проверка и авто-ремонт verify --repair"
  info "Running verify --repair"
  bash "$TARGET_DIR/verify.sh" \
    --host "$HOST" \
    --initial-user "$ROOT_USER" \
    --openclaw-user "$OPENCLAW_USER" \
    --ssh-key "$SSH_KEY" \
    --ssh-port "$SSH_PORT" \
    --repair
fi

step 6 6 "Финальные рекомендации"
if ssh "${REMOTE_CHECK_OPTS[@]}" "${OPENCLAW_USER}@${HOST}" "test -f /var/run/reboot-required" >/dev/null 2>&1; then
  warn "VPS reports reboot-required after system package updates."
  if [[ "$AUTO_REBOOT" == "yes" ]]; then
    info "Auto-reboot is enabled. Rebooting VPS now..."
    BOOT_ID_BEFORE="$(
      ssh "${REMOTE_CHECK_OPTS[@]}" "${ROOT_USER}@${HOST}" "cat /proc/sys/kernel/random/boot_id" 2>/dev/null \
        | tr -d '\r' | tr -d '\n'
    )"
    if ! ssh "${REMOTE_CHECK_OPTS[@]}" "${ROOT_USER}@${HOST}" "sudo reboot || reboot" >/dev/null 2>&1; then
      warn "Reboot command returned non-zero (expected when SSH disconnects during reboot)."
    fi
    info "Waiting for server to restart and SSH to return (timeout: ${REBOOT_WAIT_TIMEOUT}s)..."
    if ! wait_for_ssh_after_reboot "$ROOT_USER" "$BOOT_ID_BEFORE"; then
      fail "Server did not become reachable via SSH within ${REBOOT_WAIT_TIMEOUT}s after auto-reboot."
    fi
    ok "Server returned after reboot."
    if [[ "$SKIP_VERIFY" != "yes" ]]; then
      info "Running verify after reboot"
      bash "$TARGET_DIR/verify.sh" \
        --host "$HOST" \
        --initial-user "$ROOT_USER" \
        --openclaw-user "$OPENCLAW_USER" \
        --ssh-key "$SSH_KEY" \
        --ssh-port "$SSH_PORT"
    fi
  else
    warn "Run once to finalize kernel/system updates:"
    printf '   ssh -i %s -p %s %s@%s "sudo reboot || reboot"\n' "$SSH_KEY" "$SSH_PORT" "$ROOT_USER" "$HOST"
  fi
fi

if [[ -n "$SSH_ALIAS" ]]; then
  setup_ssh_alias "$SSH_ALIAS"
  ok "SSH alias configured: $SSH_ALIAS"
fi

printf '\nDone.\n'
ok "Установка завершена."
printf '1) Open tunnel:\n'
if [[ -n "$SSH_ALIAS" ]]; then
  printf '   ssh -N -L 18789:127.0.0.1:18789 %s\n' "$SSH_ALIAS"
else
  printf '   ssh -i %s -N -L 18789:127.0.0.1:18789 %s@%s\n' "$SSH_KEY" "$OPENCLAW_USER" "$HOST"
fi
printf '2) Open dashboard in private window: http://127.0.0.1:18789\n'
if [[ -n "$SSH_ALIAS" ]]; then
  printf '3) SSH to VPS: ssh %s\n' "$SSH_ALIAS"
  printf '4) If needed run on VPS: ~/.openclaw/bin/openclaw onboard\n'
else
  printf '3) If needed run on VPS: ~/.openclaw/bin/openclaw onboard\n'
fi
printf 'Install log: %s\n' "$LOG_FILE"
