#!/bin/bash
# Auto-generated deployment script for Kairos latest
# Generated: Sat Aug 16 11:25:30 AM CDT 2025

set -euo pipefail

KAIROS_VERSION="latest"
IMAGE_DIR="/home/lordmuffin/Claude/Git/beyond-devops-os-factory/images/kairos/latest"
CLOUD_CONFIG="${CLOUD_CONFIG:-./auroraboot/cloud-config.yaml}"

echo "Deploying Kairos $KAIROS_VERSION with AuroraBoot..."

# Find available images
ISO_FILE=$(find "$IMAGE_DIR" -name "*.iso" | head -1)
RAW_FILE=$(find "$IMAGE_DIR" -name "*.raw" | head -1)
QCOW2_FILE=$(find "$IMAGE_DIR" -name "*.qcow2" | head -1)

if [ -z "$ISO_FILE" ] && [ -z "$RAW_FILE" ] && [ -z "$QCOW2_FILE" ]; then
    echo "ERROR: No suitable images found in $IMAGE_DIR"
    exit 1
fi

# Prefer ISO for bootable deployment
IMAGE_FILE="${ISO_FILE:-${RAW_FILE:-$QCOW2_FILE}}"
echo "Using image: $IMAGE_FILE"

# Check for cloud-config
if [ ! -f "$CLOUD_CONFIG" ]; then
    echo "WARNING: Cloud-config not found: $CLOUD_CONFIG"
    echo "Please create a cloud-config file for deployment"
    exit 1
fi

# Deploy with AuroraBoot
echo "Starting AuroraBoot deployment..."
docker run --rm -ti \
    --net host \
    -v "$(dirname "$IMAGE_FILE"):/images" \
    -v "$(dirname "$CLOUD_CONFIG"):/config" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    quay.io/kairos/auroraboot:v0.8.1 \
    --set "container_image=/images/$(basename "$IMAGE_FILE")" \
    --cloud-config "/config/$(basename "$CLOUD_CONFIG")"

echo "Deployment completed!"
