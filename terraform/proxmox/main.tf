terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66.0"
    }
  }
}

# Provider configuration for Proxmox VE
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_api_insecure
  
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}2