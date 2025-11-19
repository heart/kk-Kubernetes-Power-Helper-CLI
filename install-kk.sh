#!/usr/bin/env bash
#
# install-kk.sh - Installer for kk (Kubernetes Power Helper CLI)
#
# Run as root or via:  sudo bash install-kk.sh
#

set -euo pipefail

KK_URL_DEFAULT="https://raw.githubusercontent.com/heart/kk-Kubernetes-Power-Helper-CLI/main/kk"
INSTALL_PATH_DEFAULT="/usr/local/bin/kk"

KK_URL="${KK_URL:-$KK_URL_DEFAULT}"
INSTALL_PATH="${INSTALL_PATH:-$INSTALL_PATH_DEFAULT}"

echo "[kk-installer] Using source URL:    $KK_URL"
echo "[kk-installer] Target install path: $INSTALL_PATH"

if [[ "$EUID" -ne 0 ]]; then
  echo "[kk-installer] ERROR: Please run this script as root, e.g.:"
  echo "  sudo bash install-kk.sh"
  exit 1
fi

TMP_FILE="$(mktemp /tmp/kk.XXXXXX)"

cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT

LOCAL_SOURCE=""
if [[ "$KK_URL" == file://* ]]; then
  LOCAL_SOURCE="${KK_URL#file://}"
elif [[ -f "$KK_URL" ]]; then
  LOCAL_SOURCE="$KK_URL"
fi

if [[ -n "$LOCAL_SOURCE" ]]; then
  echo "[kk-installer] Using local kk source: $LOCAL_SOURCE"
  cp "$LOCAL_SOURCE" "$TMP_FILE"
else
  echo "[kk-installer] Downloading kk ..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$KK_URL" -o "$TMP_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$KK_URL" -O "$TMP_FILE"
  else
    echo "[kk-installer] ERROR: curl or wget is required to download kk."
    exit 1
  fi
fi

if [[ ! -s "$TMP_FILE" ]]; then
  echo "[kk-installer] ERROR: Downloaded file is empty. Aborting."
  exit 1
fi

if [[ -e "$INSTALL_PATH" || -L "$INSTALL_PATH" ]]; then
  BACKUP_PATH="${INSTALL_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  echo "[kk-installer] Existing kk found at $INSTALL_PATH"
  echo "[kk-installer] Backing up to $BACKUP_PATH"
  mv "$INSTALL_PATH" "$BACKUP_PATH"
fi

INSTALL_DIR="$(dirname "$INSTALL_PATH")"
mkdir -p "$INSTALL_DIR"

echo "[kk-installer] Installing kk to $INSTALL_PATH ..."
mv "$TMP_FILE" "$INSTALL_PATH"

chown root:root "$INSTALL_PATH"
chmod 755 "$INSTALL_PATH"

echo "[kk-installer] Done."
echo "[kk-installer] kk is installed at: $INSTALL_PATH"
echo "[kk-installer] Try:  kk ns show  or  kk pods"
