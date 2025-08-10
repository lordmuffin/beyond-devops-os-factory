output "vm_id" {
  description = "ID of the created VM"
  value       = proxmox_virtual_environment_vm.kairos_vm.id
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_virtual_environment_vm.kairos_vm.name
}

output "vm_node_name" {
  description = "Proxmox node where VM is deployed"
  value       = proxmox_virtual_environment_vm.kairos_vm.node_name
}

output "vm_ipv4_addresses" {
  description = "IPv4 addresses assigned to the VM"
  value       = proxmox_virtual_environment_vm.kairos_vm.ipv4_addresses
}

output "vm_ipv6_addresses" {
  description = "IPv6 addresses assigned to the VM"
  value       = proxmox_virtual_environment_vm.kairos_vm.ipv6_addresses
}

output "vm_mac_addresses" {
  description = "MAC addresses of the VM network interfaces"
  value       = proxmox_virtual_environment_vm.kairos_vm.mac_addresses
}

output "vm_status" {
  description = "Current status of the VM"
  value       = proxmox_virtual_environment_vm.kairos_vm.status
}

output "kairos_ssh_connection" {
  description = "SSH connection string for the Kairos VM"
  value       = length(proxmox_virtual_environment_vm.kairos_vm.ipv4_addresses[1]) > 0 ? "ssh kairos@${proxmox_virtual_environment_vm.kairos_vm.ipv4_addresses[1][0]}" : "VM IP not available"
}

output "k3s_kubeconfig_access" {
  description = "Command to access K3s cluster"
  value       = length(proxmox_virtual_environment_vm.kairos_vm.ipv4_addresses[1]) > 0 ? "scp kairos@${proxmox_virtual_environment_vm.kairos_vm.ipv4_addresses[1][0]}:/etc/rancher/k3s/k3s.yaml ./kubeconfig" : "VM IP not available"
}

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    vm_name        = proxmox_virtual_environment_vm.kairos_vm.name
    vm_id          = proxmox_virtual_environment_vm.kairos_vm.id
    node           = proxmox_virtual_environment_vm.kairos_vm.node_name
    cpu_cores      = proxmox_virtual_environment_vm.kairos_vm.cpu[0].cores
    memory         = "${proxmox_virtual_environment_vm.kairos_vm.memory[0].dedicated}MB"
    disk_size      = proxmox_virtual_environment_vm.kairos_vm.disk[0].size
    storage        = proxmox_virtual_environment_vm.kairos_vm.disk[0].datastore_id
    network_bridge = proxmox_virtual_environment_vm.kairos_vm.network_device[0].bridge
    tags           = proxmox_virtual_environment_vm.kairos_vm.tags
    started        = proxmox_virtual_environment_vm.kairos_vm.started
  }
}