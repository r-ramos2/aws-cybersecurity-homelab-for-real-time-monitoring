#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# splunk_setup.sh
# Installs Splunk Enterprise on Ubuntu/Debian hosts (non-interactive)
# Creates admin user and enables boot-start

SPLUNK_VERSION="9.1.0"
SPLUNK_BUILD="1c86ca0bacc3"
SPLUNK_PKG="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-2.6-amd64.deb"
SPLUNK_DOWNLOAD_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_PKG}"

# Default admin credentials (CHANGE THESE in production!)
SPLUNK_ADMIN_USER="${SPLUNK_ADMIN_USER:-admin}"
SPLUNK_ADMIN_PASS="${SPLUNK_ADMIN_PASS:-Changeme123!}"

echo "[INFO] Splunk Enterprise Setup Script"
echo "[INFO] Version: ${SPLUNK_VERSION}"

# Work in /tmp
cd /tmp

# Download Splunk if not present
if [ ! -f "$SPLUNK_PKG" ]; then
  echo "[INFO] Downloading Splunk Enterprise..."
  for i in {1..3}; do
    if wget -q "$SPLUNK_DOWNLOAD_URL" -O "$SPLUNK_PKG"; then
      echo "[INFO] Splunk package downloaded successfully."
      break
    fi
    echo "[WARN] Download attempt $i failed. Retrying in 5s..."
    sleep 5
  done

  if [ ! -f "$SPLUNK_PKG" ]; then
    echo "[ERROR] Failed to download Splunk after retries."
    echo "Verify the download URL or manually download from:"
    echo "  https://www.splunk.com/en_us/download/splunk-enterprise.html"
    exit 1
  fi
else
  echo "[INFO] Splunk package already present."
fi

# Install package
echo "[INFO] Installing Splunk Enterprise..."
if ! dpkg -i "$SPLUNK_PKG"; then
  echo "[WARN] dpkg reported missing dependencies; attempting to fix..."
  apt-get update
  apt-get install -f -y
fi

# Create user-seed.conf for non-interactive setup
echo "[INFO] Configuring admin user..."
mkdir -p /opt/splunk/etc/system/local
cat > /opt/splunk/etc/system/local/user-seed.conf << EOF
[user_info]
USERNAME = ${SPLUNK_ADMIN_USER}
PASSWORD = ${SPLUNK_ADMIN_PASS}
EOF

chmod 400 /opt/splunk/etc/system/local/user-seed.conf

# Start Splunk and accept license
echo "[INFO] Starting Splunk Enterprise..."
/opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt

# Enable boot-start
echo "[INFO] Enabling Splunk to start at boot..."
/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --answer-yes

# Configure receiving port for forwarders
echo "[INFO] Enabling data receiving on port 9997..."
/opt/splunk/bin/splunk enable listen 9997 -auth ${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}

# Restart to apply all configs
echo "[INFO] Restarting Splunk..."
/opt/splunk/bin/splunk restart

# Display access info
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo ""
  echo "=========================================="
  echo "[SUCCESS] Splunk Enterprise is running!"
  echo "=========================================="
  echo "Web UI:  http://$IP_ADDR:8000"
  echo "Username: ${SPLUNK_ADMIN_USER}"
  echo "Password: ${SPLUNK_ADMIN_PASS}"
  echo ""
  echo "IMPORTANT: Change the default password after first login!"
  echo "=========================================="
else
  echo "[INFO] Splunk installed. Access at http://<TOOLS_PUBLIC_IP>:8000"
fi

echo "[INFO] Splunk setup complete."
