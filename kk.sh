#!/usr/bin/env bash
# kk - Kubernetes helper CLI (function wrapper around kubectl for daily Dev/DevOps workflows).
#
# Usage (install):
#   1) Save this file as ~/kk.sh
#   2) Add to your ~/.bashrc or ~/.zshrc:
#        source ~/kk.sh
#   3) Open a new shell, then call:
#        kk ns set my-namespace
#        kk pods
#
# Each shell (tmux pane/window) has its own KK_NAMESPACE variable,
# so switching namespace in one shell will NOT affect the others.

DEFAULT_NS="default"
: "${KK_NAMESPACE:=$DEFAULT_NS}"

###############################################################################
# Helpers
###############################################################################

_kk_current_namespace() {
  printf '%s\n' "${KK_NAMESPACE:-$DEFAULT_NS}"
}

kk_usage() {
  cat <<EOF
kk - Kubernetes Power Helper CLI (wrapper around kubectl)

Usage:
  kk ns [show|set <namespace>|list]         Manage namespace in this shell (list uses interactive picker)
  kk pods [name-substring]                  List pods (optional regex filter)
  kk svc [name-substring]                   List services (optional regex filter)
  kk sh <name-substring> [-- COMMAND...]    Exec into matching pod
  kk logs <name-substring> [-c ...] [...]   Stream logs from pods (with filters)
  kk images <name-substring>                Show container images for pod(s)
  kk restart <deploy-pattern>               Rollout restart matching deployment
  kk pf <pod-pattern> <local:remote>        Port-forward to matching pod
  kk desc <pod-pattern>                     Describe a pod
  kk top [pattern]                          Show resource usage (optional filter)
  kk ctx [list|use|show] [...]              Manage kubectl contexts (list/use/show details)
  kk events                                 List recent namespace events
  kk deploys                                Summarize deployments in namespace

Notes:
  - Namespace is stored in shell variable KK_NAMESPACE (default: ${DEFAULT_NS})
  - Each shell / tmux pane has its own KK_NAMESPACE
  - <name-substring> is used as a regex against pod names
  - kk is a thin wrapper: all real work is done by kubectl
EOF
}

select_pod_by_pattern() {
  local pattern="$1"
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  # list pod names and grep by pattern
  local pods
  pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -E -- "$pattern" || true)

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
    printf "%s\n" "$pods" | fzf --height=40% --border --prompt="Select pod> "
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
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  local deploys
  deploys=$(kubectl get deploy -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -E -- "$pattern" || true)

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
    printf "%s\n" "$deploys" | fzf --height=40% --border --prompt="Select deployment> "
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

###############################################################################
# Subcommand implementations
###############################################################################

kk_cmd_ns() {
  local action="${1:-show}"
  case "$action" in
    show)
      echo "Current namespace: ${KK_NAMESPACE:-$DEFAULT_NS}"
      ;;
    set)
      local ns="${2:-}"
      if [[ -z "$ns" ]]; then
        echo "Usage: kk ns set <namespace>" >&2
        return 1
      fi
      KK_NAMESPACE="$ns"
      echo "Set namespace to: ${KK_NAMESPACE}"
      ;;
    list)
      local namespaces selected
      if ! namespaces=$(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); then
        echo "Failed to list namespaces via kubectl" >&2
        return 1
      fi
      if [[ -z "$namespaces" ]]; then
        echo "No namespaces returned by cluster" >&2
        return 1
      fi
      if command -v fzf >/dev/null 2>&1; then
        local header="Select namespace to set for this shell (current: ${KK_NAMESPACE:-$DEFAULT_NS})"
        selected=$(printf "%s\n" "$namespaces" | fzf --height=40% --border --prompt="ns> " --header="$header")
      else
        echo "Select the namespace to use in this shell (current: ${KK_NAMESPACE:-$DEFAULT_NS})" >&2
        echo "Available namespaces:" >&2
        nl -ba <<< "$namespaces" >&2
        echo -n "Select index: " >&2
        local idx
        read -r idx
        selected=$(nl -ba <<< "$namespaces" | awk -v i="$idx" '$1 == i { $1=""; sub(/^ /,""); print }')
      fi
      if [[ -z "$selected" ]]; then
        echo "No namespace selected" >&2
        return 1
      fi
      KK_NAMESPACE="$selected"
      echo "Set namespace to: ${KK_NAMESPACE}"
      ;;
    *)
      echo "Unknown ns action: $action" >&2
      return 1
      ;;
  esac
}

