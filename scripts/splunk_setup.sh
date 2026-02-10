#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# splunk_setup.sh
# Installs Splunk Enterprise on Ubuntu/Debian hosts (non-interactive)
# Creates admin user and enables boot-start

# Version configuration - UPDATE THESE VARIABLES FOR NEW RELEASES
SPLUNK_VERSION="${SPLUNK_VERSION:-9.1.0}"
SPLUNK_BUILD="${SPLUNK_BUILD:-1c86ca0bacc3}"
SPLUNK_PKG="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-2.6-amd64.deb"
SPLUNK_DOWNLOAD_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_PKG}"

# CRITICAL: Set these via environment variables before running
# Example: SPLUNK_ADMIN_PASS='YourSecureP@ssw0rd!' bash splunk_setup.sh
SPLUNK_ADMIN_USER="${SPLUNK_ADMIN_USER:-admin}"
SPLUNK_ADMIN_PASS="${SPLUNK_ADMIN_PASS:-}"

echo "[INFO] Splunk Enterprise Setup Script"
echo "[INFO] Version: ${SPLUNK_VERSION}"
echo "=========================================="

# Validate password is set
if [ -z "$SPLUNK_ADMIN_PASS" ]; then
  echo "[ERROR] SPLUNK_ADMIN_PASS environment variable not set!"
  echo ""
  echo "Usage:"
  echo "  SPLUNK_ADMIN_PASS='YourSecureP@ssw0rd!' bash splunk_setup.sh"
  echo ""
  echo "Password requirements:"
  echo "  - Minimum 8 characters"
  echo "  - At least 1 uppercase letter"
  echo "  - At least 1 lowercase letter"
  echo "  - At least 1 number"
  echo "  - At least 1 special character"
  exit 1
fi

# Validate password complexity
if [[ ${#SPLUNK_ADMIN_PASS} -lt 8 ]]; then
  echo "[ERROR] Password must be at least 8 characters long"
  exit 1
fi

echo "[INFO] Installing system dependencies..."
apt-get update
apt-get install -y wget curl

# Work in /tmp
cd /tmp

# Download Splunk if not present
if [ ! -f "$SPLUNK_PKG" ]; then
  echo "[INFO] Downloading Splunk Enterprise..."
  echo "[INFO] This may take several minutes depending on your connection..."
  
  DOWNLOAD_SUCCESS=0
  for i in {1..3}; do
    if wget --progress=bar:force:noscroll "$SPLUNK_DOWNLOAD_URL" -O "$SPLUNK_PKG"; then
      echo "[INFO] Splunk package downloaded successfully."
      DOWNLOAD_SUCCESS=1
      break
    fi
    echo "[WARN] Download attempt $i failed. Retrying in 5s..."
    sleep 5
  done

  if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    echo "[ERROR] Failed to download Splunk after 3 attempts."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify internet connectivity: ping -c 3 8.8.8.8"
    echo "  2. Check if version ${SPLUNK_VERSION} exists at:"
    echo "     https://www.splunk.com/en_us/download/splunk-enterprise.html"
    echo "  3. Update SPLUNK_VERSION and SPLUNK_BUILD variables in this script"
    echo "  4. Manually download and place in /tmp/"
    exit 1
  fi
  
  # Verify downloaded file is not corrupt
  if [ ! -s "$SPLUNK_PKG" ]; then
    echo "[ERROR] Downloaded file is empty or corrupt"
    rm -f "$SPLUNK_PKG"
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
  
  # Retry installation
  if ! dpkg -i "$SPLUNK_PKG"; then
    echo "[ERROR] Splunk installation failed after dependency fix"
    exit 1
  fi
fi

# Verify installation directory exists
if [ ! -d "/opt/splunk" ]; then
  echo "[ERROR] Splunk installation directory not found!"
  exit 1
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
echo "[INFO] First start may take 1-2 minutes..."
if ! /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt; then
  echo "[ERROR] Failed to start Splunk"
  echo "[INFO] Check logs at: /opt/splunk/var/log/splunk/"
  exit 1
fi

# Enable boot-start
echo "[INFO] Enabling Splunk to start at boot..."
/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --answer-yes

# Wait for Splunk to be fully operational
echo "[INFO] Waiting for Splunk services to be ready..."
sleep 10

# Configure receiving port for forwarders
echo "[INFO] Enabling data receiving on port 9997..."
if ! /opt/splunk/bin/splunk enable listen 9997 -auth ${SPLUNK_ADMIN_USER}:${SPLUNK_ADMIN_PASS}; then
  echo "[WARN] Failed to enable listening port. You may need to configure this manually."
fi

# Restart to apply all configs
echo "[INFO] Restarting Splunk to apply configurations..."
/opt/splunk/bin/splunk restart

# Wait for restart
echo "[INFO] Waiting for Splunk to restart..."
sleep 15

# Verify Splunk is running
if /opt/splunk/bin/splunk status | grep -q "splunkd is running"; then
  echo ""
  echo "=========================================="
  echo "[SUCCESS] Splunk Enterprise is running!"
  echo "=========================================="
else
  echo ""
  echo "[WARN] Splunk may not be fully started yet. Check status with:"
  echo "  /opt/splunk/bin/splunk status"
fi

# Display access info
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -n "$IP_ADDR" ]; then
  echo ""
  echo "Access Information:"
  echo "  Web UI:  http://$IP_ADDR:8000"
  echo "  Username: ${SPLUNK_ADMIN_USER}"
  echo "  Password: (set via environment variable)"
  echo ""
  echo "Forwarder Configuration:"
  echo "  Receiving Port: 9997"
  echo "  Server Address: ${IP_ADDR}:9997"
  echo ""
else
  echo "[INFO] Splunk installed. Access at http://<TOOLS_PUBLIC_IP>:8000"
fi

echo "=========================================="
echo "[INFO] Splunk setup complete."
echo ""
echo "Next Steps:"
echo "  1. Access Splunk Web UI and complete initial setup"
echo "  2. Create indexes for your data (Settings -> Indexes)"
echo "  3. Configure forwarders to send data to ${IP_ADDR}:9997"
echo "  4. Review security settings and enable HTTPS"
echo "=========================================="
