#!/usr/bin/env bash
# kk - Kubernetes helper CLI
# Lightweight wrapper around kubectl for daily Dev/DevOps workflows.

set -euo pipefail

CONFIG_FILE="${HOME}/.kk"
DEFAULT_NS="default"

###############################################################################
# Namespace handling
###############################################################################

load_namespace() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
  NAMESPACE="${NAMESPACE:-$DEFAULT_NS}"
}

save_namespace() {
  local ns="$1"
  echo "NAMESPACE=${ns}" > "$CONFIG_FILE"
}

###############################################################################
# Usage
###############################################################################

usage() {
  cat <<EOF
kk - Kubernetes Power Helper CLI (wrapper around kubectl)

Usage:
  kk ns [show|set <namespace>]              Manage saved namespace
  kk pods [name-substring]                  List pods (optional regex filter)
  kk svc [name-substring]                   List services (optional regex filter)
  kk sh <name-substring> [-- COMMAND...]    Exec into matching pod
  kk logs <name-substring> [-c ...] [...]   Stream logs from pods (with filters)
  kk images <name-substring>                Show container images for pod(s)
  kk restart <deploy-pattern>               Rollout restart matching deployment
  kk pf <pod-pattern> <local:remote>        Port-forward to matching pod
  kk desc <pod-pattern>                     Describe a pod
  kk top [pattern]                          Show resource usage (optional filter)
  kk events                                 List recent namespace events
  kk deploys                                Summarize deployments in namespace
  kk ctx [context]                          Show or switch kubectl contexts

Notes:
  - Uses current namespace from ${CONFIG_FILE} (default: ${DEFAULT_NS})
  - <name-substring> is used as a regex against pod names
  - kk is a thin wrapper: all real work is done by kubectl
EOF
}

###############################################################################
# Commands
###############################################################################

cmd_ns() {
  load_namespace
  local action="${1:-show}"
  case "$action" in
    show)
      echo "Current namespace: ${NAMESPACE}"
      ;;
    set)
      local ns="${2:-}"
      if [[ -z "$ns" ]]; then
        echo "Usage: kk ns set <namespace>" >&2
        exit 1
      fi
      save_namespace "$ns"
      echo "Set namespace to: ${ns}"
      ;;
    *)
      echo "Unknown ns action: $action" >&2
      exit 1
      ;;
  esac
}

cmd_pods() {
  load_namespace
  local pattern="${1:-}"
  if [[ -z "$pattern" ]]; then
    kubectl get pods -n "$NAMESPACE"
  else
    # keep header row (NR==1) and filter pod name column by regex
    kubectl get pods -n "$NAMESPACE" | awk 'NR==1 || $1 ~ /'"$pattern"'/' 
  fi
}

cmd_svc() {
  load_namespace
  local pattern="${1:-}"

  local output
  if ! output=$(kubectl get svc -n "$NAMESPACE"); then
    return $?
  fi

  if [[ -z "$pattern" ]]; then
    printf "%s\n" "$output"
  else
    awk 'NR==1 || $1 ~ /'"$pattern"'/' <<< "$output"
  fi
}

select_pod_by_pattern() {
  local pattern="$1"
  load_namespace

  # list pod names and grep by pattern
  local pods
  pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$pattern" || true)

  if [[ -z "$pods" ]]; then
    echo "No pods found matching pattern: $pattern" >&2
    return 1
  fi

  local count
  count=$(printf "%s\n" "$pods" | wc -l | tr -d ' ')

  if [[ "$count" -eq 1 ]]; then
    printf "%s" "$pods"
    return 0
  fi

  # multiple pods: pick via fzf if available, otherwise ask user
  if command -v fzf >/dev/null 2>&1; then
    printf "%s\n" "$pods" | fzf --prompt="Select pod> "
  else
    echo "Multiple pods found:" >&2
    nl -ba <<< "$pods" >&2
    echo -n "Select index: " >&2
    local idx
    read -r idx
    local selected
    selected=$(nl -ba <<< "$pods" | awk -v i="$idx" '$1 == i { $1=""; sub(/^ /,""); print }')
    if [[ -z "$selected" ]]; then
      echo "Invalid selection" >&2
      return 1
    fi
    printf "%s" "$selected"
  fi
}

