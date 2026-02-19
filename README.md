# 🦞 Lobster OpenClaw VPS Quickstart

Security-first OpenClaw setup for Ubuntu VPS in one command.

## Language

- English: [README_EN.md](README_EN.md)
- Русский: [README_RU.md](README_RU.md)

## Quick Install (latest)

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.29/install.sh | bash -s -- --host <VPS_IP>
```

## What You Get

- SSH key based access (password auth disabled by default).
- Dedicated non-root user: `openclaw`.
- Host hardening baseline: `UFW`, `Fail2ban`, `unattended-upgrades`.
- OpenClaw gateway bound to loopback with token auth.
- Verification and repair scripts for post-install diagnostics.

## Repo Map

- `install.sh`: one-command entrypoint from local machine.
- `bootstrap.sh`: full VPS bootstrap and hardening flow.
- `verify.sh`: diagnostics and optional repair mode.
- `scripts/smoke-test.sh`: quick health checks.
- `scripts/repair-token-mismatch.sh`: gateway token mismatch fixer.
- `scripts/tunnel.sh`: local SSH tunnel helper for Control UI.
- `scripts/connect.sh`: SSH connect helper.
- `scripts/get-token.sh`: fetch gateway token from VPS.
- `LANDING.md`: long-form landing content.

## Project Links

- Landing content: [LANDING.md](LANDING.md)
- Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues
- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl

## License

This project is distributed under [LICENSE](LICENSE) (`All Rights Reserved`).
