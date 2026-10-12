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

Public port 22 stays closed. SSH is still `~/.ssh/hetzner_dev`, over the tailnet. The scripts do not change your tailnet policy and do not turn on Tailscale SSH (`--ssh` would ignore that key).

### One-time setup

1. Install Tailscale on the laptop and run `tailscale up`. `up` exits if that status is not Running.
2. [DNS](https://login.tailscale.com/admin/dns): MagicDNS on. Tailnets created after October 2022 already have it. This is what makes the name `dev-ai` resolve. The `100.x` address printed by `up` works without it, until the next clean boot.
3. [Keys](https://login.tailscale.com/admin/settings/keys): **Generate auth key**.
   - Reusable: on. A fresh image and a lost node both need the same key.
   - Ephemeral: off. An ephemeral node is deleted when the server is destroyed, so the next `up` has to reopen public SSH.
   - Tags: off. The script does not pass a tag.
   - Pre-approved: only listed if [device approval](https://login.tailscale.com/admin/settings/device-management) is on. If the checkbox is missing, leave device approval off. If it is there, tick Pre-approved.
   - Do not enable Tailnet Lock. A locked tailnet will not accept this key.
   - Expiry is 90 days at most. After that, a new join needs a new key in `pass`. A node that already joined keeps working until its own key expires.
4. Paste only the key, one line, no quotes: `pass insert -m tailscale/authkey`
5. Do not name another device `dev-ai`. `up` uses the first online peer with that hostname. The server is registered as `$NAME`.
6. After the first successful join, [Machines](https://login.tailscale.com/admin/machines): row `dev-ai`, menu, **Disable key expiry**. Otherwise the node saved in the snapshot stops authenticating after 180 days.

Leave the offline `dev-ai` node in Machines between `down` and `up`. Deleting it forces one public-SSH rejoin. The auth key is removed from the server disk after join. The node state in `/var/lib/tailscale` is what the snapshot reconnects with. The server does not use Tailscale DNS (`--accept-dns=false`).

A snapshot from before Tailscale was installed has no node state. That `up` opens public SSH, joins, then closes it again.

If other people are on the tailnet, the default policy lets them reach this server. The script does not install an ACL.

### Firewall

`up` creates a Hetzner firewall named `dev-ai-ts` once, from `firewall-tailscale.json`, and attaches it on every create. The only inbound rule is UDP 41641. The script does not overwrite rules you change later. Outbound stays open, which is how Tailscale connects from behind a deny-all inbound firewall.

Locked out, and the tailnet path is dead: `hcloud firewall remove-from-resource --type server --server dev-ai dev-ai-ts`. Fix the key, SSH to the public IP, then attach the firewall again.

### Connect

Tailscale must be connected on the laptop. Same entry for a terminal (`ssh dev-ai`) and VS Code Remote SSH (Connect to Host, `dev-ai`). Delete any host that still points at the public IP.

```sshconfig
Host dev-ai
  User ai-dev
  IdentityFile ~/.ssh/hetzner_dev
  IdentitiesOnly yes
```

A normal down/up keeps the SSH host key. A clean boot does not; `up` replaces the `dev-ai` entry in `known_hosts`. From another machine: `ssh-keygen -R dev-ai`.

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