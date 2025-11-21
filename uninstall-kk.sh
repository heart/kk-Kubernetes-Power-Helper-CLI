#!/usr/bin/env bash
#
# uninstall-kk.sh - Uninstaller for kk (Kubernetes Power Helper CLI)
#
# Run as root or via:  sudo bash uninstall-kk.sh
#

set -euo pipefail

INSTALL_PATH_DEFAULT="/usr/local/lib/kk.sh"
PROFILE_SNIPPET_DEFAULT="/etc/profile.d/kk.sh"

INSTALL_PATH="${INSTALL_PATH:-$INSTALL_PATH_DEFAULT}"
PROFILE_SNIPPET="${PROFILE_SNIPPET:-$PROFILE_SNIPPET_DEFAULT}"

echo "[kk-uninstall] Target install path: $INSTALL_PATH"
echo "[kk-uninstall] Profile snippet:     $PROFILE_SNIPPET"

if [[ "$EUID" -ne 0 ]]; then
  echo "[kk-uninstall] ERROR: Please run this script as root, e.g.:"
  echo "  sudo bash uninstall-kk.sh"
  exit 1
fi

# Remove kk script
if [[ -e "$INSTALL_PATH" || -L "$INSTALL_PATH" ]]; then
  echo "[kk-uninstall] Removing kk script at: $INSTALL_PATH"
  rm -f "$INSTALL_PATH"
else
  echo "[kk-uninstall] No kk script found at: $INSTALL_PATH (nothing to remove)"
fi

# Remove profile snippet
if [[ -e "$PROFILE_SNIPPET" || -L "$PROFILE_SNIPPET" ]]; then
  echo "[kk-uninstall] Removing profile snippet at: $PROFILE_SNIPPET"
  rm -f "$PROFILE_SNIPPET"
else
  echo "[kk-uninstall] No profile snippet found at: $PROFILE_SNIPPET (nothing to remove)"
fi

echo "[kk-uninstall] Done."
echo "[kk-uninstall] If you manually added 'source $INSTALL_PATH' to your ~/.bashrc or ~/.zshrc,"
echo "[kk-uninstall] please remove that line as well."
echo "[kk-uninstall] Open a new shell to ensure kk() is no longer loaded."
