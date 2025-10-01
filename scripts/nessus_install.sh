#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# nessus_install.sh
# Installs Nessus Essentials on Debian/Ubuntu hosts (non-interactive)
# Check https://www.tenable.com/downloads/nessus for latest version

# Version configuration - UPDATE THESE VARIABLES FOR NEW RELEASES
NESSUS_VERSION="${NESSUS_VERSION:-10.3.0}"
NESSUS_PKG="Nessus-${NESSUS_VERSION}-debian6_amd64.deb"

# Construct download URL
# Note: Tenable's download URLs require authentication via their API
# You must obtain the actual download link from your Tenable account
NESSUS_DOWNLOAD_URL="${NESSUS_DOWNLOAD_URL:-}"

echo "[INFO] Nessus Essentials Installation Script"
echo "[INFO] Version: ${NESSUS_VERSION}"
echo "=========================================="

# Check if user provided download URL
if [ -z "$NESSUS_DOWNLOAD_URL" ]; then
  echo "[INFO] No download URL provided via NESSUS_DOWNLOAD_URL environment variable"
  echo ""
  echo "To get the download URL:"
  echo "  1. Register for Nessus Essentials at:"
  echo "     https://www.tenable.com/products/nessus/nessus-essentials"
  echo "  2. You will receive an activation code via email"
  echo "  3. Download the .deb package for Debian/Ubuntu 64-bit"
  echo "  4. Either:"
  echo "     a) Place the .deb file in /tmp/ and re-run this script, OR"
  echo "     b) Set NESSUS_DOWNLOAD_URL and re-run:"
  echo "        NESSUS_DOWNLOAD_URL='https://...' bash nessus_install.sh"
  echo ""
fi

# Work in /tmp to avoid clutter
cd /tmp

# Download package if missing
if [ ! -f "$NESSUS_PKG" ]; then
  if [ -n "$NESSUS_DOWNLOAD_URL" ]; then
    echo "[INFO] Downloading Nessus package from provided URL..."
    
    DOWNLOAD_SUCCESS=0
    for i in {1..3}; do
      if wget --progress=bar:force:noscroll "$NESSUS_DOWNLOAD_URL" -O "$NESSUS_PKG"; then
        echo "[INFO] Nessus package downloaded successfully."
        DOWNLOAD_SUCCESS=1
        break
      fi
      echo "[WARN] Download attempt $i failed. Retrying in 5s..."
      sleep 5
    done

    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
      echo "[ERROR] Failed to download Nessus package after 3 attempts."
      echo ""
      echo "Troubleshooting:"
      echo "  1. Verify the download URL is correct and not expired"
      echo "  2. Check internet connectivity: ping -c 3 8.8.8.8"
      echo "  3. Manually download from https://www.tenable.com/downloads/nessus"
      echo "  4. Place the .deb file in /tmp/ and re-run this script"
      exit 1
    fi
    
    # Verify downloaded file
    if [ ! -s "$NESSUS_PKG" ]; then
      echo "[ERROR] Downloaded file is empty or corrupt"
      rm -f "$NESSUS_PKG"
      exit 1
    fi
  else
    echo "[ERROR] Nessus package not found and no download URL provided."
    echo ""
    echo "Please either:"
    echo "  1. Manually download the package and place it in /tmp/"
    echo "  2. Provide download URL via NESSUS_DOWNLOAD_URL environment variable"
    exit 1
  fi
else
  echo "[INFO] Nessus package already present: $NESSUS_PKG"
fi

# Verify package file integrity
echo "[INFO] Verifying package integrity..."
if ! dpkg-deb --info "$NESSUS_PKG" > /dev/null 2>&1; then
  echo "[ERROR] Package file appears corrupt or invalid"
  echo "[INFO] Removing corrupted file..."
  rm -f "$NESSUS_PKG"
  echo "[ERROR] Please download the package again"
  exit 1
fi

# Install dependencies
echo "[INFO] Installing system dependencies..."
apt-get update
apt-get install -y wget curl

# Install package
echo "[INFO] Installing Nessus package..."
if ! dpkg -i "$NESSUS_PKG"; then
  echo "[WARN] dpkg reported missing dependencies; attempting to fix..."
  apt-get update
  apt-get install -f -y

  # Retry installation
  if ! dpkg -i "$NESSUS_PKG"; then
    echo "[ERROR] Nessus installation failed after dependency fix"
    exit 1
  fi
fi

# Enable and start Nessus service
echo "[INFO] Enabling and starting Nessus service..."
systemctl enable nessusd.service
systemctl start nessusd.service

# Wait briefly for service startup
echo "[INFO] Waiting for Nessus to initialize..."
for i in {1..30}; do
  if systemctl is-active --quiet nessusd.service; then
    break
  fi
  sleep 2
done

# Check service status
if systemctl is-active --quiet nessusd.service; then
  echo ""
  echo "=========================================="
  echo "[SUCCESS] Nessus is installed and running!"
  echo "=========================================="
else
  echo "[ERROR] Nessus service failed to start. Check logs:"
  echo "  journalctl -u nessusd.service -xe"
  exit 1
fi

# Display access information
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo ""
  echo "Access Information:"
  echo "  Web UI:  https://$IP_ADDR:8834/"
  echo ""
else
  echo "[INFO] Nessus Web UI available at:"
  echo "  https://<YOUR_SERVER_IP>:8834/"
fi

echo "=========================================="
echo "[INFO] Next Steps:"
echo "  1. Open the Nessus Web UI in your browser"
echo "  2. Register with your activation code (from Tenable email)"
echo "  3. Allow plugin download/installation to complete"
echo "  4. Create your first scan policy"
echo "=========================================="
