#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Installs Xfce and XRDP for remote desktop access
if ! dpkg -l | grep -q xfce4; then
  echo "[INFO] Updating packages..."
  apt-get update && apt-get -y full-upgrade
  echo "[INFO] Installing Xfce4 and XRDP..."
  apt-get -y install --no-install-recommends xfce4 xorg xrdp
else
  echo "[INFO] XFCE4 already installed."
fi

systemctl enable --now xrdp

echo "[INFO] XRDP is running on TCP port 3389."
