#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts (non-interactive)
# Update NESSUS_VERSION as needed before running.

NESSUS_VERSION="10.3.0"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"
DOWNLOAD_URL="https://www.tenable.com/downloads/api/v2/pages/nessus/files/${NESSUS_PKG}"

# Work in /tmp to avoid clutter
cd /tmp

if [ ! -f "$NESSUS_PKG" ]; then
  echo "[INFO] Downloading Nessus package..."
  if ! wget -q "$DOWNLOAD_URL" -O "$NESSUS_PKG"; then
    echo "[ERROR] Failed to download Nessus package. Check URL or registration requirements." >&2
    exit 1
  fi
else
  echo "[INFO] Nessus package already present."
fi

echo "[INFO] Installing Nessus package..."
if ! dpkg -i "$NESSUS_PKG"; then
  echo "[WARN] dpkg reported missing deps; attempting to fix..."
  apt-get update
  apt-get install -f -y
fi

systemctl enable --now nessusd || true

# Wait for service to become active
sleep 5

IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo "[INFO] Nessus should be accessible at: https://$IP_ADDR:8834"
else
  echo "[INFO] Nessus installed. Check https://<TOOLS_PUBLIC_IP>:8834"
fi
