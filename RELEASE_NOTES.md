# Release Notes

## v1.0.28

### Repo hygiene
- Synced repository to current GitHub main state with a new clean release line.
- Added bilingual docs entrypoint and separated English/Russian READMEs.
- Updated install examples to `v1.0.28`.

### Installer & security baseline
- Restored hardened installer/bootstrap flow:
  - SSH key onboarding with safe validation
  - Dedicated `openclaw` user setup
  - UFW + Fail2ban + unattended-upgrades checks
  - Gateway loopback + token auth repair flow
- Restored verification and repair scripts used in production tests.

### Device keys / mobile UX
- Kept optional extra SSH keys workflow (`--extra-keys`).
- Added optional private-key terminal print mode (`--show-extra-private-keys`) with explicit warnings.

### Docs / branding
- Added Lobster references in a GitHub-friendly way.
- Added contact links (Telegram + GitHub Issues).
- Updated `LANDING.md` command snippets to latest tag and corrected Windows flow to WSL2.

### Legal
- Added explicit `LICENSE` file (`All Rights Reserved`).
