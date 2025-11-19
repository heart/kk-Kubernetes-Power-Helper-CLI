# Agent Guide for `kk` – Kubernetes Power Helper CLI

## Project Name

**kk – Kubernetes Power Helper CLI**

## Goal

`kk` is a lightweight Bash CLI wrapper around `kubectl` that:

- Reduces repetitive typing for common Kubernetes tasks
- Adds smart, pattern-based helpers for pods and deployments
- Keeps behavior close to raw `kubectl` while improving ergonomics

Unlike `kubectl` plugins, `kk` is a **single executable Bash script**.
It focuses on:

- Short, memorable commands
- Smart pod/deployment matching
- Automatic namespace handling
- Multi-pod log streaming with optional grep
- Fast troubleshooting workflows (logs, exec, restart, pf, etc.)

AI assistants (e.g. Codex) should extend and maintain this tool according to the guidelines below.

---

## Philosophy

1. **Simplicity first**

   - One script, minimal magic.
   - Prefer small helpers over complex frameworks.

2. **Smart automation**

   - Auto-select pods/deployments using patterns and `fzf` when available.
   - Avoid forcing the user to type full resource names.

3. **Avoid abstraction leakage**

   - `kk` is a thin layer over `kubectl`.
   - Do not hide or rewrite `kubectl` semantics.

4. **Safe defaults**

   - Respect the configured namespace at all times.
   - Avoid dangerous operations by default.
   - Handle patterns safely (no raw injection into `awk`/`grep`).

5. **Unix-style output**
   - Simple, textual output that plays well with `grep`, `less`, `fzf`, etc.
   - No fancy formatting that breaks piping.

---

## Current Commands & Behavior

All commands implicitly use the namespace stored in `~/.kk` (falling back to `default`).

### Namespace

- `kk ns show`  
  Show the current namespace (`$NAMESPACE` from `~/.kk` or `default`).

- `kk ns set <namespace>`  
  Persist a new namespace into `~/.kk`.

- `kk ns list`  
  Fetch all namespaces with `kubectl get ns`, then:
  - If `fzf` exists: interactive picker
  - Otherwise: numbered list + index selection  
    The chosen namespace is stored in `~/.kk`.

### Pods & Services

- `kk pods [name-substring-or-regex]`

  - `kubectl get pods -n $NAMESPACE`
  - If pattern is provided, filter by pod name (column 1) using `awk` with a **safe variable pattern**, not raw injection.

- `kk svc [name-substring-or-regex]`
  - `kubectl get svc -n $NAMESPACE`
  - Optional safe `awk` filter on service name (column 1).

### Pod selection (internal behavior)

- `select_pod_by_pattern(pattern)`

  - Lists all pod names in the current namespace.
  - Filters with **`grep -E -- "$pattern"`** (always using `--` to avoid option injection).
  - If one result: returns it.
  - If many:
    - Use `fzf` if available, otherwise show a numbered list and ask for index.

- `select_deploy_by_pattern(pattern)`
  - Similar to `select_pod_by_pattern` but for deployments.

### Exec / Shell

- `kk sh <pod-pattern> [-- COMMAND...]`
  - Resolves the pod via `select_pod_by_pattern`.
  - Default command: `/bin/sh` if none is provided.
  - Runs `kubectl exec -ti -n $NAMESPACE "$POD" -- COMMAND...`.

### Logs

- `kk logs <pod-pattern> [-c container] [-g pattern] [-f] [-- extra kubectl args]`
  - Finds all pods matching the pattern (using `grep -E --`).
  - If `-f` is set: follow logs from all matching pods concurrently.
  - Prefixes each log line with `[pod-name] ` using `sed -u`.
  - If `-g/--grep` is set:
    - Pipe through `grep --line-buffered -E "$grep_pattern"`
    - `grep` must always be called as `grep -- ...` or `grep -E -- ...` to avoid option injection.

### Images

- `kk images <pod-pattern>`
  - Requires `jq`.
  - Uses `kubectl get pods -o json` and a **safe jq expression**:
    - `.items[]? | select(.metadata.name? | test($p))`
  - For each matching pod, prints container names and images.

