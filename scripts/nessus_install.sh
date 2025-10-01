#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts (non-interactive)
# Note: Tenable download links require authentication / user session.
# Provide NESSUS_DOWNLOAD_URL or place the .deb in /tmp/ before running.

# Configurable version (update as needed)
NESSUS_VERSION="${NESSUS_VERSION:-10.3.0}"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"
# Optionally provide a direct download URL (from your Tenable account)
NESSUS_DOWNLOAD_URL="${NESSUS_DOWNLOAD_URL:-}"

echo "[INFO] Nessus Essentials Installation Script"
echo "[INFO] Version: ${NESSUS_VERSION}"
echo "=========================================="

# Instructions if no URL provided
if [ -z "$NESSUS_DOWNLOAD_URL" ]; then
  echo "[INFO] No NESSUS_DOWNLOAD_URL provided."
  echo "Place ${NESSUS_PKG} in /tmp/ or set NESSUS_DOWNLOAD_URL before running."
fi

# Work in /tmp
cd /tmp

# Acquire package (download if URL provided and file missing)
if [ ! -f "$NESSUS_PKG" ]; then
  if [ -n "$NESSUS_DOWNLOAD_URL" ]; then
    echo "[INFO] Downloading Nessus package from provided URL..."
    DOWNLOAD_SUCCESS=0
    for i in {1..3}; do
      if wget --progress=bar:force:noscroll "$NESSUS_DOWNLOAD_URL" -O "$NESSUS_PKG"; then
        DOWNLOAD_SUCCESS=1
        echo "[INFO] Download successful."
        break
      fi
      echo "[WARN] Download attempt $i failed. Retrying in 5s..."
      sleep 5
    done
    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
      echo "[ERROR] Failed to download Nessus package after 3 attempts."
      echo "Manually download from: https://www.tenable.com/downloads/nessus"
      exit 1
    fi
    if [ ! -s "$NESSUS_PKG" ]; then
      echo "[ERROR] Downloaded file is empty or corrupt."
      rm -f "$NESSUS_PKG"
      exit 1
    fi
  else
    echo "[ERROR] Nessus package not present in /tmp/ and no NESSUS_DOWNLOAD_URL specified."
    echo "Please download ${NESSUS_PKG} and place it in /tmp/ or set NESSUS_DOWNLOAD_URL."
    exit 1
  fi
else
  echo "[INFO] Nessus package already present: $NESSUS_PKG"
fi

# Verify .deb structure
echo "[INFO] Verifying package header..."
if ! dpkg-deb --info "$NESSUS_PKG" >/dev/null 2>&1; then
  echo "[ERROR] Package appears corrupt or invalid. Removing and aborting."
  rm -f "$NESSUS_PKG"
  exit 1
fi

# Install minimal dependencies (wget/curl and a port-check tool)
echo "[INFO] Installing system dependencies..."
apt-get update -y
# Try to install netcat-openbsd; fall back to netcat if needed.
if ! apt-get install -y wget curl netcat-openbsd; then
  apt-get install -y netcat || true
fi

# Install Nessus package, fix deps if dpkg reports issues
echo "[INFO] Installing Nessus package..."
if ! dpkg -i "$NESSUS_PKG"; then
  echo "[WARN] dpkg reported missing dependencies; attempting to fix..."
  apt-get update -y
  apt-get install -f -y
  if ! dpkg -i "$NESSUS_PKG"; then
    echo "[ERROR] Nessus installation failed after dependency fix."
    exit 1
  fi
fi

# Enable and start the nessusd service
echo "[INFO] Enabling and starting nessusd.service..."
if ! systemctl enable --now nessusd.service; then
  echo "[ERROR] Failed to enable/start nessusd. See journal for details."
  journalctl -u nessusd.service --no-pager | tail -n 50 || true
  exit 1
fi

# Wait for the systemd service to report active (adaptive wait)
echo "[INFO] Waiting for nessusd service to become active..."
for i in {1..30}; do
  if systemctl is-active --quiet nessusd.service; then
    echo "[INFO] nessusd service is active."
    break
  fi
  sleep 2
done

if ! systemctl is-active --quiet nessusd.service; then
  echo "[ERROR] nessusd failed to become active. Check logs:"
  echo "  journalctl -u nessusd.service -xe"
  exit 1
fi

# Confirm the web UI is listening on port 8834 (use nc or ss)
echo "[INFO] Checking Nessus Web UI availability on port 8834..."
PORT_OK=0
for i in {1..30}; do
  if command -v nc >/dev/null 2>&1; then
    if nc -z localhost 8834 2>/dev/null; then
      PORT_OK=1
      break
    fi
  else
    # fallback: use ss
    if ss -tnlp 2>/dev/null | grep -q ":8834"; then
      PORT_OK=1
      break
    fi
  fi
  sleep 2
done

if [ $PORT_OK -ne 1 ]; then
  echo "[WARN] Nessus service is active but port 8834 is not responding yet."
  echo "Check logs: /opt/nessus/var/nessus/logs and journalctl -u nessusd.service"
else
  echo "[INFO] Nessus Web UI appears to be listening on port 8834."
fi

# Display access information and next steps
IP_ADDR=$(hostname -I | awk '{print $1}' || true)
echo ""
echo "=========================================="
echo "[SUCCESS] Nessus installation complete."
if [ -n "${IP_ADDR:-}" ]; then
  echo "Web UI:  https://${IP_ADDR}:8834/"
else
  echo "Web UI:  https://<YOUR_SERVER_IP>:8834/"
fi
echo ""
echo "Next steps:"
echo "  1) Open the Web UI and choose 'Nessus Essentials'."
echo "  2) Enter your activation code (received via email from Tenable)."
echo "  3) Allow plugin updates to complete (may take 10-30 minutes)."
echo "  4) Create a scan and verify target reachability."
echo "=========================================="
