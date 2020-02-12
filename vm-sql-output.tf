#######################################
## Azure VM with SQL Module - Output ##
#######################################

output "sql_vm_name" {
  description = "Virtual Machine name"
  value       = azurerm_virtual_machine.sql-vm.name
}

output "sql_vm_ip_address" {
  description = "Virtual Machine name IP Address"
  value       = azurerm_public_ip.sql-vm-ip.ip_address
}

output "sql_vm_admin_username" {
  description = "Username password for the Virtual Machine"
  value       = azurerm_virtual_machine.sql-vm.os_profile.*
  #sensitive   = true
}

output "sql_vm_admin_password" {
  description = "Administrator password for the Virtual Machine"
  value       = random_password.sql-vm-password.result
  #sensitive   = true
}

