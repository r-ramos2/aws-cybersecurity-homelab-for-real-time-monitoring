#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Opt-in clipboard redirection for XRDP
# Default: 0 (disabled). To enable: XRDP_ALLOW_CLIPBOARD=1 bash kali_setup.sh
XRDP_ALLOW_CLIPBOARD="${XRDP_ALLOW_CLIPBOARD:-0}"

echo "[INFO] Updating system..."
apt-get update && apt-get -y full-upgrade

echo "[INFO] Installing XFCE and XRDP (if not present)..."
if ! dpkg -l | grep -q xfce4; then
  # Small retry loop for apt install (transient network issues happen)
  for i in 1 2 3; do
    if apt-get -y install --no-install-recommends kali-desktop-xfce xorg xfce4 xrdp; then
      break
    fi
    echo "[WARN] Install attempt $i failed. Retrying in 5s..."
    sleep 5
  done
else
  echo "[INFO] XFCE already installed."
fi

echo "[INFO] Enabling XRDP service..."
systemctl enable --now xrdp

# XRDP clipboard handling
XRDP_CFG="/etc/xrdp/xrdp.ini"
if [ -f "$XRDP_CFG" ]; then
  if [ "$XRDP_ALLOW_CLIPBOARD" = "1" ]; then
    echo "[INFO] Enabling clipboard redirection per XRDP_ALLOW_CLIPBOARD=1"
    sed -i 's/clipboard=0/clipboard=1/g' "$XRDP_CFG" || true
  else
    echo "[INFO] Disabling clipboard redirection (secure default). To enable set XRDP_ALLOW_CLIPBOARD=1"
    sed -i 's/clipboard=1/clipboard=0/g' "$XRDP_CFG" || true
  fi
  systemctl restart xrdp
fi

echo "[INFO] Kali setup complete. XRDP running on TCP port 3389."
echo "If you require clipboard access, rerun the script with XRDP_ALLOW_CLIPBOARD=1"
