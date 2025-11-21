# Agent Guide for `kk` – Kubernetes Power Helper CLI (Function Wrapper)

## Project Name

**kk – Kubernetes Power Helper CLI**

## Goal

`kk` is a lightweight **Bash function** that wraps `kubectl` and:

- Reduces repetitive typing for common Kubernetes tasks
- Adds smart, pattern-based helpers for pods and deployments
- Keeps behavior close to raw `kubectl` while improving ergonomics
- Keeps namespace state **per shell / per tmux pane** using an environment variable

Unlike `kubectl` plugins or standalone binaries, `kk` is:

- Implemented as a single Bash file (e.g. `~/kk.sh`)
- Loaded with `source ~/kk.sh`
- Exposed to the user as a shell function named `kk`

AI assistants (e.g. Codex) should extend and maintain this tool according to the guidelines below.

---

## Philosophy

1. **Simplicity first**

   - One file, minimal magic.
   - Prefer small helpers over complex frameworks.

2. **Smart automation**

   - Auto-select pods/deployments using patterns and `fzf` when available.
   - Avoid forcing the user to type full resource names.

3. **Avoid abstraction leakage**

   - `kk` is a thin layer over `kubectl`.
   - Do not hide or rewrite `kubectl` semantics.

4. **Safe defaults**

   - Respect the current namespace at all times.
   - Avoid dangerous operations by default.
   - Handle patterns safely (no raw injection into `awk`/`grep`).

5. **Unix-style output**

   - Simple, textual output that plays well with `grep`, `less`, `fzf`, etc.
   - No fancy formatting that breaks piping.

---

## Installation & Runtime Model

### How `kk` is installed

Typical usage:

```bash
# 1) Save kk.sh somewhere, e.g.:
cp kk.sh ~/kk.sh

# 2) Add to ~/.bashrc or ~/.zshrc:
source ~/kk.sh

# 3) Open a new shell and use:
kk ns set my-namespace
kk pods
```

### Function, not executable

- `kk` is declared as:

  ```bash
  kk() {
    # dispatcher calling kk_cmd_* functions
  }
  ```

- It is **not** meant to be executed directly as `./kk.sh`.
- All subcommands live in `kk_cmd_<name>()` helpers and are dispatched from `kk()`.

### Per-shell namespace

- Namespace lives in a shell variable:

  ```bash
  DEFAULT_NS="default"
  : "${KK_NAMESPACE:=$DEFAULT_NS}"
  ```

- Each shell / tmux pane:

  - Has its own `KK_NAMESPACE`.
  - Is independent of other shells.
  - Will default to `"default"` if `KK_NAMESPACE` is unset.

- The helper:

  ```bash
  _kk_current_namespace() {
    printf '%s\n' "${KK_NAMESPACE:-$DEFAULT_NS}"
  }
  ```

  is the **single source of truth** for the active namespace inside `kk`.

- **No files are used** to store namespace (no `~/.kk`, no on-disk config).

---

## Current Commands & Behavior

All commands implicitly use the namespace from `_kk_current_namespace()`
(which resolves to `KK_NAMESPACE` or `default`).

### Namespace commands

- `kk ns show`  
  Show the current namespace (from `KK_NAMESPACE` or `default`):

  ```text
  Current namespace: my-namespace
  ```

- `kk ns set <namespace>`  
  Set `KK_NAMESPACE` in this shell only:

  ```text
  Set namespace to: my-namespace
  ```

- `kk ns list`

  - Fetch all namespaces via:

    ```bash
    kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    ```

  - If `fzf` exists: interactive picker with header showing the current namespace.
  - Otherwise: print numbered list and prompt for index.
  - The selected namespace is written into `KK_NAMESPACE` (no files touched).

### Pods & Services

- `kk pods [name-substring-or-regex]`

  - Runs:

    ```bash
    kubectl get pods -n "$NAMESPACE"
    ```

    where `NAMESPACE` comes from `_kk_current_namespace`.

  - If a pattern is provided, filter by pod name (column 1) using **safe `awk`**:

    ```bash
    awk -v p="$pattern" 'NR==1 || $1 ~ p'
    ```

- `kk svc [name-substring-or-regex]`

  - Runs:

    ```bash
    kubectl get svc -n "$NAMESPACE"
    ```

  - If pattern is provided, filters via the same safe `awk` pattern.

### Pod & Deployment selection (internal helpers)

- `select_pod_by_pattern(pattern)`

  - Lists pod names in the current namespace:

    ```bash
    kubectl get pods -n "$NAMESPACE" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    ```

  - Filters with **safe `grep`**:

    ```bash
    grep -E -- "$pattern" || true
    ```

  - Behavior:
    - 0 matches: print clear error and return non-zero.
    - 1 match : print that pod name and return success.
    - > 1 match:
      - If `fzf` exists: interactive selection with `fzf`.
      - Else: numbered list + index prompt, return chosen pod name.

