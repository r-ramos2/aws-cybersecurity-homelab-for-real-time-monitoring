#!/usr/bin/env bash
# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts.

set -euo pipefail

# Path or URL to the Nessus .deb package.
NESSUS_DEB="Nessus-10.3.0-debian6_amd64.deb"

echo "[INFO] Installing Nessus Essentials package..."
sudo dpkg -i "$NESSUS_DEB"

echo "[INFO] Enabling and starting Nessus service..."
sudo systemctl enable nessusd
sudo systemctl start nessusd

echo "[INFO] Nessus is now running."
