#!/usr/bin/env bash
# rdp.sh
# Installs Xfce and XRDP for remote desktop access on Kali Linux.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! dpkg -l | grep -q xfce4; then
  echo "[INFO] Updating and upgrading system packages..."
  sudo apt-get update && sudo apt-get full-upgrade -y

  echo "[INFO] Installing Xfce4 desktop and XRDP..."
  sudo apt-get install -y kali-desktop-xfce xorg xrdp
else
  echo "[INFO] XFCE4 already installed, skipping package install."
fi

echo "[INFO] Enabling and starting XRDP service..."
sudo systemctl enable xrdp
sudo systemctl restart xrdp

echo "[INFO] XRDP is running on TCP port 3389."