select_deploy_by_pattern() {
  local pattern="$1"
  load_namespace

  local deploys
  deploys=$(kubectl get deploy -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$pattern" || true)

  if [[ -z "$deploys" ]]; then
    echo "No deployments found matching pattern: $pattern" >&2
    return 1
  fi

  local count
  count=$(printf "%s\n" "$deploys" | wc -l | tr -d ' ')

  if [[ "$count" -eq 1 ]]; then
    printf "%s" "$deploys"
    return 0
  fi

  if command -v fzf >/dev/null 2>&1; then
    printf "%s\n" "$deploys" | fzf --prompt="Select deployment> "
  else
    echo "Multiple deployments found:" >&2
    nl -ba <<< "$deploys" >&2
    echo -n "Select index: " >&2
    local idx
    read -r idx
    local selected
    selected=$(nl -ba <<< "$deploys" | awk -v i="$idx" '$1 == i { $1=""; sub(/^ /,""); print }')
    if [[ -z "$selected" ]]; then
      echo "Invalid selection" >&2
      return 1
    fi
    printf "%s" "$selected"
  fi
}

cmd_sh() {
  local pattern="${1:-}"
  shift || true

  if [[ -z "$pattern" ]]; then
    echo "Usage: kk sh <name-substring> [-- COMMAND...]" >&2
    exit 1
  fi

  local pod
  pod=$(select_pod_by_pattern "$pattern") || exit 1
  load_namespace

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if [[ "$#" -eq 0 ]]; then
    set -- /bin/sh
  fi

  echo "Exec into pod: $pod (namespace: $NAMESPACE)" >&2
  kubectl exec -ti -n "$NAMESPACE" "$pod" -- "$@"
}

cmd_logs() {
  load_namespace

  if [[ $# -lt 1 ]]; then
    echo "Usage: kk logs <name-substring> [-c container] [-g pattern] [-f] [-- extra kubectl logs args]" >&2
    exit 1
  fi

  local pattern="$1"
  shift

  local container=""
  local grep_pattern=""
  local follow="false"
  local extra_args=()

  # parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--container)
        container="$2"; shift 2 ;;
      -g|--grep)
        grep_pattern="$2"; shift 2 ;;
      -f|--follow)
        follow="true"; shift ;;
      --)
        shift
        extra_args+=("$@")
        break
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  local pods
  pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$pattern" || true)

  if [[ -z "$pods" ]]; then
    echo "No pods found matching pattern: $pattern" >&2
    exit 1
  fi

  echo "Streaming logs from pods (namespace: $NAMESPACE):" >&2
  printf "%s\n" "$pods" >&2

  # stream logs, prefix with pod name, then optional grep
  if [[ "$follow" == "true" ]]; then
    for p in $pods; do
      (
        args=(logs -n "$NAMESPACE" "$p" -f)
        [[ -n "$container" ]] && args+=("-c" "$container")
        args+=("${extra_args[@]}")
        kubectl "${args[@]}" 2>&1 | sed "s/^/[$p] /"
      ) &
    done
    wait
  else
    for p in $pods; do
      args=(logs -n "$NAMESPACE" "$p")
      [[ -n "$container" ]] && args+=("-c" "$container")
      args+=("${extra_args[@]}")
      echo "==== pod: $p ====" >&2
      kubectl "${args[@]}" 2>&1 | sed "s/^/[$p] /"
    done
  fi | {
    if [[ -n "$grep_pattern" ]]; then
      grep --line-buffered -E "$grep_pattern" || true
    else
      cat
    fi
  }
}

