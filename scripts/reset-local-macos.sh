#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/reset-local-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line="$1"
  local code="$2"
  printf '[ERROR] reset-local-macos.sh failed at line %s (exit %s). Log: %s\n' "$line" "$code" "$LOG_FILE" >&2
  exit "$code"
}
trap 'on_error "$LINENO" "$?"' ERR

usage() {
  cat <<USAGE
Usage: ./scripts/reset-local-macos.sh [options]

Options:
  --server-host <host>       Remove this host from known_hosts
  --ssh-key <path>           SSH key path (default: ~/.ssh/openclaw_vps_ed25519)
  --remove-ssh-key           Remove SSH private/public key files
  --remove-brew-tools        Uninstall ansible and ssh-copy-id from Homebrew
  --yes                      Skip confirmation prompt
  -h, --help                 Show help

This script resets local workstation artifacts used by this quickstart.
USAGE
}

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_value() {
  local opt="$1"
  local value="${2-}"
  [[ -n "$value" ]] || fail "Missing value for ${opt}"
}

validate_host() {
  local host="$1"
  [[ "$host" != -* ]] || fail "Invalid --server-host value: $host"
  [[ "$host" =~ ^[A-Za-z0-9._:-]+$ ]] || fail "Invalid --server-host value: $host"
}

SERVER_HOST=""
SSH_KEY="~/.ssh/openclaw_vps_ed25519"
REMOVE_SSH_KEY="no"
REMOVE_BREW_TOOLS="no"
ASSUME_YES="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-host)
      require_value "$1" "${2-}"
      SERVER_HOST="$2"
      shift 2
      ;;
    --ssh-key)
      require_value "$1" "${2-}"
      SSH_KEY="$2"
      shift 2
      ;;
    --remove-ssh-key)
      REMOVE_SSH_KEY="yes"
      shift 1
      ;;
    --remove-brew-tools)
      REMOVE_BREW_TOOLS="yes"
      shift 1
      ;;
    --yes)
      ASSUME_YES="yes"
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

SSH_KEY="${SSH_KEY/#\~/$HOME}"
if [[ -n "$SERVER_HOST" ]]; then
  validate_host "$SERVER_HOST"
fi

cat <<PLAN
Plan:
- Remove local OpenClaw state (~/.openclaw, ~/.config/openclaw, ~/.cache/openclaw)
- Remove global OpenClaw package via npm/pnpm when available
- Remove known_hosts entry (if --server-host set)
- Remove SSH key files only if --remove-ssh-key
- Uninstall Homebrew tools only if --remove-brew-tools

Log file: $LOG_FILE
PLAN

if [[ "$ASSUME_YES" != "yes" ]]; then
  read -r -p "Continue? [y/N] " confirm
  case "$confirm" in
    y|Y|yes|YES) ;;
    *)
      info "Canceled"
      exit 0
      ;;
  esac
fi

info "Removing local OpenClaw state"
rm -rf "$HOME/.openclaw" "$HOME/.config/openclaw" "$HOME/.cache/openclaw"

if command -v npm >/dev/null 2>&1; then
  info "Uninstalling global npm openclaw (if present)"
  npm rm -g openclaw >/dev/null 2>&1 || true
else
  warn "npm not found; skipping npm global uninstall"
fi

if command -v pnpm >/dev/null 2>&1; then
  info "Uninstalling global pnpm openclaw (if present)"
  pnpm remove -g openclaw >/dev/null 2>&1 || true
fi

if [[ -n "$SERVER_HOST" ]]; then
  info "Removing $SERVER_HOST from known_hosts"
  ssh-keygen -R "$SERVER_HOST" >/dev/null 2>&1 || true
fi

if [[ "$REMOVE_SSH_KEY" == "yes" ]]; then
  warn "Removing SSH key files: $SSH_KEY and $SSH_KEY.pub"
  ssh-add -d "$SSH_KEY" >/dev/null 2>&1 || true
  rm -f "$SSH_KEY" "$SSH_KEY.pub"
fi

if [[ "$REMOVE_BREW_TOOLS" == "yes" ]]; then
  if command -v brew >/dev/null 2>&1; then
    info "Uninstalling Homebrew tools (ansible, ssh-copy-id) if installed"
    brew list --formula 2>/dev/null | grep -qx 'ansible' && brew uninstall ansible || true
    brew list --formula 2>/dev/null | grep -qx 'ssh-copy-id' && brew uninstall ssh-copy-id || true
  else
    warn "brew not found; skipping brew uninstall"
  fi
fi

info "Local reset complete"
info "Log saved to: $LOG_FILE"
