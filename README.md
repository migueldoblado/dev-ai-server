# dev-ai-server

Ephemeral AI dev server on Hetzner Cloud. One command to create a fully-bootstrapped server, one to destroy it.

## Repos

| Role | Purpose | Contains |
|------|---------|----------|
| Orchestration (this one) | scripts + cloud-config | `bin/`, `cloud-config.yaml` |
| Bootstrap keys (local) | keys injected into the server once per boot, managed via pass | SSH key, GPG key, Hetzner token |
| Encrypted secrets (private) | GPG-encrypted runtime secrets for the server, cloned at boot | API keys, tokens |
| Dotfiles (public) | chezmoi source for the server, applied at boot | `.zshrc`, `.gitconfig`, pi config |

All remote repos are private except dotfiles.

## Prerequisites

- [hcloud CLI](https://github.com/hetznercloud/cli) installed and authenticated
- SSH key `~/.ssh/hetzner_dev` (private key on laptop, public key is in `cloud-config.yaml`)
- A private GitHub repo for GPG-encrypted runtime secrets (set as `KEYS_REPO`)
- A GitHub repo with chezmoi dotfiles for the server (public, hardcoded in the script)
- A pass password store with bootstrap keys cloned to `~/.config/personal-secrets` (see its README)

### Bootstrap keys (pass store)

Managed with [pass](https://www.passwordstore.org). Requires a GPG key.

```bash
git clone <bootstrap-keys-repo-url> ~/.config/personal-secrets
cd ~/.config/personal-secrets
pass init <your-gpg-key-id>              # creates .gpg-id
pass insert hetzner/token                # Hetzner Cloud API token
pass insert ssh/github_personal          # GitHub SSH private key
pass insert gpg/private.key              # GPG private key (for dev-ai-server)
pass insert gpg/passphrase               # passphrase of that private key
git push
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
| `IMAGE` | `ubuntu-26.04` | OS image |
| `NAME` | `dev-ai` | Server name |
| `KEYS_REPO` | *(required)* | Git URL of the GPG-encrypted secrets repo |
| `PERSONAL_SECRETS` | `~/.config/personal-secrets` | Path to local pass store |

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