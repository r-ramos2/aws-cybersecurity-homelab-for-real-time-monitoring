#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# kali_setup.sh
# Installs XFCE desktop and XRDP on a Kali Linux host (non-interactive)
#
# Environment variables:
#   XRDP_ALLOW_CLIPBOARD=1   Enable clipboard redirection (default: disabled)
#   RDP_USER=<username>      Dedicated RDP user to create (default: rdpuser)
#   RDP_PASS=<password>      Password for the RDP user (required)

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] This script must be run as root (sudo)."
  exit 1
fi

# ── Configuration ─────────────────────────────────────────────────────────────
XRDP_ALLOW_CLIPBOARD="${XRDP_ALLOW_CLIPBOARD:-0}"
RDP_USER="${RDP_USER:-rdpuser}"
RDP_PASS="${RDP_PASS:-}"
XRDP_CFG="/etc/xrdp/xrdp.ini"

echo "[INFO] Kali XRDP Setup Script"
echo "=========================================="

# ── Public IP / port exposure warning ─────────────────────────────────────────
echo "[INFO] Checking for public IP exposure..."
PUBLIC_IP=$(curl -sf --max-time 5 https://checkip.amazonaws.com || true)
if [ -n "$PUBLIC_IP" ]; then
  echo "[WARN] Host has a public IP: ${PUBLIC_IP}"
  echo "[WARN] Ensure port 3389 is restricted to trusted sources in your firewall/security group."
  echo "[WARN] Exposing RDP publicly is a critical security risk."
fi

# ── System update ─────────────────────────────────────────────────────────────
echo "[INFO] Updating system packages..."
apt-get update && apt-get -y full-upgrade

# ── Install XFCE and XRDP ─────────────────────────────────────────────────────
echo "[INFO] Installing XFCE and XRDP (if not present)..."
if ! dpkg -l | grep -q xfce4; then
  for i in 1 2 3; do
    if apt-get -y install --no-install-recommends \
        kali-desktop-xfce xorg xfce4 xrdp openssl; then
      break
    fi
    echo "[WARN] Install attempt $i failed. Retrying in 5s..."
    sleep 5
  done
else
  echo "[INFO] XFCE already installed."
  # Ensure openssl is present for TLS cert generation
  apt-get -y install --no-install-recommends openssl
fi

# ── Dedicated RDP user ────────────────────────────────────────────────────────
echo "[INFO] Configuring dedicated RDP user: ${RDP_USER}"
if id "$RDP_USER" &>/dev/null; then
  echo "[INFO] User ${RDP_USER} already exists."
else
  useradd -m -s /bin/bash "$RDP_USER"
  echo "[INFO] Created user: ${RDP_USER}"
fi

if [ -z "$RDP_PASS" ]; then
  echo "[WARN] RDP_PASS not set. You must set a password manually before connecting:"
  echo "         passwd ${RDP_USER}"
else
  echo "${RDP_USER}:${RDP_PASS}" | chpasswd
  echo "[INFO] Password set for ${RDP_USER}."
fi

# Add to required groups for desktop session access (not sudo)
usermod -aG audio,video,plugdev "$RDP_USER" || true

# ── Enable XRDP service ───────────────────────────────────────────────────────
echo "[INFO] Enabling XRDP service..."
systemctl enable --now xrdp

# ── XRDP TLS configuration ────────────────────────────────────────────────────
echo "[INFO] Configuring XRDP TLS..."
XRDP_CERT="/etc/xrdp/cert.pem"
XRDP_KEY="/etc/xrdp/key.pem"

if [ ! -f "$XRDP_CERT" ] || [ ! -f "$XRDP_KEY" ]; then
  echo "[INFO] Generating self-signed TLS certificate for XRDP..."
  openssl req -x509 \
    -newkey rsa:4096 \
    -keyout "$XRDP_KEY" \
    -out "$XRDP_CERT" \
    -days 365 \
    -nodes \
    -subj "/CN=xrdp-$(hostname)" \
    2>/dev/null
  chmod 600 "$XRDP_KEY"
  chmod 644 "$XRDP_CERT"
  chown root:xrdp "$XRDP_KEY" 2>/dev/null || chown root:root "$XRDP_KEY"
  echo "[INFO] TLS certificate generated."
else
  echo "[INFO] TLS certificate already exists, skipping generation."
fi

# ── XRDP ini configuration ────────────────────────────────────────────────────
if [ -f "$XRDP_CFG" ]; then

  # Apply TLS settings
  sed -i "s|^certificate=.*|certificate=${XRDP_CERT}|" "$XRDP_CFG"
  sed -i "s|^key_file=.*|key_file=${XRDP_KEY}|"       "$XRDP_CFG"
  # Enforce TLS security layer (prevents downgrade to RDP/NLA negotiation)
  if grep -q "^security_layer=" "$XRDP_CFG"; then
    sed -i "s|^security_layer=.*|security_layer=tls|" "$XRDP_CFG"
  else
    sed -i "/^\[globals\]/a security_layer=tls" "$XRDP_CFG"
  fi

  # Clipboard handling
  if [ "$XRDP_ALLOW_CLIPBOARD" = "1" ]; then
    echo "[INFO] Enabling clipboard redirection per XRDP_ALLOW_CLIPBOARD=1"
    sed -i 's/clipboard=0/clipboard=1/g' "$XRDP_CFG" || true
  else
    echo "[INFO] Disabling clipboard redirection (secure default)."
    sed -i 's/clipboard=1/clipboard=0/g' "$XRDP_CFG" || true
  fi

  systemctl restart xrdp
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "[SUCCESS] Kali setup complete."
echo "=========================================="
echo ""
echo "XRDP:         running on TCP 3389"
echo "TLS:          enabled (self-signed cert)"
echo "RDP user:     ${RDP_USER}"
echo "Clipboard:    $([ "$XRDP_ALLOW_CLIPBOARD" = "1" ] && echo enabled || echo disabled)"
echo ""
echo "Security reminders:"
echo "  - Restrict port 3389 to trusted IPs in your security group"
echo "  - Do not use the root account for RDP sessions"
echo "  - Rotate the RDP user password regularly"
if [ -z "$RDP_PASS" ]; then
  echo ""
  echo "[ACTION REQUIRED] Set the RDP user password: passwd ${RDP_USER}"
fi
echo "=========================================="
