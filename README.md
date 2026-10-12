# dev-ai-server

Ephemeral AI dev server on Hetzner Cloud. One command to create a fully-bootstrapped server, one to snapshot the disk and destroy it. The next create restores that snapshot.

## Repos

| Role | Purpose | Contains |
|------|---------|----------|
| Orchestration (this one) | scripts + cloud-config | `bin/`, `cloud-config.yaml` |
| Bootstrap keys (local) | keys injected into the server once per boot, managed via pass | SSH key, GPG key, Hetzner token |
| Encrypted secrets (private) | GPG-encrypted runtime secrets for the server, cloned at boot | API keys, tokens |
| Dotfiles (public) | chezmoi source for the server, applied on first boot | `.zshrc`, `.gitconfig`, pi config |

All remote repos are private except dotfiles.

## Prerequisites

- [hcloud CLI](https://github.com/hetznercloud/cli) installed and authenticated
- [Tailscale](https://tailscale.com/download) installed on the laptop and logged in (`tailscale up`)
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
pass insert -m tailscale/authkey         # reusable, not ephemeral
git push
```

## Commands

```bash
# create + bootstrap, or restore the latest snapshot
KEYS_REPO=<url> bin/dev-ai-server-up

# drop this NAME's snapshots and boot a fresh image
KEYS_REPO=<url> CLEAN=1 bin/dev-ai-server-up

# snapshot, then delete the server (stops hourly billing)
bin/dev-ai-server-down
```

`down` can take several minutes. Do not interrupt it: the server is deleted only after the snapshot is available.

## Snapshots

`down` powers the server off, snapshots the whole disk, then deletes the server. The next `up` boots that snapshot, so files, packages, and home are as you left them. Cloud-config and chezmoi do not run again. Cloud-init still configures the new network. GPG is unlocked again so `pass` works. The IP changes.

`up` and `down` keep the 2 newest snapshots labeled `dev-ai-server=<NAME>` and delete the rest. Hetzner bills every snapshot that still exists. No snapshot yet: `up` boots a fresh image and bootstraps, as before.

A different `NAME` is a different snapshot set and is not pruned with the default name. The server type must be the same architecture, and its disk must be at least as large as the snapshot.

Clean boot (drops the saved disk): `CLEAN=1` on `up`. It deletes every snapshot labeled `dev-ai-server=<NAME>`, then boots `IMAGE`. It does not delete a server that is still running, and it does not touch another `NAME`. If `dev-ai` is up, delete it without saving a disk first: `hcloud server delete dev-ai`. `down` would snapshot the disk you are trying to drop.

The snapshot includes keys under `~`. Same trust boundary as the server disk.

SSH user is `ai-dev` (passwordless sudo, `docker` group). Root SSH is disabled.

## Tailscale

Public inbound is closed. `up` creates a Hetzner firewall named `dev-ai-ts` the first time and attaches it on every create. The only inbound rule is UDP 41641, so Tailscale can connect directly. The script does not overwrite that firewall if you change its rules later.

`up` still uses `~/.ssh/hetzner_dev`. It SSHes to the server's Tailscale IPv4, not the public IP. Tailscale SSH is off: it would ignore that key.

Later, with Tailscale running, the stable name is the server name (`dev-ai`). MagicDNS must be on. Same entry for a terminal and for VS Code Remote SSH:

```sshconfig
Host dev-ai
  User ai-dev
  IdentityFile ~/.ssh/hetzner_dev
  IdentitiesOnly yes
```

The auth key must be reusable, and must not be ephemeral. Pre-approved is only shown if device approval is enabled; leave that off. An ephemeral node is deleted when the server is destroyed, so the next `up` has to reopen public SSH to join again. After a successful join the key is removed from the disk. The node state stays, and that is what the snapshot reconnects with. Leave the offline node in the admin console between `down` and `up`. Deleting it forces one public-SSH rejoin.

A snapshot taken before Tailscale was installed has no node state. That `up` opens public SSH, joins, then attaches the firewall again.

## Config

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_TYPE` | `cx23` | Hetzner server type |
| `LOCATION` | `fsn1` | Hetzner location (fsn1, nbg1, hel1) |
| `IMAGE` | `ubuntu-26.04` | OS image |
| `NAME` | `dev-ai` | Server name |
| `CLEAN` | *(unset)* | `1` deletes this name's snapshots and boots a fresh image |
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
| **tailscale** | private path in; public SSH stays closed |