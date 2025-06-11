#!/usr/bin/env bash
# rdp.sh
# Installs Xfce and XRDP for remote desktop access on Kali Linux.

set -euo pipefail

echo "[INFO] Updating and upgrading system packages..."
sudo apt-get update && sudo apt-get full-upgrade -y

echo "[INFO] Installing Xfce4 desktop and XRDP..."
sudo apt-get install -y kali-desktop-xfce xorg xrdp

echo "[INFO] Enabling and starting XRDP service..."
sudo systemctl enable xrdp
sudo systemctl start xrdp

echo "[INFO] XRDP is running on TCP port 3389."
