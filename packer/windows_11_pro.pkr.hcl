# Packer template for building Windows 11 Pro images on Azure
# This template creates a customized Windows 11 Pro image with enterprise-ready configurations

# Define the Packer version requirements
# This ensures compatibility and prevents issues with newer Packer versions
packer {
  required_plugins {
    # Azure Resource Manager plugin for creating Azure-based images
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
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
variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID where the image will be created"
  default     = env("AZURE_SUBSCRIPTION_ID")
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure tenant ID for authentication"
  default     = env("AZURE_TENANT_ID")
}

variable "azure_client_id" {
  type        = string
  description = "Azure service principal client ID"
  default     = env("AZURE_CLIENT_ID")
}

variable "azure_client_secret" {
  type        = string
  description = "Azure service principal client secret"
  default     = env("AZURE_CLIENT_SECRET")
  sensitive   = true
}

variable "resource_group_name" {
  type        = string
  description = "Azure resource group name for image storage"
  default     = "rg-packer-images"
}

variable "location" {
  type        = string
  description = "Azure region where resources will be created"
  default     = "East US"
}

# Define the source configuration for the Windows 11 Pro base image
# This specifies which Azure marketplace image to use as the foundation
source "azure-arm" "windows_11_pro" {
  # Authentication configuration using service principal
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  # Resource configuration - where to create temporary resources during build
  managed_image_resource_group_name = var.resource_group_name
  managed_image_name               = "windows-11-pro-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  location                        = var.location

  # Base image configuration - Windows 11 Pro 23H2 from Microsoft
  # These values specify the exact marketplace image to use
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "Windows-11"
  image_sku       = "win11-23h2-pro"
  image_version   = "latest"

  # Virtual machine configuration for the build process
  # These settings determine the temporary VM used to customize the image
  vm_size         = "Standard_D2s_v3"  # 2 vCPUs, 8GB RAM - sufficient for most customizations
  os_type         = "Windows"

  # WinRM configuration for remote connectivity during provisioning
  # This enables Packer to connect to the Windows VM and run provisioning scripts
  communicator     = "winrm"
  winrm_use_ssl    = true
  winrm_insecure   = true
  winrm_timeout    = "10m"
  winrm_username   = "packer"

  # Azure-specific settings for image creation
  # These control how the final image is stored and tagged
  managed_image_storage_account_type = "Premium_LRS"
  
  # Tags for resource management and cost tracking
  azure_tags = {
    Environment = "Production"
    Project     = "Windows11ProFactory"
    CreatedBy   = "Packer"
    CreatedOn   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Define the build configuration that orchestrates the provisioning process
# This section specifies the sequence of steps to customize the base image
build {
  name = "windows-11-pro-build"
  
  # Reference the source configuration defined above
  sources = ["source.azure-arm.windows_11_pro"]

  # PowerShell provisioner - executes Windows-specific configuration scripts
  # This runs first to handle Windows-native tasks and tool installations
  provisioner "powershell" {
    # Execute the common tools installation script
    script = "provisioning/powershell/install-common-tools.ps1"
    
    # Execution policy settings for security
    execution_policy = "Bypass"
    
    # Timeout configuration to prevent hanging builds
    timeout = "30m"
  }

  # Ansible provisioner - handles complex configuration management
  # This runs after PowerShell to apply configuration management practices
  provisioner "ansible" {
    # Path to the Ansible playbook
    playbook_file = "provisioning/ansible/playbook.yml"
    
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

  # Post-processor for image cleanup and optimization (optional)
  # Uncomment if you want to perform additional post-build processing
  # post-processor "shell-local" {
  #   inline = [
  #     "echo 'Image build completed successfully'",
  #     "echo 'Image name: windows-11-pro-${formatdate(\"YYYY-MM-DD-hhmm\", timestamp())}'"
  #   ]
  # }
}