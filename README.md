# kk – Kubernetes Power Helper CLI

_A faster, clearer, pattern-driven way to work with Kubernetes._

![kk logo](logo.png)

---

## Why kk exists

Working with plain `kubectl` often means:

- long repetitive commands
- retyping `-n namespace` all day
- hunting for pod names
- copying/pasting long suffixes
- slow troubleshooting loops

`kk` is a lightweight Bash wrapper that removes this friction.  
No CRDs. No server install. No abstraction magic.  
Just **fewer keystrokes, more clarity, and faster debugging**.

---

## Key Strengths of kk

### 🔹 1. Namespace that remembers itself

Set it once:

```
kk ns set staging
```

Every subcommand automatically applies it.  
No more `-n staging` everywhere.

---

### 🔹 2. Pattern-first Pod Selection

**Stop hunting for pod names. Start selecting by intent.**

In real clusters, pods look like:

```
api-server-7f9c8d7c9b-xyz12
api-server-7f9c8d7c9b-a1b2c
api-worker-64c8b54fd9-jkq8n
```

You normally must:

- run `kubectl get pods`
- search for the right one
- copy/paste the full name
- repeat when it restarts

`kk` removes that entire workflow.

#### ⭐ What “pattern-first” means

Any substring or regex becomes your selector:

```
kk logs api
kk sh api
kk desc api
```

Grouped targets:

```
kk logs server
kk logs worker
kk restart '^api-server'
```

Specific pod inside a large namespace:

```
kk sh 'order.*prod'
```

If multiple pods match, `kk` launches `fzf` or a numbered picker—no mistakes.

#### ⭐ Why this matters

Pattern-first selection eliminates:

- scanning long pod lists
- copying/pasting long suffixes
- dealing with restarts changing names
- typing errors in long pod IDs

**Your pattern expresses your intent.  
kk resolves the actual pod for you.**

#### ⭐ Works across everything

One selector model, applied consistently:

```
kk pods api
kk svc api
kk desc api
kk images api
kk restart api
```

---

### 🔹 3. Multi-pod Log Streaming & Debugging That Actually Works

Debugging in Kubernetes is rarely linear.  
Services scale, pods restart, replicas shift.  
Chasing logs across multiple pods is slow and painful.

`kk` makes this workflow _practical_:

```
kk logs api -g "traceId=123"
```

What happens:

- Any pod whose name contains `api` is selected
- Logs stream **from all replicas in parallel**
- Only lines containing `traceId=123` appear
- Every line is prefixed with the pod name
- You instantly see which replica emitted it

This transforms multi-replica debugging:

- flaky requests become traceable
- sharded workloads make sense
- cross-replica behavior becomes visible

You stop “hunting logs” and start “following evidence”.

---

### 🔹 4. Troubleshooting Helpers

Useful shortcuts you actually use daily:

- `kk top api` – quick CPU/memory filtering
- `kk desc api` – describe via pattern
- `kk events` – recent namespace events
- `kk pf api 8080:80` – smarter port-forward
- `kk images api` – pull container images (with `jq`)

kk reduces friction everywhere, not just logs.

---

## How kk improves real workflows

### Before kk

```
kubectl get pods -n staging | grep api
kubectl logs api-7f9c9d7c9b-xyz -n staging -f | grep ERROR
kubectl exec -it api-7f9c9d7c9b-xyz -n staging -- /bin/bash
```

### After kk

```
kk pods api
kk logs api -f -g ERROR
kk sh api
```

Same Kubernetes.  
Same kubectl semantics.  
**Less typing. Faster movement. Better clarity.**

---

## Available commands

