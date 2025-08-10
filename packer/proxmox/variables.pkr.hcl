# Packer variables file for Proxmox Kairos base template

# Proxmox connection variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = env("PROXMOX_API_URL")
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  default     = env("PROXMOX_API_TOKEN_ID")
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  default     = env("PROXMOX_API_TOKEN_SECRET")
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = env("PROXMOX_NODE")
}

variable "proxmox_username" {
  description = "Proxmox SSH username"
  type        = string
  default     = "root"
}

variable "proxmox_password" {
  description = "Proxmox SSH password (optional when using API tokens)"
  type        = string
  default     = ""
  sensitive   = true
}

# VM template configuration
variable "vm_name" {
  description = "Name of the VM template"
  type        = string
  default     = "kairos-base-template"
}

variable "template_description" {
  description = "Description for the VM template"
  type        = string
  default     = "Base template for Kairos deployment with AuroraBoot support"
}

variable "iso_file" {
  description = "Path to Ubuntu ISO on Proxmox storage"
  type        = string
  default     = "local:iso/ubuntu-22.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  description = "Checksum for the ISO file"
  type        = string
  default     = "sha256:45f873de9f8cb637345d6e66a583762730bbea30277ef7b32c9c3bd6700a32b2"
}

variable "storage_pool" {
  description = "Proxmox storage pool"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# Hardware configuration
variable "vm_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size"
  type        = string
  default     = "32G"
}

# Build configuration
variable "ssh_username" {
  description = "SSH username for the template"
  type        = string
  default     = "packer"
}

variable "ssh_password" {
  description = "SSH password for the template"
  type        = string
  default     = "packer"
  sensitive   = true
}

variable "ssh_timeout" {
  description = "SSH timeout"
  type        = string
  default     = "20m"
}

# Tag configuration
variable "vm_tags" {
  description = "Tags for the VM template"
  type        = list(string)
  default     = ["packer", "template", "kairos", "ubuntu", "auroraboot"]
}