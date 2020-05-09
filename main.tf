/*
* Demonstrate use of provisioner 'remote-exec' to execute a command
* on a new VM instance.
*/

/*
* NOTE: It is very poor practice to hardcode sensitive information
* such as user name, password, etc. Hardcoded values are used here
* only to simplify the tutorial.
*/

variable "resource_prefix" {
  default = "my"
}

# You'll usually want to set this to a region near you.
variable "location" {
  default = "westus"
}

# Configure the provider.
provider "azurerm" {
  version = "~>1.31"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_prefix}TFResourceGroup"
  location = var.location
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}TFVnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.resource_prefix}TFSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.1.0/24"
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                         = "${var.resource_prefix}TFPublicIP"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method = "Static"
  }

data "azurerm_public_ip" "publicip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.resource_prefix}TFNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "${var.resource_prefix}NIC"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  network_security_group_id = azurerm_network_security_group.nsg.id

  ip_configuration {
    name                          = "${var.resource_prefix}NICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.resource_prefix}TFVM"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "${var.resource_prefix}OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.resource_prefix}TFVM"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
        path     = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSt8lzgehOfl+V+mW1DxnJTkB/DvTdtVY/xAwuxzOFdTjzS/kSEOJ+psfIwUbaqGL/+ITWp41hr83FMd9pCbL1vgl68nR5y8Sly6If2NeWvMxW31BhJnLaM5Ixv7E6T6z/1LnIzIeve0OBySwT4DNaeh2/ArLoLd2KYO3fKbvAn4wO0U48m6dFccuFULIVA3a4cL87FxjFr4mn/QUp77dM4ddkHft+z1dItFz5DyIjHvZgFHYgAMFIMBSwyBHMgNbByK9T8e12YY71sz7KnBh6RgWs9RLqnSMEemzP4rbtl+NMV1TRRdMsDVNekKMpSw+jE9Gdd/jnpHI+4Yq+gGfKue5GbIY1N+XNn07W0eMBQXBiDIjI9jB/8DYDt7kmy559dpea3OgJe15hdG7KgaafJ9ezR/FBgjC72GVzyuafQJNPnTP6a4PXBQmCFyAlqXw2qnnqbX7ywj6ndPkQYMFReVTeov59v6CS++LZGJxqgalKM8M22+IhokIOlf9O+zV9Vx4IISadDMtpG9zs36+apgdKqYyJDWqzV/oy8ljzXa4mU17DOUFEav+LRE3p4NIAEXsTma9L6mAmGZVo8zZwAv8hLtIzR0ts12AVonKQ9BNO5RXowShlC7nZRwn2v3XpqdtenEAkblcEaby9KxDrUuyQE4f6pNC+EayyPJSnqw== larryebaum@hashicorp.com"
        }
  }

  # provisioner "file" {
  #   connection {
  #     host     = azurerm_public_ip.publicip.ip_address
  #     type     = "ssh"
  #     user     = var.admin_username
  #     password = var.admin_password
  #   }
  #
  #   source      = "newfile.txt"
  #   destination = "newfile.txt"
  # }

  provisioner "remote-exec" {
    connection {
      host     = azurerm_public_ip.publicip.ip_address
      type     = "ssh"
      user     = var.admin_username
      password = var.admin_password
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get update",
    ]
  }

  provisioner "local-exec" {
    command = "ansible-playbook  -i ./ansible/http_inventory.yaml ./ansible/httpd.yml"
  }

}