| Command       | Syntax                                                                                | Description                                                                                                                                                                                                                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ns`          | `kk ns [show \| set <namespace> \| list]`                                             | Manage the persisted default namespace used by all kk commands. `show` prints the current namespace, `set` updates it (stored in `~/.kk`), and `list` lets you pick a namespace from the cluster (using `fzf` if available).                                                                                              |
| `pods`        | `kk pods [pattern]`                                                                   | List pods in the current namespace. If `pattern` is provided, it is treated as a regular expression and only pods whose names match the pattern are shown (header row is always kept).                                                                                                                                    |
| `svc`         | `kk svc [pattern]`                                                                    | List services in the current namespace. If `pattern` is provided, it is used as a regex filter on the service name column while preserving the header row.                                                                                                                                                                |
| `sh`, `shell` | `kk sh <pod-pattern> [-- COMMAND ...]`                                                | Exec into a pod selected by regex. Uses `pod-pattern` to match pod names, resolves to a single pod via `fzf` or an index picker if needed, then runs `kubectl exec -ti` into it. If no command is provided, it defaults to `/bin/sh`.                                                                                     |
| `logs`        | `kk logs <pod-pattern> [-c container] [-g pattern] [-f] [-- extra kubectl logs args]` | Stream logs from **all pods** whose names match `pod-pattern`. Optional `-c/--container` selects a container, `-f/--follow` tails logs, and `-g/--grep` filters lines by regex after prefixing each log line with `[pod-name]`. Any extra arguments after `--` are passed directly to `kubectl logs` (e.g. `--since=5m`). |
| `images`      | `kk images <pod-pattern>`                                                             | Show container images for every pod whose name matches `pod-pattern`. Requires `jq`. Prints each pod followed by a list of container names and their images.                                                                                                                                                              |
| `restart`     | `kk restart <deploy-pattern>`                                                         | Rollout-restart a deployment selected by regex. Uses `deploy-pattern` to find deployments, resolves to a single one via `fzf` or index picker, then runs `kubectl rollout restart deploy/<name>` in the current namespace.                                                                                                |
| `pf`          | `kk pf <pod-pattern> <local:remote> [extra args]`                                     | Port-forward to a pod selected by regex. Picks a single pod whose name matches `pod-pattern`, then runs `kubectl port-forward` with the given `local:remote` port mapping and any extra arguments. Prints a helpful error message when port-forwarding fails (e.g. port in use, pod restarting).                          |
| `desc`        | `kk desc <pod-pattern>`                                                               | Describe a pod whose name matches `pod-pattern`. Uses the same pattern-based pod selection and then runs `kubectl describe pod` on the chosen resource.                                                                                                                                                                   |
| `top`         | `kk top [pattern]`                                                                    | Show CPU and memory usage for pods in the current namespace using `kubectl top pod`. If `pattern` is provided, it is used as a regex filter on the pod name column while keeping the header row.                                                                                                                          |
| `events`      | `kk events`                                                                           | List recent events in the current namespace. Tries to sort by `.lastTimestamp`, falling back to `.metadata.creationTimestamp` if needed. Useful for quick troubleshooting of failures and restarts.                                                                                                                       |
| `deploys`     | `kk deploys`                                                                          | Summarize deployments in the current namespace. With `jq` installed, prints a compact table of deployment `NAME`, `READY/desired` replicas, and the first container image; otherwise falls back to `kubectl get deploy`.                                                                                                  |
| `ctx`         | `kk ctx [context]`                                                                    | Show or switch `kubectl` contexts. With no argument, prints all contexts; with a `context` name, runs `kubectl config use-context` and echoes the result on success.                                                                                                                                                      |
| `help`        | `kk help` / `kk -h` / `kk --help`                                                     | Display the built-in usage help, including a summary of all subcommands, arguments, and notes about namespace and regex-based pattern matching.                                                                                                                                                                           |

---

## Installation

### Simple install

```
git clone git@github.com:heart/kk-Kubernetes-Power-Helper-CLI.git
cd kk-Kubernetes-Power-Helper-CLI
cp kk.sh ~/.kk.sh
echo 'source ~/.kk.sh' >> ~/.bashrc   # or the shell RC you actually use
# open a new shell (or `source ~/.bashrc`) and start running kk commands
```

### One-liner

```
curl -fsSL https://raw.githubusercontent.com/heart/kk-Kubernetes-Power-Helper-CLI/main/install-kk.sh | sudo bash
# reload your shell so the kk() function from /etc/profile.d/kk.sh is available
# on macOS, the installer will remind you to add:  source /usr/local/lib/kk.sh  to ~/.zshrc (or similar)
```

### Uninstall

```
curl -fsSL https://raw.githubusercontent.com/heart/kk-Kubernetes-Power-Helper-CLI/main/uninstall-kk.sh | sudo bash
```

Or, if you installed manually, just delete the sourced script (e.g. `rm ~/.kk.sh`) and remove the `source ~/.kk.sh` line from your shell rc file.

---

## Getting Started

```
kk ns set my-namespace
kk pods
kk logs api -f -g ERROR
kk sh api -- /bin/bash
```

---

## Philosophy

1. **Stay simple** – a single Bash script
2. **Reduce friction** – automate repetitive work
3. **Stay true to Kubernetes** – don’t hide essential concepts
4. **Be safe** – clear confirmation before destructive actions
5. **Be Unixy** – everything is grep- and pipe-friendly

---

## Contributing

Pull requests are welcome.  
Keep it clean, keep it Bash, keep it understandable.

Happy troubleshooting!