- `select_deploy_by_pattern(pattern)`

  - Same model as `select_pod_by_pattern`, but for deployments, using:

    ```bash
    kubectl get deploy -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
    ```

### Exec / Shell

- `kk sh <pod-pattern> [-- COMMAND...]`

  - Resolves the pod via `select_pod_by_pattern`.
  - Defaults to `/bin/sh` when no command is provided.
  - Runs:

    ```bash
    kubectl exec -ti -n "$NAMESPACE" "$pod" -- COMMAND...
    ```

  - Example default:

    ```bash
    kk sh api- --        # -> /bin/sh inside the chosen pod
    ```

### Logs

- `kk logs <pod-pattern> [-c container] [-g pattern] [-f] [-- extra kubectl args]`

  - Resolves all pods matching `<pod-pattern>` via `grep -E --`.
  - Options:

    - `-c/--container <name>` – restrict logs to a specific container.
    - `-g/--grep <pattern>` – filter log lines using `grep --line-buffered -E -- "$pattern"`.
    - `-f/--follow` – follow logs in real-time from all matching pods.
    - `--` – everything after `--` goes directly to `kubectl logs` as extra args.

  - Behavior:

    - **Non-follow mode**: iterate pods sequentially, prefixing logs:

      ```bash
      kubectl logs ... | sed -u "s/^/[$p] /"
      ```

    - **Follow mode**: run `kubectl logs -f` in the background for each pod, prefix each stream with its pod name, and `wait` for all.

  - If `-g` is specified, all output is piped through:

    ```bash
    grep --line-buffered -E -- "$grep_pattern" || true
    ```

### Images

- `kk images <pod-pattern>`

  - Requires `jq`. If `jq` is missing, prints an explicit error and returns non-zero.

  - Uses:

    ```bash
    kubectl get pods -n "$NAMESPACE" -o json |
      jq -r --arg p "$pattern" \
        '.items[]? | select(.metadata.name? | test($p)) | .metadata.name'
    ```

  - For each matched pod, prints container names and images from:

    ```bash
    kubectl get pod "$pod" -n "$NAMESPACE" -o json |
      jq -r '.spec.containers[] | "  - \(.name): \(.image)"'
    ```

### Deployments

- `kk restart <deploy-pattern>`

  - Resolves a deployment using `select_deploy_by_pattern`.
  - Runs:

    ```bash
    kubectl rollout restart "deploy/$deploy" -n "$NAMESPACE"
    ```

  - Prints a short message indicating which deployment and namespace are being restarted.

- `kk deploys`

  - If `jq` is available:

    - Runs `kubectl get deploy -n "$NAMESPACE" -o json` and formats a summary:

      ```text
      NAME                           READY      IMAGE
      my-api                         2/3        image: my-api:1.2.3
      ```

    - The jq expression uses `.items[]?`, `//` and `tostring` to avoid null issues.

  - If `jq` is not available: falls back to `kubectl get deploy -n "$NAMESPACE"`.

### Port-forward

- `kk pf <pod-pattern> <local:remote> [extra kubectl args...]`

  - Resolves pod via `select_pod_by_pattern`.
  - Runs:

    ```bash
    kubectl port-forward -n "$NAMESPACE" "$pod" "$port_spec" "${extra_args[@]}"
    ```

  - On failure, prints:

    ```text
    Port-forward failed (port in use, pod restarting, or network issue)
    ```

  - Returns non-zero from `kk`.

### Describe / Top / Events

- `kk desc <pod-pattern>`

  - Resolves pod via `select_pod_by_pattern`.
  - Runs:

    ```bash
    kubectl describe pod "$pod" -n "$NAMESPACE"
    ```

- `kk top [pattern]`

  - Runs `kubectl top pod -n "$NAMESPACE"`.
  - If a pattern is provided, filters using safe `awk`:

    ```bash
    awk -v p="$pattern" 'NR==1 || $1 ~ p'
    ```

- `kk events`

  - First tries:

    ```bash
    kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp
    ```

  - On failure, falls back to:

    ```bash
    kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp
    ```

### Contexts (global kubectl context)

- `kk ctx [list|use|show] [...]`

  - `kk ctx` or `kk ctx list`

    ```bash
    kubectl config get-contexts
    ```

  - `kk ctx use <context>`

    ```bash
    kubectl config use-context "$context"
    ```

    - On success: prints `Switched to context: <context>`.
    - On failure: prints `Failed to switch context: <context>` and returns non-zero.

  - `kk ctx show [context]`

    - If no context is provided, resolves the current context via `kubectl config current-context`.
    - Shows context details with:

      ```bash
      kubectl config view --minify --context "$context"
      ```

    - On failure: prints `Failed to show details for context: <context>` and returns non-zero.

  - **Note:** Contexts are global kubectl configuration. `kk` does not implement its own context system; it simply forwards to `kubectl`.

