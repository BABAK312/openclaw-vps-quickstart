# Release Notes

## v1.0.31

### Reliability fixes (installer/bootstrap/verify)
- Fixed transient SSH disconnect failures (`exit 255`) during post-bootstrap steps:
  - extra SSH key authorization (`--extra-keys`)
  - post-install status checks (`linger`, `gateway status`, permissions, hardening checks, token fetch)
- Added minimal SSH retry policy for transient transport errors only:
  - retry count: 3
  - retries only for `ssh` exit `255`
  - no retries for functional/auth/config errors
- Isolated long remote bootstrap execution from SSH multiplex socket state by running that step with `ControlMaster=no`.
- Kept OpenClaw CLI install retry minimal (single retry) for temporary upstream/network failures.

### Verify improvements
- Added the same minimal transient-SSH retry behavior to `verify.sh` (including `--repair` path), so diagnostics are stable on flaky links.

### Helper scripts hardening
- Added strict argument validation to:
  - `scripts/connect.sh`
  - `scripts/tunnel.sh`
  - `scripts/get-token.sh`
- Invalid/missing option values now fail fast with clear messages.

### Docs/version sync
- Bumped all public install snippets to `v1.0.31`:
  - `README.md`
  - `README_EN.md`
  - `README_RU.md`
  - `LANDING.md`

### Validation run
- Full install flow executed on Ubuntu 24.04 VPS from macOS:
  - `install.sh` (with `--extra-keys 1`)
  - `verify.sh` / `verify.sh --repair`
  - `scripts/smoke-test.sh` (7/7 pass)
- All repository shell scripts pass `bash -n`.

## v1.0.30

### Docs/version sync
- Bumped all public install snippets to `v1.0.30`:
  - `README.md`
  - `README_EN.md`
  - `README_RU.md`
  - `LANDING.md`
- Expanded root `README.md` quickstart flow for first-time users:
  - 60-second install path
  - common flags
  - important paths
  - day-2 operations

## v1.0.29

### Documentation upgrade
- Expanded docs for better first-time onboarding.
- Added bilingual structure:
  - `README.md` (entrypoint)
  - `README_EN.md`
  - `README_RU.md`
- Added clear sections:
  - what installer configures
  - command cheat sheet
  - post-install and repair flow
- Updated all install snippets to `v1.0.29`.

### Script baseline
- Kept hardened installer/bootstrap flow and diagnostics stack.
- Kept mobile extra-key UX (`--extra-keys`) and optional key-print mode (`--show-extra-private-keys`).
- Normalized helper script defaults to `~/.ssh/openclaw_vps_ed25519`.

### Repo hygiene
- Updated `LANDING.md` command snippets and Windows flow (WSL2).
- Kept Lobster contacts in a GitHub-friendly format.
- Preserved explicit legal notice (`LICENSE`, All Rights Reserved).