### Deployments

- `kk restart <deploy-pattern>`

  - Resolve deployment via `select_deploy_by_pattern`.
  - Run `kubectl rollout restart deploy/<name> -n $NAMESPACE`.

- `kk deploys`
  - If `jq` is available:
    - `kubectl get deploy -o json` and summarize as:
      - `NAME READY/REPLICAS image: <image>`
    - Use `.items[]?` and safe accessors (`//`, `tostring`) to avoid null issues.
  - Otherwise fallback to `kubectl get deploy -n $NAMESPACE`.

### Port-forward

- `kk pf <pod-pattern> <local:remote> [extra kubectl args...]`
  - Resolve pod via `select_pod_by_pattern`.
  - Run `kubectl port-forward -n $NAMESPACE "$POD" "$local:$remote" ...`
  - On failure, print a clear message:
    - e.g. `"Port-forward failed (port in use, pod restarting, or network issue)"` and exit non-zero.

### Describe / Top / Events / Contexts

- `kk desc <pod-pattern>`

  - Describe the resolved pod: `kubectl describe pod`.

- `kk top [pattern]`

  - `kubectl top pod -n $NAMESPACE`, optional filter by pod name using safe `awk`.

- `kk events`

  - `kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp`
  - Fallback to `--sort-by=.metadata.creationTimestamp` if needed.

- `kk ctx [context]`
  - No args: `kubectl config get-contexts`.
  - With arg: `kubectl config use-context <context>`
    - On success: print confirmation.
    - On failure: print a clear error and exit non-zero.

---

## Tech Stack & Constraints

- Shell: `bash` (`#!/usr/bin/env bash`)
- Tools:
  - Required: `kubectl`
  - Optional: `jq`, `fzf`
- No other mandatory dependencies allowed.

---

## Safety & Robustness Guidelines

When modifying or adding code, **AI assistants must**:

1. **Use safe awk patterns**

   - Never inject `$pattern` directly into the awk script source.
   - Always pass it via `-v p="$pattern"` and match with `~ p`.

2. **Use safe grep invocation**

   - Always use `grep -E -- "$pattern"` (note the `--`) to avoid treating user patterns as options.

3. **Use safe jq selectors**

   - Prefer `.items[]?`, `.metadata.name?` and `//` for null-safe defaults.

4. **Error handling**

   - When a command fails (e.g., `kubectl` returns non-zero), print a brief, clear error and exit non-zero.
   - Don’t silently ignore failures.

5. **Namespace respect**
   - All kubectl calls must include `-n "$NAMESPACE"` where appropriate.
   - Namespace should always come from `load_namespace()`.

---

## Design Rules

1. Single Bash script (`kk`).
2. Use only: `bash + kubectl (+ jq optional, + fzf optional)`.
3. No heavy or compiled dependencies.
4. All commands implemented as `cmd_<name>()` functions.
5. Use `load_namespace()` rather than reimplementing namespace logic.
6. Provide clear, short error messages.
7. Do not silently change existing behavior.

---

## Allowed Tasks for AI Assistants

- Implement new subcommands **when explicitly requested**.
- Refactor for readability and safety (quoting, error handling, pattern safety).
- Fix bugs without changing public CLI semantics.
- Update `usage()` and comments to match behavior.
- Add small, well-scoped helpers that align with the philosophy.

---

## Forbidden Changes

- Adding features or commands that were **not requested**.
- Breaking backward compatibility (changing existing flags or semantics).
- Replacing or “wrapping” `kubectl` logic with a different implementation.
- Adding new mandatory dependencies or complex frameworks.
- Introducing interactive behavior that blocks non-interactive use without need.

---

## Output Expectations for AI

When modifying code:

- Prefer **minimal diffs** over rewrites.
- Keep overall structure, function names, and command names unchanged.
- If major refactors are absolutely required, explain them in comments.

---

## Notes for Non-interactive Tools (like Codex)

- If something is ambiguous, **prefer the smallest, safest change** that preserves current behavior.
- Do not invent new commands, flags, or behaviors unless the user explicitly asked for them in the prompt.
