#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# splunk_setup.sh
# Installs Splunk Enterprise on Ubuntu/Debian hosts (non-interactive)
# Creates admin user and enables boot-start
#
# Environment variables:
#   SPLUNK_ADMIN_PASS     Admin password (required)
#   SPLUNK_ADMIN_USER     Admin username (default: admin)
#   SPLUNK_VERSION        Package version (default: 9.3.2)
#   SPLUNK_BUILD          Build hash (default: d8ae995bf219)
#   SPLUNK_SHA256         Expected SHA256 of the .deb file (recommended)

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] This script must be run as root (sudo)."
  exit 1
fi

# ── Configuration ─────────────────────────────────────────────────────────────
# Check https://www.splunk.com/en_us/download/splunk-enterprise.html for the
# latest version string and build hash before deploying. The defaults below
# are known-good but will become outdated; using a stale build installs an
# unpatched binary on first deploy.
SPLUNK_VERSION="${SPLUNK_VERSION:-9.3.2}"
SPLUNK_BUILD="${SPLUNK_BUILD:-d8ae995bf219}"
SPLUNK_PKG="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-2.6-amd64.deb"
SPLUNK_DOWNLOAD_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_PKG}"
SPLUNK_ADMIN_USER="${SPLUNK_ADMIN_USER:-admin}"
SPLUNK_ADMIN_PASS="${SPLUNK_ADMIN_PASS:-}"
SPLUNK_SHA256="${SPLUNK_SHA256:-}"
SEED_CONF="/opt/splunk/etc/system/local/user-seed.conf"

echo "[INFO] Splunk Enterprise Setup Script"
echo "[INFO] Version: ${SPLUNK_VERSION}"
echo "=========================================="

# ── Password validation ───────────────────────────────────────────────────────
if [ -z "$SPLUNK_ADMIN_PASS" ]; then
  echo "[ERROR] SPLUNK_ADMIN_PASS is not set."
  echo ""
  echo "Usage:"
  echo "  SPLUNK_ADMIN_PASS='StrongP@ss123!' bash splunk_setup.sh"
  echo ""
  echo "Password requirements: 8+ chars, upper, lower, digit, special character"
  exit 1
fi

