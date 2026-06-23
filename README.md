# copilot-sandbox
Ephemeral Docker container for demoing and testing GitHub Copilot CLI over SSH.

## Why

Spin up a clean, disposable environment that simulates a real SSH workflow — perfect for quick demos and testing. The container provides a proper PTY over SSH (unlike `docker exec -it`, which breaks interactive prompts), resets to a blank slate on every restart, and takes seconds to launch.

## What's included

- **Ubuntu 24.04** (pinned)
- git, curl, ripgrep, fd
- GitHub CLI (`gh`)
- Neovim + LazyVim (arm64/amd64 auto-detected)
- GitHub Copilot CLI
- gnome-keyring (encrypted credential storage — no plain text tokens)
- SSH server (key-based auth only, no password, non-root `dev` user)

## Quick start

```bash
make up    # Build and start the container
make ssh   # SSH in

# Inside the container — authenticate GitHub CLI
gh auth login          # interactive OAuth device flow
gh auth setup-git      # sets gh as git credential helper for private repos
gh auth status         # verify auth

# Launch Copilot CLI (uses its own OAuth device flow for multi-org support)
copilot
```

> **Note:** Credentials are stored in `gnome-keyring` (encrypted, in-memory).
> No plain text config files. Everything is destroyed when the container stops.

## Commands

```
make build   Build the container
make builder (Re)start the image builder with a working DNS server
make up      Build and start the container
make down    Stop and remove the container
make ssh     SSH into the container
make clean   Remove container, image, and SSH keys
make help    Show all commands
```

## Tear down

```bash
make down
```

Every restart is a fresh environment — nothing persists.

## SSH key

A project-local SSH keypair is generated automatically on first `make up` (stored in `.ssh/`, gitignored). No setup needed — it just works.

To regenerate the key:

```bash
make clean   # removes keys and container
make up      # generates a fresh key and starts the container
```

## Private marketplace repos

If you use `/plugin marketplace add` with private repos, `gh auth setup-git` is **required**. Without it, git has no credential helper and will prompt for a username/password — which freezes the terminal.

Verify it's set:

```bash
git config --global --list | grep cred
# Should show: credential.https://github.com.helper=!/usr/bin/gh auth git-credential
```

Your fine-grained PAT also needs access to the private repos you're adding as marketplaces.

## Troubleshooting

### `make build` fails with `Temporary failure resolving 'ports.ubuntu.com'`

Apple's `container` image builder starts **without a DNS server**, so `apt-get update`
inside the build can't resolve package mirrors. Every package then fails with
`Unable to locate package ...`.

`make build` now fixes this automatically by (re)starting the builder with DNS before
building. If your network blocks `1.1.1.1`, point it at another resolver:

```bash
make build BUILDER_DNS=8.8.8.8
```

To reset the builder manually:

```bash
container builder stop
container builder start --dns 1.1.1.1
```

> Note: passing `--dns` to `container build` directly does **not** work — the RUN steps
> ignore it. The DNS server must be set when the **builder** is started.

The `dns:` entry in `docker-compose.yml` is the matching setting for the **running**
container, but note the current `container-compose` does not yet honor it, so the
running container's DNS isn't overridden today. It's kept as standard, forward-compatible
Compose syntax. If a container needs working DNS at runtime now, start it with
`container run --dns 1.1.1.1 ...`.

## Notes

- SSH is bound to `127.0.0.1:2222` only (not exposed to network)
- The `dev` user has passwordless sudo
- Container runs with `init: true` for proper signal handling
- `gh` tokens are stored in gnome-keyring (encrypted, in-memory) — not in plain text
- Copilot CLI uses OAuth device flow and supports authenticating to multiple orgs
