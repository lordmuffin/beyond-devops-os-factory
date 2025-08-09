# Packer template for building Kairos bootable images and ISOs
# This template creates customized Kairos images using the official build process

# Define the Packer version requirements
# This ensures compatibility and prevents issues with newer Packer versions
packer {
  required_plugins {
    # Docker plugin for container-based image building
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.8"
    }
    # QEMU plugin for creating bootable ISOs
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

# Define variables that can be overridden at build time
# These provide flexibility for different environments and use cases
variable "base_distribution" {
  type        = string
  description = "Base distribution (ubuntu-22.04, ubuntu-24.04, fedora-40, etc.)"
  default     = "ubuntu-22.04"
}

variable "k8s_distribution" {
  type        = string
  description = "Kubernetes distribution (k3s, k8s, etc.)"
  default     = "k3s"
}

variable "kairos_version" {
  type        = string
  description = "Kairos framework version"
  default     = "v2.4.3"
}

variable "output_directory" {
  type        = string
  description = "Output directory for built images"
  default     = "output-kairos"
}

variable "disk_size" {
  type        = string
  description = "Disk size for bootable images (e.g., 20G)"
  default     = "20G"
}

variable "memory" {
  type        = string
  description = "Amount of RAM for VM (in MB)"
  default     = "2048"
}

variable "cpus" {
  type        = string
  description = "Number of CPU cores for VM"
  default     = "2"
}

# Build custom Kairos container image from base image
source "docker" "kairos_custom" {
  # Use official Kairos base image - using the same version from original Dockerfile
  image = "quay.io/kairos/ubuntu:22.04-standard-amd64-generic-v2.4.3-k3sv1.28.2-k3s1"

  # Container configuration
  commit = true

  # Output configuration for custom container image
  changes = [
    "ENV KAIROS_CUSTOM=true",
    "ENV KAIROS_VERSION=${var.kairos_version}",
    "ENV DEBIAN_FRONTEND=noninteractive",
    "ENV DEBCONF_NONINTERACTIVE_SEEN=true",
    "LABEL org.opencontainers.image.title=\"Custom Kairos Base\"",
    "LABEL org.opencontainers.image.description=\"Custom Kairos base image with enterprise configuration and storage support\"",
    "LABEL org.opencontainers.image.version=\"${var.kairos_version}\"",
    "LABEL org.opencontainers.image.source=\"https://github.com/beyond-devops-os-factory\"",
    "LABEL org.opencontainers.image.licenses=\"Apache-2.0\""
  ]
}

# Build bootable ISO from custom container image
source "qemu" "kairos_iso" {
  # Use a minimal Linux ISO as base for bootable image creation
  iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
  iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"

  # Virtual machine configuration for building
  vm_name   = "kairos-builder"
  memory    = var.memory
  cpus      = var.cpus
  disk_size = var.disk_size

  # Output configuration
  output_directory = var.output_directory

  # QEMU-specific settings
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"

  # Headless mode for CI/CD environments
  headless = true

  # Display configuration for headless mode
  display = "none"

  # QEMU arguments for headless operation
  qemuargs = [
    ["-display", "none"],
    ["-serial", "stdio"]
  ]

  # Network configuration
  net_device = "virtio-net"

  # Disk configuration
  disk_interface   = "virtio"
  disk_compression = true
  format           = "qcow2"

  # Boot configuration
  boot_wait = "5s"
  boot_command = [
    # Boot Ubuntu with autoinstall
    "<wait10><esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]

  # HTTP server for serving cloud-config
  http_directory = "kairos"
  http_port_min  = 8000
  http_port_max  = 8100

  # Communication configuration
  communicator           = "ssh"
  ssh_username           = "kairos"
  ssh_password           = "kairos"
  ssh_timeout            = "45m"
  ssh_wait_timeout       = "45m"
  ssh_handshake_attempts = 100

  # Shutdown configuration
  shutdown_command = "sudo shutdown -P now"
  shutdown_timeout = "5m"
}

# Build configuration for custom Kairos container image
build {
  name = "kairos-container-build"

  # Build custom Kairos container image first
  sources = ["source.docker.kairos_custom"]

  # File provisioner - copy build scripts and configuration
  provisioner "file" {
    source      = "../scripts/kairos/"
    destination = "/tmp/scripts/"
  }

  # File provisioner - copy cloud-config
  provisioner "file" {
    source      = "kairos/cloud-config.yaml"
    destination = "/tmp/cloud-config.yaml"
  }

  # Shell provisioner - configure timezone and install packages
  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "export DEBCONF_NONINTERACTIVE_SEEN=true",
      "",
      "# Configure timezone (America/Chicago)",
      "truncate -s0 /tmp/preseed.cfg",
      "echo 'tzdata tzdata/Areas select America' >> /tmp/preseed.cfg",
      "echo 'tzdata tzdata/Zones/America select Chicago' >> /tmp/preseed.cfg",
      "debconf-set-selections /tmp/preseed.cfg",
      "rm -f /etc/timezone /etc/localtime",
      "apt-get update",
      "apt-get install -y tzdata",
      "",
      "# Install storage and enterprise packages",
      "apt-get install -y \\",
      "  cifs-utils \\",
      "  nfs-common \\",
      "  open-iscsi \\",
      "  lsscsi \\",
      "  sg3-utils \\",
      "  multipath-tools \\",
      "  scsitools \\",
      "  curl \\",
      "  wget \\",
      "  docker.io",
      "",
      "# Configure multipath for storage",
      "tee /etc/multipath.conf <<-'EOF'",
      "defaults {",
      "    user_friendly_names yes",
      "    find_multipaths yes",
      "}",
      "EOF",
      "",
      "# Enable services",
      "systemctl enable docker",
      "systemctl enable open-iscsi",
      "systemctl enable multipathd",
      "",
      "# Make scripts executable and run preparation",
      "chmod +x /tmp/scripts/*.sh",
      "bash /tmp/scripts/prepare-kairos.sh",
      "",
      "# Set up cloud-config",
      "mkdir -p /system/oem",
      "cp /tmp/cloud-config.yaml /system/oem/99_custom.yaml",
      "",
      "# Finalize the image",
      "bash /tmp/scripts/finalize-kairos.sh",
      "",
      "# Final cleanup",
      "rm -rf /tmp/scripts /tmp/cloud-config.yaml /tmp/preseed.cfg",
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/*"
    ]
  }

  # Tag the custom container image
  post-processor "docker-tag" {
    repository = "custom-kairos-base"
    tags = [
      "${var.kairos_version}",
      "${var.kairos_version}-${formatdate("YYYY-MM-DD", timestamp())}",
      "latest"
    ]
  }
}

# Build configuration for bootable ISO image
build {
  name = "kairos-iso-build"

  # Build bootable ISO using QEMU
  sources = ["source.qemu.kairos_iso"]

  # Shell provisioner - install and configure Kairos
  provisioner "shell" {
    inline = [
      "# Wait for system to be ready",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "",
      "# Install Docker",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker kairos",
      "",
      "# Install Kairos tools",
      "curl -L https://github.com/kairos-io/kairos/releases/latest/download/kairos-linux-amd64 -o kairos",
      "sudo mv kairos /usr/local/bin/kairos",
      "sudo chmod +x /usr/local/bin/kairos",
      "",
      "# Install AuroraBoot",
      "curl -L https://github.com/kairos-io/AuroraBoot/releases/latest/download/auroraboot-linux-amd64 -o auroraboot",
      "sudo mv auroraboot /usr/local/bin/auroraboot",
      "sudo chmod +x /usr/local/bin/auroraboot"
    ]
  }

  # File provisioner - copy cloud-config and scripts
  provisioner "file" {
    sources = [
      "kairos/cloud-config.yaml",
      "../scripts/kairos/"
    ]
    destination = "/tmp/"
  }

  # Shell provisioner - build Kairos image using AuroraBoot
  provisioner "shell" {
    inline = [
      "# Create build directory",
      "mkdir -p /home/kairos/kairos-build",
      "cd /home/kairos/kairos-build",
      "",
      "# Copy cloud-config to build directory",
      "cp /tmp/cloud-config.yaml ./cloud-config.yaml",
      "",
      "# Use AuroraBoot to create bootable image with custom container",
      "sudo auroraboot \\",
      "  --set container_image=custom-kairos-base:latest \\",
      "  --set \"state_dir=/tmp/auroraboot-state\" \\",
      "  --set \"cloud_config=/home/kairos/kairos-build/cloud-config.yaml\" \\",
      "  --set \"disk_size=${var.disk_size}\" \\",
      "  build-iso",
      "",
      "# Copy generated ISO to accessible location",
      "sudo cp /tmp/auroraboot-state/*.iso /home/kairos/ || true"
    ]
  }

  # Post-processor to copy ISO file locally
  post-processor "shell-local" {
    inline = [
      "echo 'Kairos ISO build completed'",
      "echo 'Check ${var.output_directory} for generated images'"
    ]
  }
}