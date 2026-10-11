# dev-ai-server

Ephemeral AI dev server on Hetzner Cloud. One command to create a fully-bootstrapped server, one to destroy it.

## Repos

| Role | Purpose | Contains |
|------|---------|----------|
| Orchestration (this one) | scripts + cloud-config | `bin/`, `cloud-config.yaml` |
| Bootstrap keys (local) | keys injected into the server once per boot, never leaves the laptop otherwise | `ssh/github_personal`, `gpg/private.key` |
| Encrypted secrets (private) | GPG-encrypted runtime secrets for the server, cloned at boot | API keys, tokens |
| Dotfiles (public) | chezmoi source for the server, applied at boot | `.zshrc`, `.gitconfig`, pi config |

All remote repos are private except dotfiles.

## Prerequisites

- [hcloud CLI](https://github.com/hetznercloud/cli) installed and authenticated
- SSH key `~/.ssh/hetzner_dev` (private key on laptop, public key is in `cloud-config.yaml`)
- A private GitHub repo for GPG-encrypted runtime secrets (set as `KEYS_REPO`)
- A GitHub repo with chezmoi dotfiles for the server (public, hardcoded in the script)
- A local directory with bootstrap keys (set as `PERSONAL_SECRETS`, default below)

### Bootstrap keys directory

```
~/.config/personal-secrets/
├── ssh/
│   └── github_personal    # GitHub SSH private key
├── gpg/
│   └── private.key        # GPG private key (no passphrase, for automation)
└── README.md
```

Populate from your private bootstrap-keys repo:
```bash
git clone <bootstrap-keys-repo-url> ~/.config/personal-secrets
```

## Commands

```bash
# create + bootstrap (fully automatic)
KEYS_REPO=<url> bin/dev-ai-server-up

# destroy (stops hourly billing)
bin/dev-ai-server-down
```

## Config

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_TYPE` | `cx23` | Hetzner server type |
| `LOCATION` | `fsn1` | Hetzner location (fsn1, nbg1, hel1) |
| `IMAGE` | `ubuntu-24.04` | OS image |
| `NAME` | `dev-ai` | Server name |
| `KEYS_REPO` | *(required)* | Git URL of the GPG-encrypted secrets repo |
| `PERSONAL_SECRETS` | `~/.config/personal-secrets` | Path to local bootstrap keys |

```bash
KEYS_REPO=git@github.com:user/keys.git \
SERVER_TYPE=ccx33 LOCATION=nbg1 \
bin/dev-ai-server-up
```

## What's installed on the server

| Tool | Purpose |
|------|---------|
| **herdr** | agent multiplexer |
| **pi** | coding agent (`@earendil-works/pi-coding-agent`) |
| **rtk** | LLM context filter for shell output |
| **chezmoi** | dotfiles manager |
| **pass** | GPG-encrypted secrets |
| **docker** | container runtime |
| **zsh** | default shell |