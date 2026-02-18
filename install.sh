#!/usr/bin/env bash
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  cat <<USAGE
Usage: install.sh [install options] [bootstrap options]

Install options:
  --repo <owner/repo>        GitHub repository slug (default: ivansergeev/openclaw-vps-quickstart)
  --branch <name>            Branch or tag (default: main)
  --workdir <path>           Local cache dir (default: ~/.openclaw-vps-quickstart)
  -h, --help                 Show help

Bootstrap options are passed through to bootstrap.sh, e.g.:
  --host <VPS_IP>
  --ssh-key ~/.ssh/id_ed25519
  --ssh-port 22
  --root-user root
  --openclaw-user openclaw
  --no-harden-ssh
  --no-upgrade

Example:
  curl -fsSL https://raw.githubusercontent.com/ivansergeev/openclaw-vps-quickstart/main/install.sh | bash -s -- --host 1.2.3.4
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

REPO="${OPENCLAW_QUICKSTART_REPO:-ivansergeev/openclaw-vps-quickstart}"
BRANCH="${OPENCLAW_QUICKSTART_BRANCH:-main}"
WORKDIR="${OPENCLAW_QUICKSTART_WORKDIR:-$HOME/.openclaw-vps-quickstart}"
FORWARD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --workdir)
      WORKDIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -n "${SSH_CONNECTION:-}" ]]; then
  fail "Run install.sh from your local terminal, not inside VPS shell"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing command: $1"
  fi
}

require_cmd curl
require_cmd tar
require_cmd bash

REPO_NAME="${REPO##*/}"
WORKDIR="${WORKDIR/#\~/$HOME}"
TARGET_DIR="$WORKDIR/$REPO_NAME"
TMP_DIR="$(mktemp -d)"
ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$WORKDIR"

printf '\n'
printf '%s\n' "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
printf '%s\n' "${CYAN}${BOLD}║        OpenClaw VPS Quickstart Installer                   ║${NC}"
printf '%s\n' "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
printf '\n'

info "Downloading ${REPO}@${BRANCH}"
curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/repo.tgz"

tar -xzf "$TMP_DIR/repo.tgz" -C "$TMP_DIR"

SRC_DIR="$TMP_DIR/${REPO_NAME}-${BRANCH}"
if [[ ! -d "$SRC_DIR" ]]; then
  SRC_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)"
fi

if [[ ! -d "$SRC_DIR" ]]; then
  fail "Cannot locate extracted repository content"
fi

rm -rf "$TARGET_DIR.tmp"
mkdir -p "$TARGET_DIR.tmp"
cp -R "$SRC_DIR"/. "$TARGET_DIR.tmp"/
rm -rf "$TARGET_DIR"
mv "$TARGET_DIR.tmp" "$TARGET_DIR"

ok "Project ready at: $TARGET_DIR"

info "Running bootstrap..."
exec bash "$TARGET_DIR/bootstrap.sh" "${FORWARD_ARGS[@]}"
