terraform {
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "= 4.1.0"
        }
    }
}

variable "prefix" {
    description = "Prefix for resource names"
    type        = string
    default     = "lab"
}

resource "azurerm_resource_group" "rg" {
    name     = "${variable.prefix}-resource"
    location = "southeastasia"
}

// create virtual machine
resource "azurerm_virtual_machine" "vm" {
    name                  = "${variable.prefix}-vm"
    resource_group_name   = azurerm_resource_group.rg.name
    location              = azurerm_resource_group.rg.location
    network_interface_ids = [azurerm_network_interface.nic.id]
    vm_size               = "Standard_DS1_v2"

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    storage_os_disk {
        name              = "${variable.prefix}-os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "${variable.prefix}-vm"
        admin_username = "${variable.prefix}-user"
        admin_password = "P@ssw0rd123!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }
}

resource "azurerm_virtual_network" "vnet" {
    name                = "${variable.prefix}-vnet"
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    address_space       = ["10.0.0.0/16"]
}


resource "azurerm_subnet" "subnet-1" {
    name                 = "${variable.prefix}-subnet-1"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.0.1/24"]
}

resource "azurerm_subnet" "subnet-2" {
    name                 = "${variable.prefix}-subnet-2"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_storage_account" "storage_account" {
    source = "" 
    version = "1.0.0"
    name = "${variable.prefix}-storage-account"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    account_tier = "Standard"
    account_replication_type = "LRS"
}