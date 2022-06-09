data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_vpc" "default" {
  default = true
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

resource "aws_key_pair" "cloud-ssh" {
  key_name   = "cloud-ssh"
  public_key = file("~/.ssh/${local.ssh_key_pub}")
}

resource "aws_security_group" "ssh" {
  name        = "SSH-SG"
  description = "Security group for SSH"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ingress_rule_ssh" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = local.allowed_cidr
  security_group_id = aws_security_group.ssh.id
}

resource "aws_security_group_rule" "egress_rule" {
  type        = "egress"
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ssh.id
}

resource "aws_instance" "jump_host" {
  # If solution relies on ExpressVPN, jump host must be deployed.
  count                   = local.expressvpn ? 1 : 0

  ami                     = data.aws_ami.ubuntu.id
  key_name                = aws_key_pair.cloud-ssh.key_name
  instance_type           = local.jumphost_instance_type
  vpc_security_group_ids  = [aws_security_group.ssh.id]

  # Upload ssh key to jumphost
  provisioner "file" {
    source      = "~/.ssh/${local.ssh_key_priv}"
    destination = "${local.ssh_key_priv}"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip
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
      host        = self.public_ip
    }
  }

  # Add jumphost's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"JumpHost: \"${self.public_ip} > ../../files/${local.cloud_name}/servers.txt"
  }

  tags = {
    Name = "JumpHost"
  }
}

resource "aws_instance" "server" {
  count                   = local.servers_count

  ami                     = data.aws_ami.ubuntu.id
  instance_type           = local.server_instance_type
  key_name                = aws_key_pair.cloud-ssh.key_name
  vpc_security_group_ids  = [aws_security_group.ssh.id]
  user_data               = file("../../files/userdata.sh")

  # Upload cloudos_server.sh script to the server
  provisioner "file" {
    source      = "../../files/cloudos_server.sh"
    destination = "cloudos_server.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = self.public_ip
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
      host        = self.public_ip
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
      host        = self.public_ip
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
      host        = self.public_ip
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
      host        = self.public_ip
    }
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }

  # Add server's private IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Private IP: \"${self.private_ip} >> ../../files/${local.cloud_name}/servers.txt"
  }

  # Add server's public IP to the local list
  provisioner "local-exec" {
    command = "echo \"Server-${count.index + 1} Public IP: \"${self.public_ip} >> ../../files/${local.cloud_name}/servers.txt"
  }

  tags = {
    Name = "Server-${count.index + 1}"
  }
}

resource "null_resource" "apply_autostart" {
  count         = local.mhddos_proxy_autostart ? length(aws_instance.server) : 0

  provisioner "remote-exec" {
    inline = [
      "sudo /home/ubuntu/cloudos_server.sh autostart=true"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/${local.ssh_key_priv}")
      host        = aws_instance.server[count.index].public_ip
    }
  }
}

resource "null_resource" "generate_files" {
  count = local.expressvpn ? length(aws_instance.server) : 0

  # Generate handy commands facilitating login to servers
  provisioner "local-exec" {
    command = "echo \"ssh -t -i ~/.ssh/${local.ssh_key_priv} ubuntu@${aws_instance.jump_host[0].public_ip} ssh ubuntu@${aws_instance.server[count.index].private_ip} -i /home/ubuntu/${local.ssh_key_priv}\" >> ../../files/${local.cloud_name}/commands.txt"
  }
}
