data "azurerm_resource_group" "main" {
  name = "main"
}

resource "null_resource" "clean_up_files" {
  # Clean up files
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/servers.txt ]; then rm ../../files/${local.cloud_name}/servers.txt; fi"
  }
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/commands.txt ]; then rm ../../files/${local.cloud_name}/commands.txt; fi"
  }
}

# Azure ssh key
resource "azurerm_ssh_public_key" "cloud-ssh" {
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  name                = "cloud-ssh"
  public_key          = file("~/.ssh/${local.ssh_key_pub}")
}

# Azure resource group
resource "azurerm_virtual_network" "main" {
  resource_group_name = data.azurerm_resource_group.main.name
  name          = "main-network"
  location      = data.azurerm_resource_group.main.location
  address_space = ["192.168.0.0/16"]
}

# Azure subnet
resource "azurerm_subnet" "internal" {
  resource_group_name   = data.azurerm_resource_group.main.name
  name                  = "main-internal-subnet"
  virtual_network_name  = azurerm_virtual_network.main.name
  address_prefixes      = ["192.168.1.0/24"]
}

# Azure public IP for jumphost
resource "azurerm_public_ip" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count                   = local.expressvpn ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
  name                = "jump-host-ip"
}

# Azure network interface for jumphost
resource "azurerm_network_interface" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count                   = local.expressvpn ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  name                = "jumphost-nic"
  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump_host[0].id
  }
}

# Azure public IP for servers
resource "azurerm_public_ip" "server" {
  count               = local.servers_count

  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
  name                = "vpn-ip-${count.index}"
}

# Azure network interface for server
resource "azurerm_network_interface" "server" {
  count               = local.servers_count

  resource_group_name = data.azurerm_resource_group.main.name
  name                = "server-nic-${count.index}"

  location            = data.azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${element( azurerm_public_ip.server.*.id, count.index)}"
  }
}

resource "azurerm_linux_virtual_machine" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count                   = local.expressvpn ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  name            = "JumpHost"
  location        = data.azurerm_resource_group.main.location
  admin_username  = "ubuntu"
  size            = local.jumphost_instance_type

  network_interface_ids = [
    azurerm_network_interface.jump_host[0].id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = azurerm_ssh_public_key.cloud-ssh.public_key
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
#    offer     = "0001-com-ubuntu-server-focal"
#    sku       = "20_04-lts-gen2"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Upload ssh key to jumphost
  provisioner "file" {
    source      = "~/.ssh/${local.ssh_key_priv}"
    destination = "${local.ssh_key_priv}"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  # Set correct ssh key permission
  provisioner "remote-exec" {
    inline = [
      "chmod 600 ${local.ssh_key_priv}"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  # Add jumphost's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"JumpHost: \"${self.public_ip_address} > ../../files/${local.cloud_name}/servers.txt"
  }
}

resource "azurerm_linux_virtual_machine" "server" {
  count           = local.servers_count

  resource_group_name = data.azurerm_resource_group.main.name
  name            = "Server-${count.index}"

  location        = data.azurerm_resource_group.main.location
  admin_username  = "ubuntu"
  size            = local.server_instance_type
  custom_data     = base64encode(file("../../files/userdata.sh"))

  network_interface_ids = ["${element( azurerm_network_interface.server.*.id, count.index)}"]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = azurerm_ssh_public_key.cloud-ssh.public_key
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Upload cloudos_server.sh script to the server
  provisioner "file" {
    source      = "../../files/cloudos_server.sh"
    destination = "cloudos_server.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  # Upload expressvpn.sh script to the server
  provisioner "file" {
    source      = "../../files/expressvpn.sh"
    destination = "expressvpn.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  # Upload expressvpn_activation_code to the server
  provisioner "file" {
    source      = "../../files/expressvpn_activation_code"
    destination = "expressvpn_activation_code"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  # Upload targets.txt file to the server
  provisioner "file" {
    source      = "../../files/targets.txt"
    destination = "targets.txt"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/cloudos_server.sh; chmod +x ~/expressvpn.sh"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip_address
    }
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }

  # Add server's private IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Private IP: \"${self.private_ip_address} >> ../../files/${local.cloud_name}/servers.txt"
  }

  # Add server's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Public IP: \"${self.public_ip_address} >> ../../files/${local.cloud_name}/servers.txt"
  }
}

resource "null_resource" "apply_autostart" {
  count         = local.mhddos_proxy_autostart ? length(azurerm_linux_virtual_machine.server) : 0

  provisioner "remote-exec" {
    inline = [
      "sudo /home/ubuntu/cloudos_server.sh autostart=true"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = azurerm_linux_virtual_machine.server[count.index].public_ip_address
    }
  }
}

resource "null_resource" "generate_files" {
  count = local.expressvpn ? length(azurerm_linux_virtual_machine.server) : 0

  # Generate handy commands facilitating login to servers
  provisioner "local-exec" {
    command = "echo \"ssh -t -i ~/.ssh/${local.ssh_key_priv} ubuntu@${azurerm_linux_virtual_machine.jump_host[0].public_ip_address} ssh ubuntu@${azurerm_linux_virtual_machine.server[count.index].private_ip_address} -i /home/ubuntu/${local.ssh_key_priv}\" >> ../../files/${local.cloud_name}/commands.txt"
  }
}
