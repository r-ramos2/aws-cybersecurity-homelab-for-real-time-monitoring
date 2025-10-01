#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts (non-interactive)
# Update NESSUS_VERSION as needed before running.

NESSUS_VERSION="10.3.0"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"
NESSUS_DOWNLOAD_URL="${NESSUS_DOWNLOAD_URL:-https://www.tenable.com/downloads/api/v2/pages/nessus/files/${NESSUS_PKG}}"

# Work in /tmp to avoid clutter
cd /tmp

# Download package if missing
if [ ! -f "$NESSUS_PKG" ]; then
  echo "[INFO] Downloading Nessus package..."
  for i in {1..3}; do
    if wget -q "$NESSUS_DOWNLOAD_URL" -O "$NESSUS_PKG"; then
      echo "[INFO] Nessus package downloaded successfully."
      break
    fi
    echo "[WARN] Download attempt $i failed. Retrying in 5s..."
    sleep 5
  done

  if [ ! -f "$NESSUS_PKG" ]; then
    echo "[ERROR] Failed to download Nessus package after retries."
    echo "Ensure you are registered with Tenable and the URL is correct:"
    echo "  $NESSUS_DOWNLOAD_URL"
    exit 1
  fi
else
  echo "[INFO] Nessus package already present."
fi

# Install package
echo "[INFO] Installing Nessus package..."
if ! dpkg -i "$NESSUS_PKG"; then
  echo "[WARN] dpkg reported missing dependencies; attempting to fix..."
  apt-get update
  apt-get install -f -y
fi

# Enable and start Nessus service
systemctl enable --now nessusd || true

# Poll for Nessus service readiness (max 60s)
echo "[INFO] Waiting for Nessus service to become active..."
for i in {1..12}; do
  if systemctl is-active --quiet nessusd; then
    echo "[OK] Nessus service is active."
    break
  fi
  sleep 5
done

# Display access URL
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo "[INFO] Nessus should be accessible at: https://$IP_ADDR:8834"
else
  echo "[INFO] Nessus installed. Check https://<TOOLS_PUBLIC_IP>:8834"
fi
