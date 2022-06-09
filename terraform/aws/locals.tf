locals {
  #############################################
  # Cloud variables
  # Available clouds:
  # aws|gcp|azure|do|oracle
  cloud_name              = "aws"
  region                  = "eu-central-1"
  #############################################


  #############################################
  # Servers variables
  # Set the number of servers to spin up
  servers_count           = "1"
  jumphost_instance_type  = "t3.micro"
  server_instance_type    = "t3.micro"
  # Allowed IPs to login via SSH
  allowed_cidr            = ["0.0.0.0/0"]
  # SSH key to login via SSH
  ssh_key_priv            = "cloud-ssh"
  ssh_key_pub             = "cloud-ssh.pub"
  #############################################


  #############################################
  # Set to 'true' to start ddos script automatically right after servers are up and running.
  # With 'false' you supposed to run script interactively directly from the server.
  # Autostart mode is not recommended due to the lack of visibility during its execution.
  mhddos_proxy_autostart     = "false"

  # Application variables
  # Set to 'true' if ExpressVPN should be used. If 'mhddos_proxy_autostart=true', expressvpn will not be working despite the 'true' parameter.
  expressvpn                 = "true"
  #############################################
}