---

## Tech Stack & Constraints

- Shell: `bash` (`#!/usr/bin/env bash`)
- Runtime: `kk()` function plus `kk_cmd_*` & helper functions in a single file.
- Tools:
  - Required: `kubectl`
  - Optional: `jq`, `fzf`
- No other mandatory dependencies or external scripts.

---

## Safety & Robustness Guidelines

When modifying or adding code, **AI assistants must**:

1. **Use safe `awk` patterns**

   - Never inject `$pattern` directly into the awk script text.
   - Always pass user patterns via `-v p="$pattern"` and use `~ p` inside the script.

2. **Use safe `grep` invocation**

   - Always use `grep -E -- "$pattern"` (or `grep --line-buffered -E -- "$pattern"`).
   - The `--` is mandatory to prevent patterns beginning with `-` from being interpreted as options.

3. **Use safe `jq` selectors**

   - Prefer `.items[]?`, `.metadata.name?` and `//` for null-safe defaults.
   - Avoid assuming keys always exist.

4. **Error handling**

   - When a `kubectl` command fails (non-zero exit):

     - Print a short, clear error message to `stderr` (`>&2`).
     - `return` non-zero from the `kk_cmd_*` function.

   - Never silently ignore errors.

5. **Namespace respect**

   - All `kubectl` calls must either:
     - Use `-n "$NAMESPACE"` where `NAMESPACE` came from `_kk_current_namespace`, or
     - Intentionally rely on kubectl defaults **only** when that is explicitly desired and documented.
   - Do **not** reintroduce file-based namespace storage (e.g. `~/.kk`).

6. **Function, not process**

   - `kk` and all `kk_cmd_*` implementations must use `return` instead of `exit`.
   - Calling `exit` would terminate the user’s shell; this is **forbidden**.
   - Assume `set -e` is **not** controlling the calling shell; each function must handle its own return codes.

---

## Design Rules

1. Single Bash file defining:

   - Helper functions (`_kk_current_namespace`, `select_pod_by_pattern`, etc.)
   - Subcommand functions (`kk_cmd_ns`, `kk_cmd_pods`, ...)
   - Dispatcher function `kk()`.

2. Use only:

   - `bash`
   - `kubectl`
   - Optional: `jq`, `fzf`

3. No heavy or compiled dependencies.

4. Keep public CLI stable:

   - Subcommand names and flags must not be changed unless explicitly requested.
   - Output format may be improved but should remain human-readable and grep-friendly.

5. Error messages:

   - Clear, concise, and sent to `stderr` where appropriate.
   - Should help the user understand what went wrong and how to fix it.

---

## Allowed Tasks for AI Assistants

- Implement new subcommands **when explicitly requested**.
- Refactor for readability and safety (quoting, error handling, pattern safety).
- Fix bugs without changing public CLI semantics.
- Update `kk_usage()` and comments to match behavior.
- Add small helpers to reduce duplication, as long as the external behavior remains unchanged.

---

## Forbidden Changes

- Adding features or commands that were **not requested**.
- Breaking backward compatibility (changing subcommand names or flag semantics).
- Re-introducing on-disk namespace config (e.g. `~/.kk`) without explicit instruction.
- Replacing or “wrapping away” native `kubectl` logic with some other tool.
- Adding new mandatory dependencies or complex frameworks.
- Introducing interactive prompts where non-interactive behavior is expected.

---

## Output Expectations for AI

When modifying code:

- Prefer **minimal diffs** over full rewrites.
- Keep the overall structure, function names, and command names unchanged.
- Only perform large refactors if explicitly asked, and then:
  - Explain the refactor with comments where it improves clarity or safety.

---

## Notes for Non-interactive Tools (like Codex)

- If something is ambiguous, choose the **smallest, safest change** that preserves current behavior.
- Do not invent new commands, flags, or behaviors unless the user explicitly asks for them.
- Keep the mental model simple: “`kk` = small, opinionated `kubectl` helper loaded as a shell function with per-shell namespace.”

---

## Documentation Update Requirement (MANDATORY)

Every code modification must be accompanied by updates to the documentation files:

- README.md (English)
- README-th.md (Thai)

AI assistants must update these two files whenever:

1. New commands or features are added
2. Existing behaviors change
3. Output format or arguments change
4. Namespace or context logic changes
5. Install instructions change
6. Safety rules change
7. Any detail is added or removed from kk.sh that affects user workflow

The documentation must always reflect the actual behavior of the script.
If a change cannot be expressed safely in the README, the feature must not be implemented.
