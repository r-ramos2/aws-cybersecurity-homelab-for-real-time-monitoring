#!/usr/bin/env bash
# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Versioned filename for clarity
NESSUS_VERSION="10.3.0"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"
DOWNLOAD_URL="https://www.tenable.com/downloads/api/v2/pages/nessus/files/${NESSUS_PKG}"

# Download the Nessus package if not already present
if [ ! -f "$NESSUS_PKG" ]; then
  echo "[INFO] Downloading Nessus Essentials package..."
  wget -q "$DOWNLOAD_URL" -O "$NESSUS_PKG"
else
  echo "[INFO] Nessus package already downloaded."
fi

echo "[INFO] Installing Nessus Essentials package..."
sudo dpkg -i "$NESSUS_PKG" || {
  echo "[WARN] dpkg reported missing dependencies, attempting to fix..."
  sudo apt-get install -f -y
}

echo "[INFO] Enabling and starting Nessus service..."
sudo systemctl enable nessusd
sudo systemctl restart nessusd

echo "[INFO] Nessus is now running on https://$(hostname -I | awk '{print $1}'):8834"
