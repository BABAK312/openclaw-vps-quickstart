# 🦞 Lobster OpenClaw VPS Quickstart

Secure one-command setup for OpenClaw on Ubuntu VPS.

Language:
- English: [README_EN.md](README_EN.md)
- Русский: [README_RU.md](README_RU.md)

Quick install (latest):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.28/install.sh | bash -s -- --host <VPS_IP>
```

Project links:
- Landing content: [LANDING.md](LANDING.md)
- Issues: https://github.com/BABAK312/openclaw-vps-quickstart/issues
- Telegram (Lobster): https://t.me/+MofnVybrWDU4YTRl

Security defaults:
- SSH key auth (`PasswordAuthentication no` by default)
- Dedicated `openclaw` user
- UFW + Fail2ban + unattended-upgrades
- Gateway on loopback (`127.0.0.1`) with token auth
