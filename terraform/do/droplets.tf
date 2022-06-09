resource "null_resource" "clean_up_files" {
  # Clean up files
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/servers.txt ]; then rm ../../files/${local.cloud_name}/servers.txt; fi"
  }
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/commands.txt ]; then rm ../../files/${local.cloud_name}/commands.txt; fi"
  }
}

resource "digitalocean_ssh_key" "cloud-ssh" {
  name       = "cloud-ssh"
  public_key = file("~/.ssh/${local.ssh_key_pub}")
}

resource "digitalocean_droplet" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count                   = local.expressvpn ? 1 : 0

  name      = "JumpHost"
  region    = local.region
  image     = "ubuntu-20-04-x64"
  size      = local.jumphost_instance_type
  ssh_keys  = [digitalocean_ssh_key.cloud-ssh.fingerprint]

  # Upload ssh key to jumphost
  provisioner "file" {
    source      = "~/.ssh/${local.ssh_key_priv}"
    destination = "${local.ssh_key_priv}"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  # Set correct ssh key permission
  provisioner "remote-exec" {
    inline = [
      "chmod 600 ${local.ssh_key_priv}"
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  # Add jumphost's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"JumpHost: \"${self.ipv4_address} > ../../files/${local.cloud_name}/servers.txt"
  }
}

resource "digitalocean_droplet" "server" {
  count                   = local.servers_count

  name        = "Server-${count.index}"
  image       = "ubuntu-20-04-x64"
  region      = local.region
  size        = local.server_instance_type
  ssh_keys    = [digitalocean_ssh_key.cloud-ssh.fingerprint]
  user_data   = file("../../files/userdata.sh")

  # Upload cloudos_server.sh script to the server
  provisioner "file" {
    source      = "../../files/cloudos_server.sh"
    destination = "cloudos_server.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  # Upload expressvpn.sh script to the server
  provisioner "file" {
    source      = "../../files/expressvpn.sh"
    destination = "expressvpn.sh"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  # Upload expressvpn_activation_code to the server
  provisioner "file" {
    source      = "../../files/expressvpn_activation_code"
    destination = "expressvpn_activation_code"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  # Upload targets.txt file to the server
  provisioner "file" {
    source      = "../../files/targets.txt"
    destination = "targets.txt"

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/cloudos_server.sh; chmod +x ~/expressvpn.sh"
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.ipv4_address
    }
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }

  # Add server's private IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Private IP: \"${self.ipv4_address_private} >> ../../files/${local.cloud_name}/servers.txt"
  }

  # Add server's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Public IP: \"${self.ipv4_address} >> ../../files/${local.cloud_name}/servers.txt"
  }
}

resource "null_resource" "apply_autostart" {
  count         = local.mhddos_proxy_autostart ? length(digitalocean_droplet.server) : 0

  provisioner "remote-exec" {
    inline = [
      "sudo /root/cloudos_server.sh autostart=true"
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = digitalocean_droplet.server[count.index].ipv4_address
    }
  }
}

resource "null_resource" "generate_files" {
  count = local.expressvpn ? length(digitalocean_droplet.server) : 0

  # Generate handy commands facilitating login to servers
  provisioner "local-exec" {
    command = "echo \"ssh -t -i ~/.ssh/${local.ssh_key_priv} root@${digitalocean_droplet.jump_host[0].ipv4_address} ssh root@${digitalocean_droplet.server[count.index].ipv4_address_private} -i /root/${local.ssh_key_priv}\" >> ../../files/${local.cloud_name}/commands.txt"
  }
}

