#!/bin/bash

# Kairos finalization script for custom image building
# This script performs final cleanup and optimization for Kairos images

set -euo pipefail

echo "Starting Kairos finalization script..."

# Clean package cache and temporary files
if command -v apt-get >/dev/null 2>&1; then
    echo "Cleaning APT cache..."
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
    rm -rf /var/lib/apt/lists/*
    
elif command -v apk >/dev/null 2>&1; then
    echo "Cleaning APK cache..."
    apk cache clean
    rm -rf /var/cache/apk/*
    
elif command -v dnf >/dev/null 2>&1; then
    echo "Cleaning DNF cache..."
    dnf clean all
    rm -rf /var/cache/dnf/*
fi

# Clean system logs
echo "Cleaning system logs..."
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
find /var/log -type f -name "*.log.*" -delete
truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp
truncate -s 0 /var/log/lastlog

# Clean temporary directories
echo "Cleaning temporary directories..."
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache

# Clean SSH host keys (will be regenerated on first boot)
echo "Removing SSH host keys (will be regenerated)..."
rm -f /etc/ssh/ssh_host_*

# Clean machine-id (will be regenerated on first boot)
echo "Cleaning machine-id..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Clean network configuration that shouldn't persist
echo "Cleaning network configuration..."
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/netplan/*.yaml
rm -rf /var/lib/dhcp/*

# Set correct permissions for Kairos
echo "Setting correct permissions..."
chmod 755 /opt/kairos/scripts/*.sh
chown -R root:root /etc/kairos/custom
chown -R root:root /var/lib/kairos/custom
chown -R root:root /opt/kairos/scripts

# Create final image validation
echo "Creating image validation markers..."
cat > /etc/kairos/custom/build-info.yaml << EOF
build_date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
build_version: custom
build_type: packer
k3s_enabled: true
enterprise_features: true
EOF

# Ensure Kairos services will start correctly
echo "Configuring Kairos service startup..."
systemctl enable kairos-agent || echo "kairos-agent service not found, skipping"
systemctl enable k3s || echo "k3s service not found, will be enabled by cloud-config"

# Final security hardening
echo "Applying final security hardening..."

# Disable unused services
systemctl disable --now bluetooth || echo "bluetooth service not found"
systemctl disable --now cups || echo "cups service not found"
systemctl disable --now avahi-daemon || echo "avahi-daemon service not found"

# Set secure permissions on sensitive files
chmod 600 /etc/shadow
chmod 600 /etc/gshadow
chmod 644 /etc/passwd
chmod 644 /etc/group

# Create enterprise compliance marker
cat > /etc/kairos/custom/compliance.yaml << 'EOF'
# Enterprise compliance configuration
security:
  hardening_applied: true
  ssh_hardening: true
  service_minimization: true
  log_cleanup: true
  
monitoring:
  metrics_collection: enabled
  health_checks: enabled
  
maintenance:
  auto_updates: disabled
  security_updates: enabled
  maintenance_window: configured
EOF

# Final filesystem sync
echo "Performing final filesystem sync..."
sync

echo "Kairos finalization script completed successfully"
echo "Image is ready for deployment"