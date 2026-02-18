# OpenClaw VPS Quickstart

One-command OpenClaw installation on a clean Ubuntu VPS. No allowlists, no restrictions — just a working AI agent assistant.

## Why This Script?

**The problem:** Manual OpenClaw installation takes 30+ minutes and requires:
- 10+ terminal commands
- Understanding of SSH, systemd, permissions
- Manual configuration of users, SSH hardening, firewall
- Risk of mistakes that break the setup

**The solution:** One command does everything automatically.

## One-Command Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.26/install.sh | bash -s -- --host YOUR_VPS_IP
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.26/install.sh" -OutFile "install.ps1"
bash install.ps1 -host "YOUR_VPS_IP"
```

Or use WSL and run the same command as Linux.

## What the Script Does (Step by Step)

1. **SSH Key Setup** — Generates secure ED25519 key if you don't have one
2. **Server Connection** — Connects to your VPS via SSH (asks for password once)
3. **User Creation** — Creates dedicated `openclaw` user (not root!)
4. **System Updates** — Updates Ubuntu packages (optional, can skip with `--no-upgrade`)
5. **SSH Hardening** — Disables password auth, enables key-only login (optional)
6. **OpenClaw Installation** — Downloads and installs OpenClaw CLI
7. **Gateway Setup** — Configures and starts the web dashboard
8. **Token Generation** — Automatically generates authentication token
9. **Permissions** — Sets correct file permissions for security
10. **Verification** — Runs health checks to ensure everything works

**Total time:** ~3-5 minutes

## After Installation

1. Create SSH tunnel from your Mac/Linux:
   ```bash
   ssh -i ~/.ssh/id_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@YOUR_VPS_IP
   ```

2. Open browser: http://127.0.0.1:18789

3. Enter the gateway token (script shows it at the end)

4. Run `openclaw onboard` on the VPS to connect AI models and Telegram

## Options

```bash
--host <IP>              # VPS IP address (required)
--root-user <user>       # Initial SSH user (default: root)
--openclaw-user <user>   # Service user (default: openclaw)
--ssh-key <path>         # SSH key path (default: ~/.ssh/id_ed25519)
--ssh-port <port>        # SSH port (default: 22)
--no-harden-ssh          # Skip SSH hardening
--no-upgrade             # Skip system package upgrades
```

## Security

- Gateway runs on loopback only (127.0.0.1) — not exposed to internet
- SSH key-based authentication (no passwords stored)
- Dedicated non-root user for OpenClaw
- No Squid/allowlist/proxy restrictions
- Proper file permissions on all sensitive directories

## Verification

Check if your server is working:
```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.26/install.sh | bash -s -- --host YOUR_VPS_IP
# After install completes:
./verify.sh --host YOUR_VPS_IP
```

Or run smoke test:
```bash
./scripts/smoke-test.sh --host YOUR_VPS_IP
```

## Troubleshooting

- **"Run from local terminal" error** — Run the command on your Mac/Linux, not inside VPS shell
- **Gateway shows token mismatch** — Run: `./scripts/repair-token-mismatch.sh --host YOUR_VPS_IP`
- **Can't connect to dashboard** — Make sure SSH tunnel is running

## Quick Reference

| Action | Command |
|--------|---------|
| Install | `curl -fsSL .../install.sh \| bash -s -- --host IP` |
| Connect to VPS | `./scripts/connect.sh --host IP` |
| Open dashboard | `./scripts/tunnel.sh --host IP` |
| Get token | `./scripts/get-token.sh --host IP` |
| Verify | `./verify.sh --host IP` |
| Repair | `./verify.sh --host IP --repair` |
