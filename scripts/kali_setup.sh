#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Minimal install of XFCE and XRDP for Kali
apt-get update && apt-get -y full-upgrade
apt-get -y install --no-install-recommends kali-desktop-xfce xorg xrdp

# Ensure xrdp runs
systemctl enable --now xrdp

# Harden basic XRDP config (disable clipboard redirection as an example)
XRDP_CFG="/etc/xrdp/xrdp.ini"
if [ -f "$XRDP_CFG" ]; then
  # Conservative edit; adapt as needed for your environment.
  sed -i 's/clipboard=1/clipboard=0/g' "$XRDP_CFG" || true
  systemctl restart xrdp
fi

echo "[INFO] Kali setup complete. XRDP enabled."
