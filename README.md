# OpenClaw VPS Quickstart (No Hard Allowlists)

This project bootstraps a fresh Ubuntu VPS for OpenClaw with:

- secure SSH key login
- dedicated non-root user (`openclaw`)
- OpenClaw installed under that user
- gateway service installed with systemd user service
- no Squid/domain allowlist/proxy restrictions from hardened templates

## Goal

Install and reach a working OpenClaw gateway in 2-3 commands from macOS/Linux.

## Fast path (fresh VPS)

1. Local terminal:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

./bootstrap.sh --host <VPS_IP>
```

2. Local terminal (new window):

```bash
./scripts/smoke-test.sh --host <VPS_IP>
```

3. Local terminal (keep running):

```bash
./scripts/tunnel.sh --host <VPS_IP>
```

Open browser: `http://127.0.0.1:18789`

## One-command raw install

If you want one command (without pre-cloning repo):

```bash
curl -fsSL https://raw.githubusercontent.com/ivansergeev/openclaw-vps-quickstart/main/install.sh | bash -s -- --host <VPS_IP>
```

This downloads this project to `~/.openclaw-vps-quickstart/openclaw-vps-quickstart` and runs `bootstrap.sh`.

## Usage

1. Clone and enter this folder.

```bash
git clone <your-repo-url>
cd <repo>
```

Important:

- Run commands from your local macOS/Linux terminal.
- Do not run `ssh -i ~/.ssh/id_ed25519 ...` from inside VPS shell.

2. Run bootstrap against your VPS IP.

```bash
./bootstrap.sh --host <YOUR_VPS_IP>
```

What it does:

- checks local dependencies
- ensures an SSH key exists (`~/.ssh/id_ed25519` by default)
- copies your public key to root on the VPS (asks for root password once if needed)
- creates/configures `openclaw` user
- enables `linger` for `openclaw`
- hardens SSH auth (`PasswordAuthentication no`, `PermitRootLogin prohibit-password`)
- installs OpenClaw via official installer as `openclaw`
- sets `gateway.mode=local` and `gateway.bind=loopback`
- installs/restarts gateway service
- ensures/repairs gateway auth token
- applies strict file permissions for `~/.openclaw` and credentials dirs
- writes detailed logs into `logs/`

3. Create SSH tunnel and open dashboard locally.

```bash
./scripts/tunnel.sh --host <YOUR_VPS_IP>
```

Open in browser: `http://127.0.0.1:18789`

## Gateway token note

These commands are valid and supported:

```bash
openclaw gateway --port 18789
openclaw config get gateway.auth.token
openclaw doctor --generate-gateway-token
```

In this quickstart, token setup is handled automatically by `bootstrap.sh`.

## Optional: model/channel onboarding

Run this on the VPS as `openclaw` when you are ready:

```bash
openclaw onboard
```

## Helper scripts (local)

Connect to server shell:

```bash
./scripts/connect.sh --host <IP>
```

Start dashboard tunnel:

```bash
./scripts/tunnel.sh --host <IP>
```

Get current gateway token:

```bash
./scripts/get-token.sh --host <IP>
```

## Security notes

- This setup keeps gateway on loopback only by default.
- SSH access is key-based.
- No hardened egress allowlists/proxy restrictions are applied.
- You still must secure channels/providers during onboarding.

## Parameters

```bash
./bootstrap.sh \
  --host <IP> \
  [--root-user root] \
  [--openclaw-user openclaw] \
  [--ssh-key ~/.ssh/id_ed25519] \
  [--ssh-port 22] \
  [--no-harden-ssh] \
  [--no-upgrade]
```

## Verify current server

```bash
./verify.sh --host <IP>
```

Auto-repair common issues (permissions + token mismatch reset):

```bash
./verify.sh --host <IP> --repair
```

Dedicated token-mismatch repair:

```bash
./scripts/repair-token-mismatch.sh --host <IP>
```

## Smoke test

```bash
./scripts/smoke-test.sh --host <IP>
```

## Local reset (Mac)

If you want to simulate a fresh local machine:

```bash
./scripts/reset-local-macos.sh --server-host <IP>
```

Optional destructive flags:

- `--remove-ssh-key` removes `~/.ssh/id_ed25519` and `.pub`
- `--remove-brew-tools` uninstalls `ansible` and `ssh-copy-id` from Homebrew

Example:

```bash
./scripts/reset-local-macos.sh --server-host <IP> --remove-brew-tools --yes
```

## Clean-room retest plan (fresh Mac state + fresh VPS)

1. Reinstall VPS OS (Ubuntu 24.04) in provider panel.
2. Optional local cleanup:

```bash
./scripts/reset-local-macos.sh --server-host <OLD_IP> --yes
```

3. If you also want a brand-new SSH key on Mac:

```bash
./scripts/reset-local-macos.sh --server-host <OLD_IP> --remove-ssh-key --yes
```

4. Bootstrap fresh VPS:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
./bootstrap.sh --host <NEW_IP>
```

5. Validate:

```bash
./scripts/smoke-test.sh --host <NEW_IP>
```

6. Open UI:

```bash
./scripts/tunnel.sh --host <NEW_IP>
```

## Multiple servers

Use the same scripts with different `--host` values:

```bash
./bootstrap.sh --host <SERVER_A_IP>
./bootstrap.sh --host <SERVER_B_IP>
./scripts/tunnel.sh --host <SERVER_A_IP> --local-port 18789
./scripts/tunnel.sh --host <SERVER_B_IP> --local-port 28789
```

This keeps one local repo and scales by host/IP without extra installs.

## Troubleshooting

- If `sudo` asks for `openclaw` password: do not use sudo as `openclaw` for `linger`; bootstrap handles it via root.
- If you see `Identity file /home/openclaw/.ssh/id_ed25519 not accessible`, you ran `ssh -i ...` inside VPS shell. Exit VPS and run SSH commands on your Mac/Linux host terminal.
- If gateway auth/token mismatch appears, rerun:

```bash
./scripts/repair-token-mismatch.sh --host <IP>
```
