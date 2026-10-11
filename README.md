# dev-ai-server

Ephemeral AI dev server on Hetzner Cloud. One command to create, one to destroy.

## Prerequisites

- [hcloud CLI](https://github.com/hetznercloud/cli) installed and `hcloud context` active
- Hetzner API token with server read-write scope

## Commands

```bash
# create + boot (waits for IP, prints ssh line)
bin/dev-ai-server-up

# destroy immediately (stops hourly billing)
bin/dev-ai-server-down
```

## Config

Override with environment variables:

| Variable | Default |
|----------|---------|
| `SERVER_TYPE` | `cx23` |
| `LOCATION` | `fsn1` |
| `IMAGE` | `ubuntu-24.04` |
| `NAME` | `dev-ai` |

```bash
SERVER_TYPE=ccx33 LOCATION=nbg1 bin/dev-ai-server-up
```

## Manual first boot

After `dev-ai-server-up`, SSH in and run these once:

```bash
ssh root@<ip>

# 1. copy GitHub private key (for cloning private repos)
#    scp ~/.ssh/github_personal root@<ip>:~/.ssh/

# 2. import GPG key (for pass)
gpg --import < /path/to/private.key

# 3. clone pass secrets
pass git clone git@github.com:migueldoblado/pass-secrets.git

# 4. apply dotfiles
chezmoi init --apply migueldoblado/dotfiles-server

# 5. start herdr
herdr
```

## What's installed

| Tool | Purpose |
|------|---------|
| herdr | agent multiplexer |
| pi | coding agent (`@earendil-works/pi-coding-agent`) |
| rtk | LLM context filter for shell output |
| chezmoi | dotfiles manager → `dotfiles-server` repo |
| pass | GPG-encrypted secrets → `pass-secrets` repo |
| docker | container runtime |
| zsh | default shell |