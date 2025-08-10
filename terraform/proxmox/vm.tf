# Create Kairos VM on Proxmox
resource "proxmox_virtual_environment_vm" "kairos_vm" {
  name        = var.vm_name
  description = var.vm_description
  node_name   = var.proxmox_node_name
  
  # VM lifecycle configuration
  on_boot    = var.vm_on_boot
  protection = var.vm_protection
  started    = true
  tags       = var.vm_tags

  # Agent configuration for better VM management
  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  # CPU configuration
  cpu {
    cores   = var.vm_cpu_cores
    sockets = var.vm_cpu_sockets
    type    = "x86-64-v2-AES"
  }

  # Memory configuration
  memory {
    dedicated = var.vm_memory
  }

  # Network configuration
  network_device {
    bridge      = var.vm_network_bridge
    mac_address = null  # Auto-generate MAC address
    model       = var.vm_network_model
    vlan_id     = var.vm_network_vlan
  }

  # Primary disk configuration
  disk {
    datastore_id = var.vm_storage
    file_id      = null  # Will be set after initial installation
    interface    = "scsi0"
    size         = var.vm_disk_size
    ssd          = true
    discard      = "on"
  }

  # CD-ROM for Kairos ISO
  cdrom {
    enabled   = true
    file_id   = var.kairos_iso_path
    interface = "ide2"
  }

  # Boot configuration
  boot_order = var.vm_boot_order

  # VGA configuration for console access
  vga {
    enabled = true
    memory  = 16
    type    = "std"
  }

  # BIOS settings
  bios = "ovmf"  # UEFI boot for modern OS support
  
  # EFI disk for UEFI boot
  efi_disk {
    datastore_id = var.vm_storage
    file_format  = "raw"
    type         = "4m"
  }

  # Machine type
  machine = "q35"

  # Tablet device for better console interaction
  tablet_device = true

  # Wait for network to be ready
  timeout_clone           = 300
  timeout_move_disk       = 300
  timeout_reboot          = 300
  timeout_shutdown_vm     = 300
  timeout_start_vm        = 300
  timeout_stop_vm         = 300
  timeout_create          = 600

  lifecycle {
    ignore_changes = [
      # Ignore changes to these attributes after creation
      cdrom,
      boot_order,
    ]
  }
}

# File upload for Kairos ISO (if using local upload)
resource "proxmox_virtual_environment_file" "kairos_iso" {
  count = var.auroraboot_enabled ? 0 : 1  # Skip if using AuroraBoot

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node_name

  source_file {
    path = "./images/kairos-custom.iso"
  }
}

# Cloud-init configuration file upload
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node_name

  source_raw {
    data      = templatefile(var.auroraboot_cloud_config_path, {
      vm_name           = var.vm_name
      ssh_public_key    = file("~/.ssh/id_rsa.pub")
      network_bridge    = var.vm_network_bridge
      github_repo       = var.kairos_github_repo
      kairos_version    = var.kairos_image_version
    })
    file_name = "${var.vm_name}-cloud-config.yaml"
  }
}

# Data source to get VM information after creation
data "proxmox_virtual_environment_vm" "kairos_vm_info" {
  depends_on = [proxmox_virtual_environment_vm.kairos_vm]
  
  node_name = var.proxmox_node_name
  vm_id     = proxmox_virtual_environment_vm.kairos_vm.id
}