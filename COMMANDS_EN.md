# OpenClaw VPS Command Reference (EN)

This file is a practical command catalog for local machine + VPS operations.
Russian version: [COMMANDS_RU.md](COMMANDS_RU.md).

## 1) One-command install

Recommended (with short SSH alias):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --ssh-alias openclaw-1
```

Minimal:

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | bash -s -- --host <VPS_IP>
```

Run from your local quickstart directory (avoids duplicate local clone path explicitly):

```bash
curl -fsSL https://raw.githubusercontent.com/BABAK312/openclaw-vps-quickstart/v1.0.32/install.sh | FORCE_COLOR=1 bash -s -- --host <VPS_IP> --dir "<LOCAL_QUICKSTART_PATH>" --ssh-alias openclaw-1
```

## 2) Install flags explained

`FORCE_COLOR=1`
- Forces colored output when installer is piped from `curl`.

`--host <VPS_IP>`
- Target VPS hostname/IP. Required.

`--initial-user <USER>`
- First SSH user provided by VPS host (default `root`).

`--ssh-alias <NAME>`
- Creates/updates local alias in `~/.ssh/config`.
- Alias name is arbitrary: `openclaw-1`, `openclaw-prod`, `openclaw-91` are all valid.

`--extra-keys <N>`
- Generates and authorizes extra SSH keys for additional devices.

`--no-upgrade`
- Skips `apt upgrade` stage for faster reruns.

`--no-auto-reboot`
- Keeps manual reboot mode (default behavior is automatic reboot when required).

`--reboot-wait-timeout <seconds>`
- Timeout for installer waiting SSH return after auto reboot (default `420`).

`--skip-verify`
- Skips the final `verify.sh --repair` stage.

`--dir <PATH>`
- Local working folder for quickstart repo.

## 3) Connect to VPS (OpenClaw user)

With alias:

```bash
ssh openclaw-1
```

Full form:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 openclaw@<VPS_IP>
```

Root shell:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP>
```

Root via alias:

```bash
ssh openclaw-1 -l root
```

## 4) Open Control UI (dashboard)

Start local tunnel with alias:

```bash
ssh -N -L 18789:127.0.0.1:18789 openclaw-1
```

Or full form:

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 -N -L 18789:127.0.0.1:18789 openclaw@<VPS_IP>
```

Then open in browser:
- `http://127.0.0.1:18789`
- or quick URL with `#token=...` printed by installer.

Fetch current token from VPS:

```bash
./scripts/get-token.sh --host <VPS_IP>
```

## 5) OpenClaw operations on VPS

Run onboarding wizard:

```bash
openclaw onboard
```

Status:

```bash
openclaw status
openclaw status --all
openclaw status --deep
```

Gateway service:

```bash
openclaw gateway status
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw gateway install --force
```

Logs / diagnostics:

```bash
openclaw logs --follow
openclaw doctor
openclaw doctor --fix --yes --non-interactive
openclaw security audit
openclaw security audit --deep
```

Update CLI:

```bash
openclaw update status
openclaw update --yes
```

## 5.1) Systemd service (advanced, user service)

OpenClaw gateway is installed as a **user** service, not a root system service.

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
systemctl --user status openclaw-gateway.service
systemctl --user restart openclaw-gateway.service
journalctl --user -u openclaw-gateway.service -f
```

## 6) Verification and repair (local quickstart repo)

Health check:

```bash
./verify.sh --host <VPS_IP>
```

Health check with repair:

```bash
./verify.sh --host <VPS_IP> --repair
```

Quick smoke:

```bash
./scripts/smoke-test.sh --host <VPS_IP>
```

Repair token mismatch:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
```

## 7) Reboot and post-upgrade

Installer default:
- If `/var/run/reboot-required` exists, installer auto-reboots once, waits for SSH, and re-runs verify.

Manual reboot (if you used `--no-auto-reboot`):

```bash
ssh -i ~/.ssh/openclaw_vps_ed25519 root@<VPS_IP> "sudo reboot || reboot"
```

Manual reboot via alias:

```bash
ssh openclaw-1 -l root "sudo reboot || reboot"
```

## 8) Optional helper scripts

Connect helper:

```bash
./scripts/connect.sh --host <VPS_IP>
```

Tunnel helper:

```bash
./scripts/tunnel.sh --host <VPS_IP>
```

## 9) Local reset for clean retest (macOS)

```bash
./scripts/reset-local-macos.sh --server-host <VPS_IP> --remove-ssh-key --yes
find ~/.ssh -maxdepth 1 -type f \( -name 'openclaw_vps_extra_*_ed25519' -o -name 'openclaw_vps_extra_*_ed25519.pub' \) -delete
```

## 10) Alias management tips

Check alias block:

```bash
cat ~/.ssh/config
```

Remove alias block manually:
- Delete lines between:
  - `# >>> openclaw-vps-quickstart alias <NAME> >>>`
  - `# <<< openclaw-vps-quickstart alias <NAME> <<<`

## 11) Common issues (quick fixes)

Gateway already running:

```bash
openclaw gateway stop
openclaw gateway start
```

Unauthorized / token mismatch:

```bash
./scripts/repair-token-mismatch.sh --host <VPS_IP>
```

SSH warning `REMOTE HOST IDENTIFICATION HAS CHANGED` (local Mac/Linux):

```bash
ssh-keygen -R <VPS_IP>
```
