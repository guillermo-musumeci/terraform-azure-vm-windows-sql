#####################################
## Azure VM with SQL Module - Main ##
#####################################

# Generate random password
resource "random_password" "sql-vm-password" {
  length           = 16
  min_upper        = 2
  min_lower        = 2
  min_special      = 2
  number           = true
  special          = true
  override_special = "!@#$%&"
}

# Generate a random vm name
resource "random_string" "sql-vm-name" {
  length  = 8
  upper   = false
  number  = false
  lower   = true
  special = false
}

# Create Security Group to access SQL
resource "azurerm_network_security_group" "sql-vm-nsg" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "sql-${lower(var.environment)}-${random_string.sql-vm-name.result}-nsg"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name

  security_rule {
    name                       = "AllowSQL"
    description                = "Allow SQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDP"
    description                = "Allow RDP"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  tags = {
    environment = var.environment
  }
}

# Associate the SQL NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "sql-vm-nsg-association" {
  depends_on=[azurerm_resource_group.network-rg]

  subnet_id                 = azurerm_subnet.network-subnet.id
  network_security_group_id = azurerm_network_security_group.sql-vm-nsg.id
}

# Get a Static Public IP
resource "azurerm_public_ip" "sql-vm-ip" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "sql-${random_string.sql-vm-name.result}-ip"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  allocation_method   = "Static"
  
  tags = { 
    environment = var.environment
  }
}

# Create Network Card for SQL VM
resource "azurerm_network_interface" "sql-private-nic" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "sql-${random_string.sql-vm-name.result}-nic"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.network-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sql-vm-ip.id
  }

  tags = { 
    environment = var.environment
  }
}

# Create a Windows VM with sql
resource "azurerm_virtual_machine" "sql-vm" {
  depends_on=[azurerm_network_interface.sql-private-nic]

  location              = azurerm_resource_group.network-rg.location
  resource_group_name   = azurerm_resource_group.network-rg.name
  name                  = "sql-${random_string.sql-vm-name.result}-vm"
  network_interface_ids = [azurerm_network_interface.sql-private-nic.id]
  vm_size               = var.sql_vm_size
  license_type          = var.sql_license_type

  delete_os_disk_on_termination    = var.sql_delete_os_disk_on_termination
  delete_data_disks_on_termination = var.sql_delete_data_disks_on_termination

  storage_image_reference {
    id        = lookup(var.sql_vm_image, "id", null)
    offer     = lookup(var.sql_vm_image, "offer", null)
    publisher = lookup(var.sql_vm_image, "publisher", null)
    sku       = lookup(var.sql_vm_image, "sku", null)
    version   = lookup(var.sql_vm_image, "version", null)
  }

  storage_os_disk {
    name              = "sql-${random_string.sql-vm-name.result}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "sql-${random_string.sql-vm-name.result}-vm"
    admin_username = var.sql_admin_username
    admin_password = random_password.sql-vm-password.result
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }

  # os_profile_secrets {
  #   source_vault_id = var.key_vault_id
  # }

  # boot_diagnostics {
  #   enabled     = true
  #   storage_uri = "https://${var.diagnostics_storage_account_name}.blob.core.windows.net"
  # }

  tags = {
    environment = var.environment
  }
}
