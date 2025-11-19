# kk – Kubernetes Power Helper CLI

![kk logo](logo.png)

## kubectl

`kk` is a lightweight Bash wrapper around `kubectl` that removes repetitive typing and makes routine troubleshooting tasks faster. It keeps all configuration on your machine (no CRDs, no cluster install) and respects your current namespace automatically.

## Why build another CLI?

Working directly with plain `kubectl` often requires long commands, repeated namespace flags, and manual pod/deployment selection. `kk` focuses on:

- Short, memorable subcommands.
- Smart pattern matching for pods and deployments.
- Streamlined workflows such as log tailing, port-forwarding, and restarts.
- Safe defaults (e.g., namespace stored in `~/.kk`) and Unix-friendly output.

If you already know `kubectl`, `kk` simply helps you type less while keeping the exact same semantics.

## Features

- Namespace helper (`kk ns show|set`) backed by `~/.kk`.
- Pod utilities: list, exec shell, logs, describe, port-forward.
- Troubleshooting helpers: multi-pod log streaming, `kubectl top` filtering, recent events.
- Deployment automation: quick restarts and human-readable summaries (with `jq`).
- Context management (`kk ctx`) to switch Kubernetes contexts without touching namespaces.

## Requirements

- Bash 4+
- `kubectl` configured to access your cluster
- Optional:
  - `jq` for richer output in `kk images` and `kk deploys`
  - `fzf` for interactive selection when patterns match multiple pods/deployments

## Installation

### Manual symlink

```bash
git clone git@github.com:heart/kk-Kubernetes-Power-Helper-CLI.git
cd kk-Kubernetes-Power-Helper-CLI
chmod +x kk
ln -s "$(pwd)/kk" /usr/local/bin/kk  # adjust path as needed
```

Alternatively, copy the `kk` script anywhere on your `PATH`.

### install-kk.sh (offline-friendly)

Clone (or copy) this repo onto a machine with access to the target host, then run:

```bash
cd kk-Kubernetes-Power-Helper-CLI
sudo bash install-kk.sh                              # downloads latest kk from GitHub
sudo KK_URL="$(pwd)/kk" bash install-kk.sh           # reuse local kk for offline installs
sudo INSTALL_PATH=/opt/bin/kk bash install-kk.sh     # optional custom path
```

Set `KK_URL` to a local path (e.g., `sudo KK_URL="$(pwd)/kk" …`) or a `file:///` URL when the target machine is offline.

### install-kk.sh one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/heart/kk-Kubernetes-Power-Helper-CLI/main/install-kk.sh | sudo bash
```

Set `INSTALL_PATH` or `KK_URL` in the environment before the command if you need custom paths or mirrors.

> Note: This codebase is generated and maintained with help from a Codex agent—please review it before using in production clusters.

## Getting Started

1. Set your default namespace once:
   ```bash
   kk ns set my-namespace
   ```
   The value is persisted inside `~/.kk`.
2. Inspect pods in that namespace:
   ```bash
   kk pods
   kk pods api
   ```
3. Tail logs or jump into a shell using regex-like patterns:
   ```bash
   kk logs api -f -g ERROR
   kk sh api -- /bin/bash
   ```

## Command Highlights

| Command                          | Description                                                                                         |
| -------------------------------- | --------------------------------------------------------------------------------------------------- |
| `kk ns [show\|set\|list]`        | Show, set, or interactively pick the namespace stored in `~/.kk`.                                   |
| `kk svc [pattern]`               | List services (keeps header, optional regex filter).                                                |
| `kk pods [pattern]`              | List pods (keeps header, optional regex filter).                                                    |
| `kk sh <pattern> [-- cmd]`       | Exec into a pod resolved by pattern.                                                                |
| `kk logs <pattern> [options]`    | Stream logs from one or many pods, with container/grep/follow options.                              |
| `kk images <pattern>`            | Show images used by pods (requires `jq`).                                                           |
| `kk restart <deploy-pattern>`    | Rollout restart a deployment, with interactive selection when needed.                               |
| `kk pf <pattern> <local:remote>` | Port-forward to a pod.                                                                              |
| `kk desc <pattern>`              | Describe a pod.                                                                                     |
| `kk top [pattern]`               | Display pod CPU/memory usage, filtered by name if provided.                                         |
| `kk events`                      | Show recent events in the current namespace.                                                        |
| `kk deploys`                     | Summarize deployments; includes ready/desired and first container image (uses `jq` when available). |
| `kk ctx [context]`               | Show contexts or switch the active `kubectl` context.                                               |

All subcommands automatically prepend `-n "$NAMESPACE"` using the namespace from `~/.kk`.

## Philosophy

1. **Simplicity first** – single Bash script, easy to audit.
2. **Smart automation** – help with pattern matching and multi-resource operations without hiding raw Kubernetes concepts.
3. **Avoid abstraction leakage** – commands map directly to familiar `kubectl` verbs.
4. **Safe defaults** – no destructive actions without confirmation-style messaging.
5. **Unix-style output** – grep-friendly text, no complicated formatting.

## Contributing

Pull requests that follow the project's philosophy are welcome. When adding commands:

- Keep everything inside the single `kk` script.
- Implement subcommands as `cmd_<name>()` functions.
- Update the usage text and documentation accordingly.
- Ensure `load_namespace` is called whenever Kubernetes resources are accessed.

Happy troubleshooting!
