#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts (non-interactive)
# Check https://www.tenable.com/downloads/nessus for latest version
#
# Environment variables:
#   NESSUS_VERSION          Package version (default: 10.3.0)
#   NESSUS_DOWNLOAD_URL     Direct download URL from Tenable account (required if pkg absent)
#   NESSUS_SHA256           Expected SHA256 checksum of the .deb file (recommended)

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] This script must be run as root (sudo)."
  exit 1
fi

# ── OS / architecture validation ──────────────────────────────────────────────
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "x86_64" ]; then
  echo "[ERROR] Unsupported architecture: ${ARCH}"
  echo "[ERROR] This script targets Debian/Ubuntu amd64 only."
  exit 1
fi

if ! command -v dpkg &>/dev/null; then
  echo "[ERROR] dpkg not found. This script requires a Debian/Ubuntu system."
  exit 1
fi

# Detect distro
DISTRO_ID=""
DISTRO_VERSION=""
if [ -f /etc/os-release ]; then
  # shellcheck source=/dev/null
  source /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_VERSION="${VERSION_ID:-unknown}"
fi

case "$DISTRO_ID" in
  ubuntu|debian|kali)
    echo "[INFO] Detected OS: ${DISTRO_ID} ${DISTRO_VERSION} (${ARCH})"
    ;;
  *)
    echo "[WARN] Unrecognised distro '${DISTRO_ID}'. Proceeding, but results may vary."
    ;;
esac

# ── Configuration ─────────────────────────────────────────────────────────────
NESSUS_VERSION="${NESSUS_VERSION:-10.3.0}"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"
NESSUS_DOWNLOAD_URL="${NESSUS_DOWNLOAD_URL:-}"
NESSUS_SHA256="${NESSUS_SHA256:-}"

echo "[INFO] Nessus Essentials Installation Script"
echo "[INFO] Version: ${NESSUS_VERSION}"
echo "=========================================="

# ── Port 8834 firewall advisory ───────────────────────────────────────────────
echo "[INFO] Checking firewall state for port 8834..."
if command -v ufw &>/dev/null; then
  UFW_STATUS=$(ufw status 2>/dev/null | head -1 || true)
  echo "[INFO] ufw status: ${UFW_STATUS}"
  if echo "$UFW_STATUS" | grep -q "inactive"; then
    echo "[WARN] ufw is inactive. Port 8834 may be publicly accessible."
    echo "[WARN] To restrict access: ufw allow from <trusted-ip> to any port 8834"
  else
    if ! ufw status | grep -q "8834"; then
      echo "[WARN] No ufw rule found for port 8834."
      echo "[WARN] Add a rule if Nessus should only be reachable from trusted hosts:"
      echo "         ufw allow from <trusted-ip> to any port 8834/tcp"
    fi
  fi
else
  echo "[INFO] ufw not installed. Ensure your firewall/security group restricts port 8834."
fi

# ── No download URL guidance ──────────────────────────────────────────────────
if [ -z "$NESSUS_DOWNLOAD_URL" ]; then
  echo "[INFO] No NESSUS_DOWNLOAD_URL set."
  echo ""
  echo "To get the download URL:"
  echo "  1. Register at: https://www.tenable.com/products/nessus/nessus-essentials"
  echo "  2. Download the .deb for Debian/Ubuntu 64-bit"
  echo "  3. Either place the .deb in /tmp/ and re-run, or:"
  echo "     NESSUS_DOWNLOAD_URL='https://...' NESSUS_SHA256='<sha256>' bash nessus_install.sh"
  echo ""
fi

# ── Download ──────────────────────────────────────────────────────────────────
cd /tmp

if [ ! -f "$NESSUS_PKG" ]; then
  if [ -n "$NESSUS_DOWNLOAD_URL" ]; then
    echo "[INFO] Downloading Nessus package..."

    DOWNLOAD_SUCCESS=0
    for i in {1..3}; do
      if wget --progress=bar:force:noscroll "$NESSUS_DOWNLOAD_URL" -O "$NESSUS_PKG"; then
        DOWNLOAD_SUCCESS=1
        break
      fi
      echo "[WARN] Download attempt $i failed. Retrying in 5s..."
      sleep 5
    done

    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
      echo "[ERROR] Failed to download Nessus after 3 attempts."
      echo "  1. Verify the URL is correct and not expired"
      echo "  2. Check connectivity: ping -c 3 8.8.8.8"
      echo "  3. Download manually from https://www.tenable.com/downloads/nessus"
      exit 1
    fi

    if [ ! -s "$NESSUS_PKG" ]; then
      echo "[ERROR] Downloaded file is empty."
      rm -f "$NESSUS_PKG"
      exit 1
    fi
  else
    echo "[ERROR] Package not found in /tmp/ and no NESSUS_DOWNLOAD_URL provided."
    exit 1
  fi
