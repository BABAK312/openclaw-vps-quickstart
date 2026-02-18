# v1.0.0

## Highlights

- One-command installer (`install.sh`) for fresh VPS bootstrap.
- End-to-end bootstrap (`bootstrap.sh`) with:
  - SSH key setup
  - non-root `openclaw` user setup
  - optional OS upgrade
  - SSH hardening by default
  - OpenClaw install + gateway service setup
  - token bootstrap and automatic mismatch repair path
- Verification and recovery tooling:
  - `verify.sh`
  - `verify.sh --repair`
  - `scripts/repair-token-mismatch.sh`
  - `scripts/smoke-test.sh`
- Local operator helpers:
  - `scripts/connect.sh`
  - `scripts/tunnel.sh`
  - `scripts/get-token.sh`
  - `scripts/reset-local-macos.sh`

## Security defaults

- Gateway bind = loopback
- SSH key-based access
- Password SSH disabled by default (override with `--no-harden-ssh`)

## Notes

- Run scripts from local terminal, not inside VPS shell.
- For multiple servers, rerun commands with different `--host` and local tunnel ports.