kk_cmd_pods() {
  local pattern="${1:-}"
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ -z "$pattern" ]]; then
    kubectl get pods -n "$NAMESPACE"
  else
    kubectl get pods -n "$NAMESPACE" | awk -v p="$pattern" 'NR==1 || $1 ~ p'
  fi
}

kk_cmd_svc() {
  local pattern="${1:-}"
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  local output
  if ! output=$(kubectl get svc -n "$NAMESPACE"); then
    return $?
  fi

  if [[ -z "$pattern" ]]; then
    printf "%s\n" "$output"
  else
    awk -v p="$pattern" 'NR==1 || $1 ~ p' <<< "$output"
  fi
}

kk_cmd_sh() {
  local pattern="${1:-}"
  shift || true

  if [[ -z "$pattern" ]]; then
    echo "Usage: kk sh <name-substring> [-- COMMAND...]" >&2
    return 1
  fi

  local pod
  pod=$(select_pod_by_pattern "$pattern") || return 1
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if [[ "$#" -eq 0 ]]; then
    set -- /bin/sh
  fi

  echo "Exec into pod: $pod (namespace: $NAMESPACE)" >&2
  kubectl exec -ti -n "$NAMESPACE" "$pod" -- "$@"
}

kk_cmd_logs() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ $# -lt 1 ]]; then
    echo "Usage: kk logs <name-substring> [-c container] [-g pattern] [-f] [-- extra kubectl logs args]" >&2
    return 1
  fi

  local pattern="$1"
  shift

  local container=""
  local grep_pattern=""
  local follow="false"
  local extra_args=()

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
  pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -E -- "$pattern" || true)

  if [[ -z "$pods" ]]; then
    echo "No pods found matching pattern: $pattern" >&2
    return 1
  fi

  echo "Streaming logs from pods (namespace: $NAMESPACE):" >&2
  printf "%s\n" "$pods" >&2

  if [[ "$follow" == "true" ]]; then
    for p in $pods; do
      (
        args=(logs -n "$NAMESPACE" "$p" -f)
        [[ -n "$container" ]] && args+=("-c" "$container")
        args+=("${extra_args[@]}")
        kubectl "${args[@]}" 2>&1 | sed -u "s/^/[$p] /"
      ) &
    done
    wait
  else
    for p in $pods; do
      args=(logs -n "$NAMESPACE" "$p")
      [[ -n "$container" ]] && args+=("-c" "$container")
      args+=("${extra_args[@]}")
      echo "==== pod: $p ====" >&2
      kubectl "${args[@]}" 2>&1 | sed -u "s/^/[$p] /"
    done
  fi | {
    if [[ -n "$grep_pattern" ]]; then
      grep --line-buffered -E -- "$grep_pattern" || true
    else
      cat
    fi
  }
}

kk_cmd_images() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ $# < 1 ]]; then
    echo "Usage: kk images <name-substring>" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for 'kk images'. Please install jq." >&2
    return 1
  fi

  local pattern="$1"

  local pods
  pods=$(kubectl get pods -n "$NAMESPACE" -o json | \
    jq -r --arg p "$pattern" '.items[]? | select(.metadata.name? | test($p)) | .metadata.name')

  if [[ -z "$pods" ]]; then
    echo "No pods found matching: $pattern" >&2
    return 1
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

kk_cmd_restart() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  local pattern="${1:-}"
  if [[ -z "$pattern" ]]; then
    echo "Usage: kk restart <deploy-pattern>" >&2
    return 1
  fi

  local deploy
  deploy=$(select_deploy_by_pattern "$pattern") || return 1

  echo "Restarting deployment: $deploy (namespace: $NAMESPACE)" >&2
  kubectl rollout restart "deploy/$deploy" -n "$NAMESPACE"
}

