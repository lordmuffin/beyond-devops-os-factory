# Packer template for building Windows 11 Pro images using QEMU/KVM
# This template creates a customized Windows 11 Pro image with enterprise-ready configurations

# Define the Packer version requirements
# This ensures compatibility and prevents issues with newer Packer versions
packer {
  required_plugins {
    # QEMU plugin for virtualization-based image building
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
    # Ansible plugin for configuration management
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Define variables that can be overridden at build time
# These provide flexibility for different environments and use cases
variable "iso_url" {
  type        = string
  description = "URL to Windows 11 Pro ISO file"
  default     = "https://software.download.prss.microsoft.com/dbazure/Win11_24H2_English_x64.iso?t=39bce123-5777-4213-a4a7-7c1bdf0a2aa7&P1=1754784648&P2=601&P3=2&P4=hbItu7HZSxFta%2boDCVyOGZxStAK%2ff4VFMtxiiEYbAmiJxRn3fJhb6el2sJtwRUwkN9VyKIOflD%2fbJ5emFH6CrUmQIGPLfM3t5inuse7BkCqG7TkX%2fB134l3DcFzdtZe%2bHQgP1LjKZsOIonTfSkQe0teyc%2fScIj7e0zF7%2bHitacjIXBTSWcABWtXydPiBL81n9AD6Y75PAsazCcbmrG8CYQsFwXsjRANagHIO%2fvJm1YX1A%2fO14krLy%2fH3rgMkgypGRLdZaqTNpUwW10C0l4AK2Pw24V1tirpb8IroGPGMOLrMphAKlODY0PP%2ffYm%2fAKWs4PfFm8kXdK3NDAjkcaSxNQ%3d%3d"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the Windows 11 Pro ISO"
  default     = "B56B911BF18A2CEAEB3904D87E7C770BDF92D3099599D61AC2497B91BF190B11"
}

variable "vm_name" {
  type        = string
  description = "Name for the virtual machine and output files"
  default     = "windows-11-pro-custom"
}

variable "disk_size" {
  type        = string
  description = "Size of the virtual disk (e.g., 40G)"
  default     = "50G"
}

variable "memory" {
  type        = string
  description = "Amount of RAM for the VM (in MB)"
  default     = "4096"
}

variable "cpus" {
  type        = string
  description = "Number of CPU cores for the VM"
  default     = "2"
}

# Define the source configuration for the Windows 11 Pro base image
# This specifies the QEMU/KVM virtualization settings for building the image
source "qemu" "windows_11_pro" {
  # ISO configuration - Windows 11 Pro installation media
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Virtual machine configuration
  vm_name      = var.vm_name
  memory       = var.memory
  cpus         = var.cpus
  disk_size    = var.disk_size
  
  # Output configuration
  output_directory = "output-windows-custom"
  
  # QEMU-specific settings
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  
  # Network configuration for provisioning
  net_device = "virtio-net"
  
  # Disk and boot configuration
  disk_interface   = "virtio"
  disk_compression = true
  format          = "qcow2"
  
  # Boot configuration
  boot_wait = "3m"
  boot_command = [
    # Boot commands will be added here for unattended installation
    # This requires an autounattend.xml file for Windows automation
  ]

  # Communication configuration for provisioning
  communicator = "winrm"
  winrm_username = "Administrator"
  winrm_password = "packer"
  winrm_timeout = "12h"
  winrm_use_ssl = false
  winrm_insecure = true
  winrm_use_ntlm = true
  
  # Shutdown configuration
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout = "15m"
}

# Define the build configuration that orchestrates the provisioning process
# This section specifies the sequence of steps to customize the base image
build {
  name = "windows-11-pro-build"
  
  # Reference the source configuration defined above
  sources = ["source.qemu.windows_11_pro"]

  # PowerShell provisioner - executes Windows-specific configuration scripts
  # This runs first to handle Windows-native tasks and tool installations
  provisioner "powershell" {
    # Execute the common tools installation script
    script = "../scripts/prepare-windows.ps1"
    
    # Execution policy settings for security
    execution_policy = "bypass"
    
    # Timeout configuration to prevent hanging builds
    timeout = "30m"
  }

  # Ansible provisioner - handles complex configuration management
  # This runs after PowerShell to apply configuration management practices
  provisioner "ansible" {
    # Path to the Ansible playbook
    playbook_file = "../ansible/playbook.yml"
    
    # Connection configuration for Windows targets
    use_proxy = false
    
    # Ansible-specific settings for Windows
    extra_arguments = [
      "--connection", "winrm",
      "--winrm-transport", "ntlm",
      "--winrm-server-cert-validation", "ignore"
    ]
    
    # Timeout configuration
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_SSH_RETRIES=5"
    ]
  }

  # PowerShell provisioner - finalizes the image preparation
  # This runs last to clean up and prepare for Sysprep
  provisioner "powershell" {
    # Execute the image finalization script
    script = "../scripts/finalize-windows.ps1"
    
    # Execution policy settings for security
    execution_policy = "bypass"
    
    # Timeout configuration - Sysprep process can take time
    timeout = "60m"
  }

  # Post-processor for image cleanup and optimization (optional)
  # Uncomment if you want to perform additional post-build processing
  # post-processor "shell-local" {
  #   inline = [
  #     "echo 'Image build completed successfully'",
  #     "echo 'Image name: windows-11-pro-${formatdate(\"YYYY-MM-DD-hhmm\", timestamp())}'"
  #   ]
  # }
}