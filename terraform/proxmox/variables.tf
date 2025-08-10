# Proxmox connection variables
variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006/api2/json)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@realm!tokenname=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_insecure" {
  description = "Disable TLS verification for Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox node access"
  type        = string
  default     = "root"
}

# VM configuration variables
variable "vm_name" {
  description = "Name for the Kairos VM"
  type        = string
  default     = "kairos-vm"
}

variable "vm_description" {
  description = "Description for the VM"
  type        = string
  default     = "Kairos OS VM deployed with AuroraBoot"
}

variable "proxmox_node_name" {
  description = "Proxmox node name to deploy VM on"
  type        = string
  default     = "pve"
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores for the VM"
  type        = number
  default     = 2
}

variable "vm_cpu_sockets" {
  description = "Number of CPU sockets for the VM"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory for the VM in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Size of the VM disk in GB"
  type        = string
  default     = "32G"
}

variable "vm_storage" {
  description = "Proxmox storage for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_network_bridge" {
  description = "Network bridge for VM"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_model" {
  description = "Network model for VM"
  type        = string
  default     = "virtio"
}

variable "vm_network_vlan" {
  description = "VLAN tag for VM network (optional)"
  type        = number
  default     = null
}

variable "kairos_iso_path" {
  description = "Path to Kairos ISO on Proxmox storage"
  type        = string
  default     = "local:iso/kairos-custom.iso"
}

variable "vm_boot_order" {
  description = "Boot order for the VM"
  type        = list(string)
  default     = ["order=scsi0", "order=ide2"]
}

variable "vm_tags" {
  description = "Tags for the VM"
  type        = list(string)
  default     = ["kairos", "k3s", "enterprise"]
}

variable "vm_on_boot" {
  description = "Start VM on Proxmox boot"
  type        = bool
  default     = true
}

variable "vm_protection" {
  description = "Enable VM protection (prevents accidental deletion)"
  type        = bool
  default     = false
}

# AuroraBoot configuration
variable "auroraboot_enabled" {
  description = "Enable AuroraBoot for automated deployment"
  type        = bool
  default     = true
}

variable "auroraboot_cloud_config_path" {
  description = "Path to cloud-config file for AuroraBoot"
  type        = string
  default     = "./auroraboot/cloud-config.yaml"
}

variable "kairos_github_repo" {
  description = "GitHub repository for Kairos images"
  type        = string
  default     = "your-org/beyond-devops-os-factory"
}

variable "kairos_image_version" {
  description = "Kairos image version to deploy (latest if empty)"
  type        = string
  default     = ""
}