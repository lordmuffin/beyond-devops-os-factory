# Kairos Installation Guide

A comprehensive guide to customize, build, and install Kairos images using the beyond-devops-os-factory automation framework.

## Table of Contents

- [Prerequisites & Setup](#prerequisites--setup)
- [Understanding the Architecture](#understanding-the-architecture)
- [Customization Options](#customization-options)
- [Build Process](#build-process)
- [Installation Methods](#installation-methods)
- [Post-Installation Configuration](#post-installation-configuration)
- [Troubleshooting & Maintenance](#troubleshooting--maintenance)

## Prerequisites & Setup

### System Requirements

**Development Machine:**
- Git 2.30+
- Text editor (VS Code, vim, etc.)
- Web browser for GitHub interface
- (Optional) Docker for local testing

**Target Hardware:**
- x86_64 (amd64) or ARM64 architecture
- Minimum 4GB RAM (8GB+ recommended)
- 20GB+ storage space
- Network connectivity for initial setup

### Required Tools

The build process uses GitHub Actions, so you don't need local tools installed. However, for development:

```bash
# Optional local tools for development
git clone https://github.com/your-org/beyond-devops-os-factory.git
cd beyond-devops-os-factory

# Verify repository structure
ls -la packer/kairos/
```

### GitHub Repository Setup

1. **Fork or clone** the repository
2. **Enable GitHub Actions** in repository settings
3. **Verify workflow permissions** are set to allow Actions to write

## Understanding the Architecture

### Kairos Factory Action Workflow

This project uses the [Kairos Factory Action](https://github.com/kairos-io/kairos-factory-action) for simplified image building:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Push Code     │───▶│ GitHub Actions  │───▶│  Built Images   │
│   Trigger       │    │ Kairos Factory  │    │ (ISO/RAW/etc)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### File Structure

```
beyond-devops-os-factory/
├── .github/workflows/
│   ├── kairos-factory.yml        # Kairos build workflow (simplified)
│   └── build-windows.yml         # Windows build workflow
├── packer/kairos/
│   ├── osartifact.yaml          # Kairos build configuration
│   ├── cloud-config.yaml        # System configuration
│   ├── Dockerfile               # Custom container (optional)
│   ├── meta-data                # Cloud-init metadata
│   └── user-data                # Cloud-init user data
└── scripts/kairos/
    ├── prepare-kairos.sh        # Pre-installation scripts
    └── finalize-kairos.sh       # Post-installation scripts
```

### Build Process Flow

1. **Trigger**: Push to main/develop or manual workflow dispatch
2. **Factory Action**: Uses Kairos Factory Action to build images
3. **Configuration**: Applies your `osartifact.yaml` and `cloud-config.yaml`
4. **Security Scanning**: Automated vulnerability scanning with Grype/Trivy
5. **Artifacts**: Generates ISO, RAW, and other image formats
6. **Release**: Creates GitHub release with downloadable images

## Customization Options

### Method 1: Kairos Bundles (Recommended)

Add software packages via bundles in `packer/kairos/osartifact.yaml`:

```yaml
# Current bundles
bundles:
  - quay.io/kairos/packages:system-upgrade-controller
  - quay.io/kairos/packages:cert-manager
  # Add your bundles here
  - quay.io/kairos/packages:prometheus
  - quay.io/kairos/packages:grafana
  - quay.io/kairos/packages:longhorn
```

**Available bundles**: Browse at https://packages.kairos.io/

### Method 2: Cloud-Config Software Installation

Add software via `packer/kairos/cloud-config.yaml`:

```yaml
#cloud-config

# Install packages during boot
runcmd:
  - apt-get update
  - apt-get install -y htop vim curl jq
  - snap install docker
  - systemctl enable docker

# Add custom software scripts
write_files:
- content: |
    #!/bin/bash
    # Install custom application
    curl -L https://github.com/your-app/releases/download/v1.0/app.tar.gz | tar -xz -C /usr/local/bin/
  path: /usr/local/bin/install-custom-app.sh
  permissions: "0755"
  owner: root:root

# Run custom scripts
runcmd:
  - /usr/local/bin/install-custom-app.sh
```

### Method 3: Custom Bundles

Create custom bundles for complex software:

1. **Create a Dockerfile** in `packer/kairos/`:

```dockerfile
FROM scratch

# Add your application files
COPY my-app /usr/local/bin/my-app
COPY my-config.conf /etc/my-app/

# Set permissions
RUN chmod +x /usr/local/bin/my-app
```

2. **Build and push** to container registry
3. **Add to bundles** in `osartifact.yaml`:

```yaml
bundles:
  - your-registry.com/your-custom-bundle:latest
```

### Method 4: Kubernetes Applications

Deploy applications via K3s after installation:

```yaml
# In cloud-config.yaml
write_files:
- content: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: my-app
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: my-app
      template:
        metadata:
          labels:
            app: my-app
        spec:
          containers:
          - name: my-app
            image: my-app:latest
  path: /var/lib/rancher/k3s/server/manifests/my-app.yaml
  permissions: "0644"
```

### Configuration Parameters

#### osartifact.yaml Key Settings

```yaml
apiVersion: build.kairos.io/v1alpha2
kind: OSArtifact
metadata:
  name: beyond-devops-kairos
spec:
  # Image formats to generate
  iso: true          # Bootable ISO
  raw: true          # RAW disk image
  
  # Cloud image formats
  cloud_images:
    - raw
    - qcow2         # QEMU format
    
  # Bundles to include
  bundles:
    - quay.io/kairos/packages:your-package
    
  # Build configuration
  buildConfig:
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
```

#### Workflow Parameters

Customize the build via `.github/workflows/kairos-factory.yml`:

```yaml
env:
  VERSION: ${{ inputs.version || '1.0.0' }}
  BASE_IMAGE: ${{ inputs.base_image || 'ubuntu:22.04' }}
  ARCH: ${{ inputs.arch || 'amd64' }}

jobs:
  build-iso:
    uses: kairos-io/kairos-factory-action/.github/workflows/reusable-factory.yaml@v0.0.4
    with:
      version: ${{ env.VERSION }}
      base_image: ${{ env.BASE_IMAGE }}
      arch: ${{ env.ARCH }}
      kubernetes_distro: "k3s"
      security_checks: "grype,trivy"
```

## Build Process

### Automated Builds (Recommended)

#### Trigger via Git Push

1. **Make changes** to configuration files
2. **Commit and push** to main or develop branch:

```bash
git add packer/kairos/
git commit -m "Add custom software bundles"
git push origin main
```

3. **Monitor build** in GitHub Actions tab
4. **Download artifacts** from completed workflow

#### Manual Workflow Trigger

1. **Go to GitHub Actions** tab in your repository
2. **Select "Build Kairos Images with Factory Action"**
3. **Click "Run workflow"**
4. **Configure parameters**:
   - Version: `1.2.0` (or leave blank for auto-generated version)
   - Base image: `ubuntu:22.04` or `ubuntu:24.04`
   - Architecture: `amd64` or `arm64`
5. **Click "Run workflow"** button

#### Semantic Versioning with Git Tags

This project uses automatic semantic versioning:

**Development Builds**: Push commits → automatic dev versions (e.g., `v1.0.0-dev.abc123`)
```bash
git add .
git commit -m "Add custom bundles"
git push origin main
# → Builds version: v1.0.0-dev.abc123
```

**Official Releases**: Create git tags → official versions (e.g., `v1.1.0`)
```bash
git tag v1.1.0 -m "Release v1.1.0: Add monitoring bundles"
git push origin v1.1.0  
# → Builds version: v1.1.0 (creates GitHub release)
```

For detailed versioning guidelines, see [VERSION.md](VERSION.md).

### Build Monitoring

Monitor build progress:

1. **GitHub Actions tab** shows real-time logs
2. **Build jobs** run in parallel (ISO and RAW)
3. **Artifacts** available after successful completion
4. **Security scans** included in build process

### Local Testing (Optional)

For configuration validation:

```bash
# Validate YAML syntax
yamllint packer/kairos/osartifact.yaml
yamllint packer/kairos/cloud-config.yaml

# Test cloud-config locally (requires cloud-init)
cloud-init devel schema --config-file packer/kairos/cloud-config.yaml
```

## Installation Methods

### Method 1: ISO Installation (Bootable Media)

**Best for**: Physical servers, VMs, laptops

1. **Download ISO** from GitHub release or workflow artifacts
2. **Create bootable media**:

```bash
# Linux/macOS
sudo dd if=kairos-v1.0.0.iso of=/dev/sdX bs=4M status=progress

# Windows (use Rufus, Etcher, or similar tools)
```

3. **Boot from media** and follow installation prompts
4. **Configuration** applied automatically via cloud-config

### Method 2: RAW Image Deployment

**Best for**: VMs, cloud instances

#### QEMU/KVM

```bash
# Convert RAW to QCOW2 if needed
qemu-img convert -f raw -O qcow2 kairos.raw kairos.qcow2

# Create VM
qemu-system-x86_64 \
  -hda kairos.qcow2 \
  -m 4096 \
  -smp 2 \
  -netdev user,id=net0 \
  -device virtio-net,netdev=net0
```

#### VMware

```bash
# Convert RAW to VMDK
qemu-img convert -f raw -O vmdk kairos.raw kairos.vmdk

# Import in VMware Workstation/vSphere
```

#### VirtualBox

```bash
# Convert RAW to VDI
VBoxManage convertfromraw kairos.raw kairos.vdi --format VDI

# Create VM and attach disk
VBoxManage createvm --name "Kairos" --register
VBoxManage modifyvm "Kairos" --memory 4096 --cpus 2
VBoxManage storagectl "Kairos" --name "SATA" --add sata
VBoxManage storageattach "Kairos" --storagectl "SATA" --port 0 --device 0 --type hdd --medium kairos.vdi
```

### Method 3: Cloud Deployment

#### AWS EC2

```bash
# Upload image to S3
aws s3 cp kairos.raw s3://your-bucket/kairos.raw

# Import as AMI
aws ec2 import-image --description "Kairos OS" --disk-containers file://containers.json

# Launch instance
aws ec2 run-instances --image-id ami-xxxxxx --instance-type t3.medium
```

#### Google Cloud Platform

```bash
# Upload image
gsutil cp kairos.raw gs://your-bucket/kairos.raw

# Create image
gcloud compute images create kairos-v1 --source-uri gs://your-bucket/kairos.raw

# Create instance
gcloud compute instances create kairos-vm --image kairos-v1 --machine-type n1-standard-2
```

### Method 4: Network Boot (PXE)

**Best for**: Bare metal provisioning, large-scale deployments

1. **Extract kernel and initrd** from ISO
2. **Configure PXE server** with Kairos files
3. **Set up DHCP** to point to PXE server
4. **Network boot** target machines

## Post-Installation Configuration

### Initial System Setup

After installation, Kairos applies your cloud-config automatically. Verify setup:

```bash
# Check system status
sudo systemctl status k3s
sudo systemctl status docker

# Verify Kubernetes cluster
kubectl get nodes
kubectl get pods -A

# Check network configuration
ip addr show
```

### Network Configuration

#### Static IP Configuration

Edit cloud-config.yaml before building:

```yaml
#cloud-config
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.1.100/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

#### WiFi Configuration

```yaml
#cloud-config
network:
  version: 2
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "Your-WiFi-Name":
          password: "your-wifi-password"
```

### Kubernetes Cluster Setup

#### Single Node Cluster

Default configuration creates a single-node cluster. Verify:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

#### Multi-Node Cluster

For additional nodes, use the P2P token:

```yaml
# On additional nodes' cloud-config
p2p:
  network_token: "your-shared-token"
  auto:
    enable: true
```

### Adding Software Post-Installation

#### Via Package Manager

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install htop vim curl

# Container-based apps
docker run -d --name nginx nginx:latest
kubectl create deployment nginx --image=nginx
```

#### Via Helm Charts

```bash
# Install Helm
curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar -xzO linux-amd64/helm > /usr/local/bin/helm
chmod +x /usr/local/bin/helm

# Install applications
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
```

### User Management

Add users via cloud-config before building:

```yaml
#cloud-config
users:
- name: admin
  passwd: "$6$rounds=4096$salted$hash"  # Use mkpasswd to generate
  groups:
    - admin
    - docker
    - sudo
  ssh_authorized_keys:
    - ssh-rsa AAAAB3NzaC1yc2E... your-key
  shell: /bin/bash
```

### Storage Configuration

#### Additional Disks

```yaml
#cloud-config
disk_setup:
  /dev/sdb:
    table_type: gpt
    layout: true

fs_setup:
- label: data
  filesystem: ext4
  device: /dev/sdb1

mounts:
- ["/dev/sdb1", "/data", "ext4", "defaults", "0", "2"]
```

#### Persistent Storage for Kubernetes

Install Longhorn for persistent storage:

```yaml
# Add to bundles in osartifact.yaml
bundles:
  - quay.io/kairos/packages:longhorn
```

Or install post-deployment:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
```

## Troubleshooting & Maintenance

### Common Build Issues

#### Workflow Fails to Start

**Symptoms**: Workflow doesn't trigger on push
**Solutions**:
- Verify GitHub Actions are enabled
- Check workflow file syntax with yamllint
- Ensure push is to main/develop branch with changes to monitored paths

#### Permission Errors

**Symptoms**: "Permission denied" in workflow logs
**Solutions**:
- Check repository settings → Actions → General → Workflow permissions
- Ensure "Read and write permissions" is selected

#### Bundle Download Failures

**Symptoms**: Cannot download bundles during build
**Solutions**:
- Verify bundle exists at specified registry
- Check network connectivity
- Use alternative bundle sources

### Common Installation Issues

#### Boot Failures

**Symptoms**: System won't boot from ISO/media
**Solutions**:
- Verify ISO integrity with checksum
- Check BIOS/UEFI boot settings
- Try different bootable media creation tools

#### Network Issues

**Symptoms**: No network connectivity after installation
**Solutions**:
- Check network configuration in cloud-config
- Verify DHCP server if using automatic configuration
- Check physical network connections

#### Kubernetes Not Starting

**Symptoms**: K3s service fails to start
**Solutions**:
```bash
# Check service status
sudo systemctl status k3s
sudo journalctl -u k3s -f

# Common fixes
sudo systemctl restart k3s
sudo systemctl enable k3s

# Check resource availability
free -h
df -h
```

### System Updates

#### Kairos System Updates

Kairos uses immutable updates:

```bash
# Check for updates
sudo kairos-agent update check

# Apply updates
sudo kairos-agent update apply

# Reboot to new version
sudo reboot
```

#### Kubernetes Updates

Updates handled via system-upgrade-controller (included in your build):

```yaml
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: k3s-server
  namespace: system-upgrade
spec:
  concurrency: 1
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
  serviceAccountName: system-upgrade
  upgrade:
    image: rancher/k3s-upgrade
  version: v1.28.3+k3s1
```

### Backup and Recovery

#### System Backup

```bash
# Backup configuration
sudo tar -czf kairos-backup.tar.gz /etc/rancher /var/lib/rancher

# Backup user data
sudo tar -czf user-data-backup.tar.gz /home /opt
```

#### Recovery Mode

If system fails to boot:

1. **Boot from rescue ISO**
2. **Mount root filesystem**
3. **Restore configuration**
4. **Rebuild initramfs if needed**

### Performance Monitoring

#### Resource Monitoring

```bash
# System resources
htop
free -h
df -h
iostat -x 1

# Kubernetes resources
kubectl top nodes
kubectl top pods -A
```

#### Log Monitoring

```bash
# System logs
sudo journalctl -f
sudo journalctl -u k3s -f

# Application logs
kubectl logs -f deployment/your-app
```

### Debugging Workflows

#### View Build Logs

1. **GitHub Actions tab** → Select workflow run
2. **Click on job** (Build Kairos ISO/RAW)
3. **Expand steps** to see detailed logs
4. **Download logs** for offline analysis

#### Enable Debug Logging

Add to workflow environment:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Getting Help

#### Community Resources

- **Kairos Documentation**: https://kairos.io/docs/
- **GitHub Issues**: https://github.com/kairos-io/kairos/issues
- **Community Forum**: https://github.com/kairos-io/kairos/discussions

#### Enterprise Support

For enterprise environments:
- Review audit logs regularly
- Implement monitoring and alerting
- Maintain update schedules
- Document customizations
- Regular backup verification

---

## Summary

This guide covers the complete lifecycle of Kairos image customization, building, and deployment using the beyond-devops-os-factory framework. The streamlined Kairos Factory Action approach significantly simplifies the build process while maintaining enterprise-grade security and functionality.

Key benefits of this approach:
- **Simplified Workflow**: 90% reduction in complexity compared to traditional Packer builds
- **Built-in Security**: Automated vulnerability scanning and compliance
- **Multi-format Support**: ISO, RAW, and cloud-specific images
- **Enterprise Ready**: Scalable, auditable, and reproducible

For additional customization or support, refer to the troubleshooting section or community resources.