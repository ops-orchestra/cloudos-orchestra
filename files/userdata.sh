#!/bin/bash

echo "Install utilities"
sudo apt-get update -y
sudo apt install iftop expect -y

echo "Install docker"
sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo echo  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sudo systemctl status docker

echo "Install ExpressVPN"
sudo cd ~/
sudo wget https://www.expressvpn.works/clients/linux/expressvpn_3.19.0.13-1_amd64.deb
sudo dpkg -i ./expressvpn_3.19.0.13-1_amd64.deb
