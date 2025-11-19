AGENTS.md

Project Name

kk – Kubernetes Power Helper CLI

Goal

kk is a lightweight wrapper CLI around kubectl designed to boost
developer productivity, reduce typing, and provide intuitive shortcuts
for routine Kubernetes operations.

Unlike kubectl plugins, kk is a single executable script that focuses
on: - short commands - smart pod pattern matching - automatic namespace
handling - multi-pod log streaming - fast troubleshooting workflows

Codex should assist in extending and maintaining this tool following the
philosophy below.

Philosophy

1.  Simplicity first
2.  Smart automation
3.  Avoid abstraction leakage
4.  Safe defaults
5.  Unix-style output

Current Commands

- kk ns show / kk ns set      – manage namespace persisted in ~/.kk
- kk pods [pattern]           – list pods (regex filter optional)
- kk sh <pattern> [-- cmd]    – exec into a pod
- kk logs <pattern> [...]     – stream logs with optional filters
- kk images <pattern>         – list pod container images (requires jq)
- kk restart <pattern>        – rollout restart a deployment
- kk pf <pattern> <portspec>  – port-forward to a pod
- kk desc <pattern>           – describe a pod
- kk top [pattern]            – show pod resource usage
- kk events                   – list recent namespace events
- kk deploys                  – summarize deployments (jq-enhanced)
- kk ctx [context]            – show or switch kubectl contexts

Planned Commands

(Only when explicitly requested) - kk kill  - kk yaml  - kk resources

Design Rules

1.  Single script.
2.  Use only bash + kubectl + jq (optional).
3.  No heavy dependencies.
4.  Commands implemented as cmd_().
5.  Namespace always respected.
6.  Clear error messages.
7.  No silent behavior changes.

Allowed Tasks for Codex

-   Implement new subcommands (when asked)
-   Refactor
-   Fix bugs
-   Update documentation
-   Extend functionality (only when asked)

Forbidden Actions

-   Adding features not requested
-   Breaking backward compatibility
-   Replacing kubectl logic
-   Adding heavy external dependencies

Output Format Requirements

-   Provide clean diff or minimal replacements
-   No rewriting entire script unless necessary

User Interaction Rules

Ask for clarification when unsure.