if [[ ${#SPLUNK_ADMIN_PASS} -lt 8 ]]; then
  echo "[ERROR] Password must be at least 8 characters."; exit 1
fi
if ! [[ "$SPLUNK_ADMIN_PASS" =~ [A-Z] ]]; then
  echo "[ERROR] Password must contain at least 1 uppercase letter."; exit 1
fi
if ! [[ "$SPLUNK_ADMIN_PASS" =~ [a-z] ]]; then
  echo "[ERROR] Password must contain at least 1 lowercase letter."; exit 1
fi
if ! [[ "$SPLUNK_ADMIN_PASS" =~ [0-9] ]]; then
  echo "[ERROR] Password must contain at least 1 number."; exit 1
fi
if ! [[ "$SPLUNK_ADMIN_PASS" =~ [^a-zA-Z0-9] ]]; then
  echo "[ERROR] Password must contain at least 1 special character."; exit 1
fi

# ── Dependencies ──────────────────────────────────────────────────────────────
echo "[INFO] Installing system dependencies..."
apt-get update
apt-get install -y wget curl

# ── Download ──────────────────────────────────────────────────────────────────
cd /tmp

if [ ! -f "$SPLUNK_PKG" ]; then
  echo "[INFO] Downloading Splunk Enterprise..."
  echo "[INFO] This may take several minutes..."

  DOWNLOAD_SUCCESS=0
  for i in {1..3}; do
    if wget --progress=bar:force:noscroll "$SPLUNK_DOWNLOAD_URL" -O "$SPLUNK_PKG"; then
      DOWNLOAD_SUCCESS=1
      break
    fi
    echo "[WARN] Download attempt $i failed. Retrying in 5s..."
    sleep 5
  done

  if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    echo "[ERROR] Failed to download Splunk after 3 attempts."
    echo "  1. Check connectivity: ping -c 3 8.8.8.8"
    echo "  2. Verify version at: https://www.splunk.com/en_us/download/splunk-enterprise.html"
    echo "  3. Update SPLUNK_VERSION / SPLUNK_BUILD and retry"
    exit 1
  fi

  if [ ! -s "$SPLUNK_PKG" ]; then
    echo "[ERROR] Downloaded file is empty."
    rm -f "$SPLUNK_PKG"
    exit 1
  fi
else
  echo "[INFO] Splunk package already present."
fi

# ── SHA256 verification ───────────────────────────────────────────────────────
if [ -n "$SPLUNK_SHA256" ]; then
  echo "[INFO] Verifying SHA256 checksum..."
  ACTUAL_SHA256=$(sha256sum "$SPLUNK_PKG" | awk '{print $1}')
  if [ "$ACTUAL_SHA256" != "$SPLUNK_SHA256" ]; then
    echo "[ERROR] SHA256 mismatch! Package may be corrupt or tampered."
    echo "  Expected: ${SPLUNK_SHA256}"
    echo "  Actual:   ${ACTUAL_SHA256}"
    rm -f "$SPLUNK_PKG"
    exit 1
  fi
  echo "[INFO] SHA256 checksum verified."
else
  echo "[WARN] SPLUNK_SHA256 not set. Skipping checksum verification."
  echo "[WARN] Supply SPLUNK_SHA256 from https://www.splunk.com/en_us/download/splunk-enterprise.html"
fi

# ── Install ───────────────────────────────────────────────────────────────────
echo "[INFO] Installing Splunk Enterprise..."
if ! dpkg -i "$SPLUNK_PKG"; then
  echo "[WARN] Missing dependencies; attempting to resolve..."
  apt-get update
  apt-get install -f -y
  if ! dpkg -i "$SPLUNK_PKG"; then
    echo "[ERROR] Splunk installation failed after dependency fix."
    exit 1
  fi
fi

if [ ! -d "/opt/splunk" ]; then
  echo "[ERROR] /opt/splunk not found after install."
  exit 1
fi

# ── Admin user seed ───────────────────────────────────────────────────────────
# user-seed.conf is read once on first start then should be deleted.
echo "[INFO] Writing admin credentials seed file..."
mkdir -p "$(dirname "$SEED_CONF")"
cat > "$SEED_CONF" << EOF
[user_info]
USERNAME = ${SPLUNK_ADMIN_USER}
PASSWORD = ${SPLUNK_ADMIN_PASS}
EOF
chmod 400 "$SEED_CONF"

# ── First start ───────────────────────────────────────────────────────────────
echo "[INFO] Starting Splunk (first start, accepting license)..."
if ! /opt/splunk/bin/splunk start \
    --accept-license --answer-yes --no-prompt; then
  echo "[ERROR] Failed to start Splunk."
  echo "  Logs: /opt/splunk/var/log/splunk/"
  exit 1
fi

# ── Delete seed file immediately after first start ────────────────────────────
# user-seed.conf contains a plaintext password and is no longer needed
# once Splunk has written the hashed credentials to passwd.
echo "[INFO] Removing plaintext credential seed file..."
rm -f "$SEED_CONF"
echo "[INFO] user-seed.conf deleted."

# ── Boot-start ────────────────────────────────────────────────────────────────
echo "[INFO] Enabling boot-start..."
/opt/splunk/bin/splunk enable boot-start \
  --accept-license --answer-yes

# ── Receiving port via conf file ──────────────────────────────────────────────
# Configure the forwarder receiving port via inputs.conf instead of CLI to
# avoid exposing credentials in the process list (visible to `ps`).
echo "[INFO] Enabling forwarder receiving port 9997 via inputs.conf..."
INPUTS_CONF="/opt/splunk/etc/system/local/inputs.conf"
cat > "$INPUTS_CONF" << EOF
[splunktcp://9997]
disabled = false
EOF
chmod 640 "$INPUTS_CONF"
echo "[INFO] Receiving port 9997 configured."

# ── Enable HTTPS on Splunk Web UI ─────────────────────────────────────────────
# Written via web.conf to avoid passing credentials on the CLI (visible in ps).
echo "[INFO] Enabling HTTPS on Splunk Web UI..."
WEB_CONF="/opt/splunk/etc/system/local/web.conf"
cat > "$WEB_CONF" << EOF
[settings]
enableSplunkWebSSL = true
EOF
chmod 640 "$WEB_CONF"
echo "[INFO] HTTPS enabled via web.conf."

# ── Restart to apply configs ──────────────────────────────────────────────────
echo "[INFO] Restarting Splunk..."
/opt/splunk/bin/splunk restart

echo "[INFO] Waiting for Splunk to be ready..."
sleep 15

# ── Status check ─────────────────────────────────────────────────────────────
if /opt/splunk/bin/splunk status | grep -q "splunkd is running"; then
  SPLUNK_RUNNING=1
else
  SPLUNK_RUNNING=0
fi

# ── Summary ───────────────────────────────────────────────────────────────────
IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "=========================================="
if [ $SPLUNK_RUNNING -eq 1 ]; then
  echo "[SUCCESS] Splunk Enterprise is running."
else
  echo "[WARN] Splunk may still be starting. Check: /opt/splunk/bin/splunk status"
fi
echo "=========================================="
echo ""
echo "Web UI:           https://${IP_ADDR:-<TOOLS_IP>}:8000  (HTTPS — self-signed cert)"
echo "Username:         ${SPLUNK_ADMIN_USER}"
echo "Receiving port:   9997"
echo "Forwarder target: ${IP_ADDR:-<TOOLS_IP>}:9997"
echo ""
echo "Next steps:"
echo "  1. Accept the self-signed cert warning in your browser"
echo "  2. Create indexes: Settings -> Indexes"
echo "  3. Point forwarders at ${IP_ADDR:-<TOOLS_IP>}:9997"
echo "  4. Review Settings -> Server controls -> Security"
echo "=========================================="
