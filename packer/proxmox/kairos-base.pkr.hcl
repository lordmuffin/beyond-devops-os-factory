# Packer template for creating Kairos base VM template on Proxmox
# This template creates a minimal VM that can be used with AuroraBoot for Kairos deployment

packer {
  required_plugins {
    proxmox = {
      version = "~> 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

# SSH credentials for the VM during build
variable "ssh_username" {
  description = "SSH username for VM access during build"
  type        = string
  default     = "packer"
}

variable "ssh_password" {
  description = "SSH password for VM access during build" 
  type        = string
  default     = "packer"
  sensitive   = true
}

variable "vm_name" {
  description = "Name of the VM template"
  type        = string
  default     = "kairos-base-template"
}

variable "template_description" {
  description = "Description for the VM template"
  type        = string
  default     = "Base template for Kairos deployment with AuroraBoot"
}

variable "iso_file" {
  description = "Path to Ubuntu ISO on Proxmox storage"
  type        = string
  default     = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# Local variables for build configuration
locals {
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
  
  # Build metadata
  build_info = {
    built_by    = "Packer"
    built_on    = local.timestamp
    purpose     = "kairos-auroraboot-base"
    os_family   = "ubuntu"
    k8s_ready   = "true"
  }
}

# Proxmox ISO builder for Ubuntu base template
source "proxmox-iso" "kairos-base" {
  # Proxmox connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM configuration
  vm_name              = "${var.vm_name}-${local.timestamp}"
  template_name        = var.vm_name
  template_description = "${var.template_description} - Built ${local.timestamp}"

  # Hardware configuration
  memory    = 4096
  cores     = 2
  sockets   = 1
  cpu_type  = "kvm64"
  bios      = "seabios"
  qemu_agent = true
  
  # Note: EFI disabled since we're using SeaBIOS for software emulation compatibility

  # Disk configuration
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "32G"
    storage_pool = var.storage_pool
    format       = "raw"
    cache_mode   = "writeback"
    io_thread    = true
  }

  # Network configuration
  network_adapters {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = false
  }

  # ISO configuration
  iso_file         = var.iso_file
  unmount_iso      = true
  iso_storage_pool = "local"

  # Cloud-init configuration
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  # Boot configuration
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  # HTTP server for autoinstall
  http_directory = "${path.root}/http"
  http_port_min  = 8000
  http_port_max  = 8100

  # SSH configuration
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = "20m"

  # Shutdown configuration
  # shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  # Task configuration
  task_timeout = "10m"
  
  # VM settings
  onboot   = false
  os       = "other"
  tags     = "packer;template;kairos;ubuntu"
}

# Build configuration
build {
  name = "kairos-base-template"
  
  sources = [
    "source.proxmox-iso.kairos-base"
  ]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "echo 'Cloud-init completed successfully'"
    ]
  }

  # Update system packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y qemu-guest-agent curl wget jq",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent"
    ]
  }

  # Install Docker for container support
  provisioner "shell" {
    inline = [
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker packer",
      "sudo systemctl enable docker",
      "sudo systemctl start docker"
    ]
  }

  # Configure system for Kairos compatibility
  provisioner "shell" {
    inline = [
      "# Enable IP forwarding for Kubernetes",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.conf",
      "",
      "# Load br_netfilter module",
      "echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf",
      "",
      "# Disable swap for Kubernetes compatibility",
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab",
      "",
      "# Configure systemd for container runtime",
      "sudo mkdir -p /etc/systemd/system/docker.service.d",
      "",
      "# Create directory for AuroraBoot downloads",
      "sudo mkdir -p /opt/auroraboot/images",
      "sudo chown packer:packer /opt/auroraboot/images"
    ]
  }

  # Install AuroraBoot dependencies
  provisioner "shell" {
    inline = [
      "# Install container tools for image handling",
      "sudo apt-get install -y skopeo buildah podman",
      "",
      "# Create AuroraBoot configuration directory",
      "sudo mkdir -p /etc/auroraboot",
      "sudo chown packer:packer /etc/auroraboot",
      "",
      "# Install gh CLI for GitHub releases",
      "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg",
      "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list",
      "sudo apt-get update",
      "sudo apt-get install -y gh"
    ]
  }

  # Create template preparation script
  provisioner "file" {
    content = templatefile("${path.root}/scripts/prepare-auroraboot.sh.tpl", {
      build_timestamp = local.timestamp
    })
    destination = "/tmp/prepare-auroraboot.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/prepare-auroraboot.sh /usr/local/bin/",
      "sudo chmod +x /usr/local/bin/prepare-auroraboot.sh"
    ]
  }

  # Clean up before template creation
  provisioner "shell" {
    inline = [
      "# Clean package cache",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "",
      "# Clean logs",
      "sudo truncate -s 0 /var/log/*.log",
      "sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} \\;",
      "",
      "# Clean SSH host keys (will be regenerated on first boot)",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "",
      "# Clean machine-id (will be regenerated)",
      "sudo truncate -s 0 /etc/machine-id",
      "",
      "# Clean bash history",
      "history -c",
      "cat /dev/null > ~/.bash_history",
      "",
      "# Clean cloud-init logs and cache",
      "sudo cloud-init clean --logs --seed",
      "",
      "# Sync filesystem",
      "sync"
    ]
  }

  # Create build manifest
  post-processor "manifest" {
    output = "${path.root}/manifests/kairos-base-${local.timestamp}.json"
    strip_path = true
    custom_data = local.build_info
  }
}