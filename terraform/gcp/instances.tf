resource "null_resource" "clean_up_files" {
  # Clean up files
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/servers.txt ]; then rm ../../files/${local.cloud_name}/servers.txt; fi"
  }
  provisioner "local-exec" {
    command = "if [ -f ../../files/${local.cloud_name}/commands.txt ]; then rm ../../files/${local.cloud_name}/commands.txt; fi"
  }
}

resource "google_compute_instance" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count        = local.expressvpn ? 1 : 0

  name         = "jump-host"
  machine_type = local.jumphost_instance_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
    }
  }

 # scratch_disk {}

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata = {
    sshKeys = "ubuntu:${file("~/.ssh/${local.ssh_key_pub}")}"
  }

  # Upload ssh key to jumphost
  provisioner "file" {
    source      = "~/.ssh/${local.ssh_key_priv}"
    destination = "${local.ssh_key_priv}"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.network_interface[0].access_config[0].nat_ip
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
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  # Add jumphost's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"JumpHost: \"${self.network_interface[0].access_config[0].nat_ip} > ../../files/${local.cloud_name}/servers.txt"
  }
}

resource "google_compute_instance" "server" {
  count        = local.servers_count

  name         = "server-${count.index}"
  machine_type = local.server_instance_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
    }
  }

 # scratch_disk {}

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata = {
    sshKeys = "ubuntu:${file("~/.ssh/${local.ssh_key_pub}")}"
  }

  metadata_startup_script = file("../../files/userdata.sh")


  # Upload cloudos_server.sh script to the server
  provisioner "file" {
    source      = "../../files/cloudos_server.sh"
    destination = "cloudos_server.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.network_interface[0].access_config[0].nat_ip
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
      host        = self.network_interface[0].access_config[0].nat_ip
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
      host        = self.network_interface[0].access_config[0].nat_ip
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
      host        = self.network_interface[0].access_config[0].nat_ip
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
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }

  # Add server's private IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Private IP: \"${self.network_interface[0].network_ip} >> ../../files/${local.cloud_name}/servers.txt"
  }

  # Add server's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Public IP: \"${self.network_interface[0].access_config[0].nat_ip} >> ../../files/${local.cloud_name}/servers.txt"
  }
}


resource "null_resource" "apply_autostart" {
  count         = local.mhddos_proxy_autostart ? length(google_compute_instance.server) : 0

  provisioner "remote-exec" {
    inline = [
      "sudo /home/ubuntu/cloudos_server.sh autostart=true"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = google_compute_instance.server[count.index].network_interface[0].access_config[0].nat_ip
    }
  }
}

resource "null_resource" "generate_files" {
  count = local.expressvpn ? length(google_compute_instance.server) : 0

  # Generate handy commands facilitating login to servers
  provisioner "local-exec" {
    command = "echo \"ssh -t -i ~/.ssh/${local.ssh_key_priv} ubuntu@${google_compute_instance.jump_host[0].network_interface[0].access_config[0].nat_ip} ssh ubuntu@${google_compute_instance.server[count.index].network_interface[0].network_ip} -i /home/ubuntu/${local.ssh_key_priv}\" >> ../../files/${local.cloud_name}/commands.txt"
  }
}