else
  echo "[INFO] Package already present: ${NESSUS_PKG}"
fi

# ── SHA256 verification ───────────────────────────────────────────────────────
if [ -n "$NESSUS_SHA256" ]; then
  echo "[INFO] Verifying SHA256 checksum..."
  ACTUAL_SHA256=$(sha256sum "$NESSUS_PKG" | awk '{print $1}')
  if [ "$ACTUAL_SHA256" != "$NESSUS_SHA256" ]; then
    echo "[ERROR] SHA256 mismatch! Package may be corrupt or tampered."
    echo "  Expected: ${NESSUS_SHA256}"
    echo "  Actual:   ${ACTUAL_SHA256}"
    rm -f "$NESSUS_PKG"
    exit 1
  fi
  echo "[INFO] SHA256 checksum verified."
else
  echo "[WARN] NESSUS_SHA256 not set. Skipping checksum verification."
  echo "[WARN] Supply NESSUS_SHA256 from https://www.tenable.com/downloads/nessus to verify authenticity."
fi

# ── Package integrity (structure) ─────────────────────────────────────────────
echo "[INFO] Verifying package structure..."
if ! dpkg-deb --info "$NESSUS_PKG" > /dev/null 2>&1; then
  echo "[ERROR] Package file is corrupt or invalid."
  rm -f "$NESSUS_PKG"
  exit 1
fi

# ── Dependencies ──────────────────────────────────────────────────────────────
echo "[INFO] Installing system dependencies..."
apt-get update
apt-get install -y wget curl

# ── Install ───────────────────────────────────────────────────────────────────
echo "[INFO] Installing Nessus..."
if ! dpkg -i "$NESSUS_PKG"; then
  echo "[WARN] Missing dependencies detected; attempting to resolve..."
  apt-get update
  apt-get install -f -y
  if ! dpkg -i "$NESSUS_PKG"; then
    echo "[ERROR] Nessus installation failed after dependency fix."
    exit 1
  fi
fi

# Verify installation
if [ ! -d "/opt/nessus" ]; then
  echo "[ERROR] /opt/nessus not found after install. Installation may have failed."
  exit 1
fi
echo "[INFO] Nessus installed to /opt/nessus."

# ── Service ───────────────────────────────────────────────────────────────────
echo "[INFO] Enabling and starting Nessus service..."
systemctl enable nessusd || { echo "[ERROR] Failed to enable nessusd."; exit 1; }
systemctl start  nessusd || { echo "[ERROR] Failed to start nessusd."; exit 1; }

echo "[INFO] Waiting for nessusd to become active (up to 2 minutes)..."
SERVICE_READY=0
for i in {1..24}; do
  if systemctl is-active --quiet nessusd; then
    SERVICE_READY=1
    break
  fi
  echo "[INFO] Waiting... (${i}/24)"
  sleep 5
done

if [ $SERVICE_READY -eq 0 ]; then
  echo "[WARN] nessusd did not become active in time."
  echo "  Check: systemctl status nessusd"
  echo "  Logs:  journalctl -u nessusd -n 50"
fi

# ── Web interface readiness ───────────────────────────────────────────────────
echo "[INFO] Waiting for Nessus web interface..."
WEB_READY=0
for i in {1..12}; do
  if curl -k -sf -o /dev/null -w "%{http_code}" https://localhost:8834 \
      | grep -q "200\|302\|403"; then
    WEB_READY=1
    break
  fi
  echo "[INFO] Waiting for web UI... (${i}/12)"
  sleep 10
done

# ── Summary ───────────────────────────────────────────────────────────────────
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "=========================================="
if [ $WEB_READY -eq 1 ]; then
  echo "[SUCCESS] Nessus installation complete."
else
  echo "[INFO] Nessus installed (web interface still initialising)."
fi
echo "=========================================="
echo ""
echo "Access:  https://${IP_ADDR:-<TOOLS_IP>}:8834"
echo ""
echo "Next steps:"
echo "  1. Accept the self-signed cert warning in your browser"
echo "  2. Choose 'Nessus Essentials' and enter your activation code"
echo "  3. Create admin credentials"
echo "  4. Wait for plugin compilation (~15-30 minutes)"
echo ""
echo "Troubleshooting:"
echo "  systemctl status nessusd"
echo "  journalctl -u nessusd -n 50"
echo "  /opt/nessus/var/nessus/logs/"
echo "=========================================="