cmd_images() {
  load_namespace

  if [[ $# -lt 1 ]]; then
    echo "Usage: kk images <name-substring>" >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for 'kk images'. Please install jq." >&2
    exit 1
  fi

  local pattern="$1"

  local pods
  pods=$(kubectl get pods -n "$NAMESPACE" -o json | \
    jq -r --arg p "$pattern" '.items[] | select(.metadata.name | test($p)) | .metadata.name')

  if [[ -z "$pods" ]]; then
    echo "No pods found matching: $pattern" >&2
    exit 1
  fi

  for pod in $pods; do
    echo "Pod: $pod"
    kubectl get pod "$pod" -n "$NAMESPACE" -o json | \
      jq -r '
        .spec.containers[] |
        "  - \(.name): \(.image)"
      '
    echo
  done
}

cmd_restart() {
  load_namespace

  local pattern="${1:-}"
  if [[ -z "$pattern" ]]; then
    echo "Usage: kk restart <deploy-pattern>" >&2
    exit 1
  fi

  local deploy
  deploy=$(select_deploy_by_pattern "$pattern") || exit 1

  echo "Restarting deployment: $deploy (namespace: $NAMESPACE)" >&2
  kubectl rollout restart "deploy/$deploy" -n "$NAMESPACE"
}

cmd_pf() {
  load_namespace

  if [[ $# -lt 2 ]]; then
    echo "Usage: kk pf <pod-pattern> <local:remote>" >&2
    exit 1
  fi

  local pattern="$1"
  local port_spec="$2"
  shift 2

  local pod
  pod=$(select_pod_by_pattern "$pattern") || exit 1

  local extra_args=("$@")
  echo "Port-forwarding pod: $pod (namespace: $NAMESPACE) on $port_spec" >&2
  kubectl port-forward -n "$NAMESPACE" "$pod" "$port_spec" "${extra_args[@]}"
}

cmd_desc() {
  load_namespace

  if [[ $# -lt 1 ]]; then
    echo "Usage: kk desc <pod-pattern>" >&2
    exit 1
  fi

  local pattern="$1"
  local pod
  pod=$(select_pod_by_pattern "$pattern") || exit 1

  kubectl describe pod "$pod" -n "$NAMESPACE"
}

cmd_top() {
  load_namespace
  local pattern="${1:-}"

  local output
  if ! output=$(kubectl top pod -n "$NAMESPACE"); then
    return $?
  fi

  if [[ -z "$pattern" ]]; then
    printf "%s\n" "$output"
  else
    awk 'NR==1 || $1 ~ /'"$pattern"'/' <<< "$output"
  fi
}

cmd_events() {
  load_namespace

  if ! kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp; then
    kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp
  fi
}

cmd_deploys() {
  load_namespace

  if command -v jq >/dev/null 2>&1; then
    local json
    if ! json=$(kubectl get deploy -n "$NAMESPACE" -o json); then
      return $?
    fi

    local lines
    lines=$(jq -r '
      .items[]? |
      [
        .metadata.name,
        (.status.readyReplicas // 0 | tostring),
        (.spec.replicas // 0 | tostring),
        (.spec.template.spec.containers[0].image // "n/a")
      ] | @tsv
    ' <<< "$json")

    if [[ -z "$lines" ]]; then
      echo "No deployments found in namespace: $NAMESPACE"
      return 0
    fi

    printf "%-30s %-10s %s\n" "NAME" "READY" "IMAGE"
    while IFS=$'\t' read -r name ready desired image; do
      printf "%-30s %s/%s  image: %s\n" "$name" "$ready" "$desired" "$image"
    done <<< "$lines"
  else
    kubectl get deploy -n "$NAMESPACE"
  fi
}

cmd_ctx() {
  local context="${1:-}"

  if [[ -z "$context" ]]; then
    kubectl config get-contexts
  else
    if kubectl config use-context "$context"; then
      echo "Switched to context: $context"
    fi
  fi
}

###############################################################################
# Main
###############################################################################

main() {
  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 0
  fi
  shift

  case "$cmd" in
    ns)      cmd_ns "$@" ;;
    pods)    cmd_pods "$@" ;;
    svc)     cmd_svc "$@" ;;
    sh|shell) cmd_sh "$@" ;;
    logs)    cmd_logs "$@" ;;
    images)  cmd_images "$@" ;;
    restart) cmd_restart "$@" ;;
    pf)      cmd_pf "$@" ;;
    desc)    cmd_desc "$@" ;;
    top)     cmd_top "$@" ;;
    events)  cmd_events "$@" ;;
    deploys) cmd_deploys "$@" ;;
    ctx)     cmd_ctx "$@" ;;
    -h|--help|help) usage ;;
    *)
      echo "Unknown subcommand: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
