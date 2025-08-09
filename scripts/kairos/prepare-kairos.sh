#!/bin/bash

# Kairos preparation script for custom image building
# This script performs initial setup and configuration for Kairos images

set -euo pipefail

echo "Starting Kairos preparation script..."

# Update system packages based on the distribution
if command -v apt-get >/dev/null 2>&1; then
    echo "Detected Ubuntu/Debian system, updating packages..."
    apt-get update
    apt-get upgrade -y
    
    # Install additional tools for enterprise environments
    apt-get install -y \
        htop \
        iotop \
        net-tools \
        tcpdump \
        strace \
        vim \
        git \
        rsync \
        unzip
        
elif command -v apk >/dev/null 2>&1; then
    echo "Detected Alpine system, updating packages..."
    apk update
    apk upgrade
    
    # Install additional tools for enterprise environments
    apk add \
        htop \
        iotop \
        net-tools \
        tcpdump \
        strace \
        vim \
        git \
        rsync \
        unzip
        
elif command -v dnf >/dev/null 2>&1; then
    echo "Detected Fedora system, updating packages..."
    dnf update -y
    
    # Install additional tools for enterprise environments
    dnf install -y \
        htop \
        iotop \
        net-tools \
        tcpdump \
        strace \
        vim \
        git \
        rsync \
        unzip
fi

# Create custom directories for enterprise configuration
echo "Creating custom directories..."
mkdir -p /etc/kairos/custom
mkdir -p /var/lib/kairos/custom
mkdir -p /opt/kairos/scripts

# Set up custom logging configuration
echo "Configuring custom logging..."
cat > /etc/kairos/custom/logging.conf << 'EOF'
# Custom logging configuration for enterprise Kairos deployment
[global]
log_level = info
log_format = json
log_output = /var/log/kairos-custom.log
EOF

# Create custom health check script
echo "Creating health check script..."
cat > /opt/kairos/scripts/health-check.sh << 'EOF'
#!/bin/bash
# Custom health check script for Kairos

# Check K3s status
if systemctl is-active --quiet k3s; then
    echo "K3s is running"
else
    echo "K3s is not running" >&2
    exit 1
fi

# Check network connectivity
if curl -s --max-time 5 https://k8s.io > /dev/null; then
    echo "Network connectivity OK"
else
    echo "Network connectivity issues" >&2
    exit 1
fi

echo "Health check passed"
EOF

chmod +x /opt/kairos/scripts/health-check.sh

# Configure automatic updates (enterprise-safe approach)
echo "Configuring update policies..."
cat > /etc/kairos/custom/update-policy.yaml << 'EOF'
# Conservative update policy for enterprise environments
apiVersion: v1
kind: ConfigMap
metadata:
  name: kairos-update-policy
data:
  policy: |
    # Only apply security updates automatically
    auto_update: false
    security_updates: true
    maintenance_window: "02:00-04:00"
    reboot_strategy: "off"
EOF

# Set up monitoring hooks
echo "Setting up monitoring hooks..."
cat > /opt/kairos/scripts/monitoring-setup.sh << 'EOF'
#!/bin/bash
# Set up basic monitoring for enterprise environments

# Create metrics collection directory
mkdir -p /var/lib/kairos/metrics

# Set up basic system metrics collection
cat > /etc/systemd/system/kairos-metrics.service << 'METRICS_EOF'
[Unit]
Description=Kairos System Metrics Collection
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "$(date): $(uptime), $(free -h | grep Mem:)" >> /var/lib/kairos/metrics/system.log'
User=root

[Install]
WantedBy=multi-user.target
METRICS_EOF

cat > /etc/systemd/system/kairos-metrics.timer << 'TIMER_EOF'
[Unit]
Description=Run Kairos Metrics Collection every 5 minutes
Requires=kairos-metrics.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=kairos-metrics.service

[Install]
WantedBy=timers.target
TIMER_EOF

systemctl daemon-reload
systemctl enable kairos-metrics.timer
EOF

chmod +x /opt/kairos/scripts/monitoring-setup.sh

# Run monitoring setup
bash /opt/kairos/scripts/monitoring-setup.sh

echo "Kairos preparation script completed successfully"