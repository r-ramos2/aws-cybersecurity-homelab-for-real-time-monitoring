#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[INFO] Updating system..."
apt-get update && apt-get -y full-upgrade

echo "[INFO] Installing XFCE and XRDP..."
if ! dpkg -l | grep -q xfce4; then
    apt-get -y install --no-install-recommends kali-desktop-xfce xorg xfce4 xrdp
else
    echo "[INFO] XFCE already installed."
fi

echo "[INFO] Enabling XRDP service..."
systemctl enable --now xrdp

# Harden XRDP config (disable clipboard redirection)
XRDP_CFG="/etc/xrdp/xrdp.ini"
if [ -f "$XRDP_CFG" ]; then
    sed -i 's/clipboard=1/clipboard=0/g' "$XRDP_CFG" || true
    systemctl restart xrdp
fi

echo "[INFO] Kali setup complete. XRDP running on TCP port 3389."