kk_cmd_pf() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ $# -lt 2 ]]; then
    echo "Usage: kk pf <pod-pattern> <local:remote>" >&2
    return 1
  fi

  local pattern="$1"
  local port_spec="$2"
  shift 2

  local pod
  pod=$(select_pod_by_pattern "$pattern") || return 1

  local extra_args=("$@")
  echo "Port-forwarding pod: $pod (namespace: $NAMESPACE) on $port_spec" >&2
  kubectl port-forward -n "$NAMESPACE" "$pod" "$port_spec" "${extra_args[@]}" || {
    echo "Port-forward failed (port in use, pod restarting, or network issue)" >&2
    return 1
  }
}

kk_cmd_desc() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if [[ $# -lt 1 ]]; then
    echo "Usage: kk desc <pod-pattern>" >&2
    return 1
  fi

  local pattern="$1"
  local pod
  pod=$(select_pod_by_pattern "$pattern") || return 1

  kubectl describe pod "$pod" -n "$NAMESPACE"
}

kk_cmd_top() {
  local pattern="${1:-}"
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  local output
  if ! output=$(kubectl top pod -n "$NAMESPACE"); then
    return $?
  fi

  if [[ -z "$pattern" ]]; then
    printf "%s\n" "$output"
  else
    awk -v p="$pattern" 'NR==1 || $1 ~ p' <<< "$output"
  fi
}

kk_cmd_events() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

  if ! kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp; then
    kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp
  fi
}

kk_cmd_deploys() {
  local NAMESPACE
  NAMESPACE=$(_kk_current_namespace)

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

kk_cmd_ctx() {
  local action="${1:-}"

  if [[ -z "$action" ]]; then
    kubectl config get-contexts
    return
  fi

  case "$action" in
    list)
      shift || true
      if [[ "$#" -gt 0 ]]; then
        echo "Usage: kk ctx list" >&2
        return 1
      fi
      kubectl config get-contexts
      ;;
    use)
      shift || true
      local context="${1:-}"
      if [[ -z "$context" ]]; then
        echo "Usage: kk ctx use <context>" >&2
        return 1
      fi
      kubectl config use-context "$context" \
        && echo "Switched to context: $context" \
        || { echo "Failed to switch context: $context" >&2; return 1; }
      ;;
    show|info|details)
      shift || true
      local context="${1:-}"
      if [[ -z "$context" ]]; then
        if ! context="$(kubectl config current-context 2>/dev/null)"; then
          echo "Failed to determine current context." >&2
          return 1
        fi
      else
        shift || true
        if [[ "$#" -gt 0 ]]; then
          echo "Usage: kk ctx show [context]" >&2
          return 1
        fi
      fi
      kubectl config view --minify --context "$context" || {
        echo "Failed to show details for context: $context" >&2
        return 1
      }
      ;;
    *)
      # Backwards compatibility: treat argument as context name to switch to.
      kubectl config use-context "$action" \
        && echo "Switched to context: $action" \
        || { echo "Failed to switch context: $action" >&2; return 1; }
      ;;
  esac
}

###############################################################################
# kk function (entry point)
###############################################################################

kk() {
  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    kk_usage
    return 0
  fi
  shift || true

  case "$cmd" in
    ns|namespace)             kk_cmd_ns "$@" ;;
    pods|pod|po)              kk_cmd_pods "$@" ;;
    svc|service|services)     kk_cmd_svc "$@" ;;
    sh|shell|exec)            kk_cmd_sh "$@" ;;
    logs|log)                 kk_cmd_logs "$@" ;;
    images|img)               kk_cmd_images "$@" ;;
    restart|rollout)          kk_cmd_restart "$@" ;;
    pf|port-forward|portforward) kk_cmd_pf "$@" ;;
    desc|describe)            kk_cmd_desc "$@" ;;
    top|usage|resources)      kk_cmd_top "$@" ;;
    events|event)             kk_cmd_events "$@" ;;
    deploys|deploy|deployments) kk_cmd_deploys "$@" ;;
    ctx|context|contexts)     kk_cmd_ctx "$@" ;;
    -h|--help|help) kk_usage ;;
    *)
      echo "Unknown subcommand: $cmd" >&2
      kk_usage
      return 1
      ;;
  esac
}
