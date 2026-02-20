# Release Notes

## v1.0.33

### Installer output UX
- Improved final `install.sh` output with copy-ready commands in English + Russian:
  - dashboard tunnel
  - dashboard URL
  - SSH connect command
  - onboarding command
  - gateway status/start/restart/stop
- Added explicit hint when no alias is configured:
  - re-run with `--ssh-alias openclaw-1`

### Command docs expansion
- Added and expanded command references:
  - `COMMANDS_EN.md`
  - `COMMANDS_RU.md`
- Added user-service systemd commands (`systemctl --user`) and quick common-fix section.

### Public links/docs
- Added live landing link to README files:
  - `https://lobster-openclaw-landing.vercel.app`
- Marked `LANDING.md` as legacy draft with pointer to live landing.

### Docs/version sync
- Bumped public install snippets to `v1.0.33`:
  - `README.md`
  - `README_EN.md`
  - `README_RU.md`
  - `LANDING.md`
  - `COMMANDS_EN.md`
  - `COMMANDS_RU.md`

## v1.0.32

### Installer automation
- Added automatic reboot flow in `install.sh` when `/var/run/reboot-required` is present:
  - sends reboot command
  - waits for SSH to return
  - runs final `verify` after reboot
- Added reboot controls:
  - `--no-auto-reboot`
  - `--reboot-wait-timeout <seconds>` (default `420`)

### Local UX improvements
- Added optional short SSH alias setup from installer:
  - `--ssh-alias <name>`
  - writes/upserts managed `Host` block in local `~/.ssh/config`
- Added short-command outputs at the end of install when alias is configured.

### Single-repo behavior on local machine
- Improved default repo directory detection in `install.sh`:
  - if run from an existing quickstart working directory, use current directory by default
  - avoids creating unintended duplicate clone at `~/openclaw-vps-quickstart`

### Bootstrap reliability fix
- Fixed remote bootstrap retry exit-code capture bug (`exit 0` false-positive path).

### Docs/version sync
- Bumped all public install snippets to `v1.0.32`:
  - `README.md`
  - `README_EN.md`
  - `README_RU.md`
  - `LANDING.md`
- Updated docs with new flags and reboot behavior.

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
