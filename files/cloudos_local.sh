#!/bin/bash

clear

# Colors
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

main () {
    echo -en "
${YELLOW}
  _____ _                 _            ____           _               _
 / ____| |               | |          / __ \         | |             | |
| |    | | ___  _   _  __| | ___  ___| |  | |_ __ ___| |__   ___  ___| |_ _ __ __ _
| |    | |/ _ \| | | |/ _  |/ _ \/ __| |  | | __/ __ |  _ \ / _ \/ __| __|  __/ _  |
| |____| | (_) | |_| | (_| | (_) \__ \ |__| | | | (__| | | |  __/\__ \ |_| | | (_| |
 \_____|_|\___/ \__,_|\__,_|\___/|___/\____/|_|  \___|_| |_|\___||___/\__|_|  \__,_|
${RESET}

${YELLOW}1.${RESET} Configure local environment
${YELLOW}2.${RESET} Deploy and configure cloud servers
${YELLOW}3.${RESET} Destroy cloud servers
${YELLOW}4.${RESET} Exit
${YELLOW}Choose an option: "${RESET}
    read -r option
    case $option in
    1)
        configure_local_env
        ;;
    2)
        deploy_cloud
        ;;
    3)
        destroy_cloud
        ;;
    4)
        exit 0
        ;;
    *)
        echo -e "${RED}ERROR: Unknown parameter. ${RESET}"
        exit 1
        ;;
    esac
}

configure_local_env () {
  echo -e "${YELLOW}\nCreating ssh key to login to cloud servers ${RESET}"
  if [ ! -d ~/.ssh ]; then mkdir ~/.ssh ;fi
  ssh-keygen -f ~/.ssh/cloud-ssh -P ""

  echo -e "${YELLOW}Install terraform ${RESET}"

  if [ $(which apt-get &> /dev/null; echo $?) -eq 0 ]; then
    tf_url='https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_linux_amd64.zip'
    sudo apt install unzip wget -y
    wget $tf_url
    unzip ${tf_url##*/} && rm ${tf_url##*/} 
    chmod +x terraform
    sudo mv terraform $(dirname $(which apt-get))
  elif [ $(which brew &> /dev/null; echo $?) -eq 0 ]; then
    tf_url='https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_darwin_amd64.zip'
    brew install unzip wget
    wget $tf_url
    unzip ${tf_url##*/} && rm ${tf_url##*/} 
    chmod +x terraform
    mv terraform $(dirname $(which brew))
  fi
  
  terraform -v || exit 1

  echo -e "${GREEN}The operation succeeded!${RESET}"
}

deploy_cloud () {
    echo -en "
${YELLOW}Deploy and configure cloud servers: ${RESET}
${YELLOW}1.${RESET} AWS (Amazon Web Services)
${YELLOW}2.${RESET} Azure (Microsoft)
${YELLOW}3.${RESET} GCP (Google Cloud)
${YELLOW}4.${RESET} DO (Digital Ocean)
${YELLOW}5.${RESET} Orcale (Orcale cloud)
${YELLOW}6.${RESET} Exit
${YELLOW}Choose an option:${RESET} "
    read -r option
    case $option in
    1)
        deploy_info
        deploy_info_output
        deploy_aws
        ;;
    2)
        deploy_info
        deploy_info_output
        deploy_azure
        ;;
    3)
        deploy_info
        deploy_info_output
        deploy_gcp
        ;;
    4)
        deploy_info
        deploy_info_output
        deploy_do
        ;;
    5)
        deploy_info
        deploy_info_output
        deploy_oracle
        ;;
    6)
        exit 0
        ;;
    *)
        echo -e "${RED}ERROR: Unknown parameter. ${RESET}"
        exit 1
        ;;
    esac
}

deploy_info () {
  echo -en "\nEnter the number of servers to create [Minimum: 1, Maximum: 5]: "
  read -r servers_count
  case $servers_count in
    1|2|3|4)
      echo -e "The value accepted."
    ;;
    *)
      echo -e "${RED}ERROR: Unknown parameter. ${RESET}\n"
      exit 1
      ;;
  esac

  echo -en "\nAutostart mhddos_proxy (recommended: no) [yes|no]: "
  read info_mhddos_proxy_autostart
  info_mhddos_proxy_autostart=`echo $info_mhddos_proxy_autostart | tr '[:upper:]' '[:lower:]'`
  case $info_mhddos_proxy_autostart in
    yes|no)
      echo -e "The value accepted."
    ;;
    *)
      echo -e "${RED}ERROR: Unknown parameter. ${RESET}\n"
      exit 1
      ;;
  esac
  if [ $info_mhddos_proxy_autostart == "yes" ]; then
    mhddos_proxy_autostart="true"
  else
    mhddos_proxy_autostart="false"
  fi

  if [ $mhddos_proxy_autostart == "true" ]; then
    echo -e "\nExpressVPN will not be used along with mhddos_proxy autostart."
  else
    echo -en "\nWill be ExpressVPN used [yes|no]: "
    read info_expressvpn
    info_expressvpn=`echo $info_expressvpn | tr '[:upper:]' '[:lower:]'`

    case $info_expressvpn in
    yes|no)
      echo -e "The value accepted."
    ;;
    *)
      echo -e "${RED}ERROR: Unknown parameter. ${RESET}\n"
      exit 1
      ;;
    esac
    if [ $info_expressvpn == "yes" ]; then
      expressvpn="true"
      echo -en "\nEnter ExpressVPN Activation Code to be used by current Cloud provider: "
      read -s expressvpn_code
      #sed -i "s/EXPRESSVPN_CODE.*\".*\"/EXPRESSVPN_CODE=\"$expressvpn_code\"/" expressvpn_activation_code || exit
      echo $expressvpn_code > expressvpn_activation_code
    else
      expressvpn="false"
    fi
  fi

  echo -en "\n\nUpdate targets.txt list [yes|no]: "
  read info_update_targets
  info_update_targets=`echo $info_update_targets | tr '[:upper:]' '[:lower:]'`

  case $info_update_targets in
    yes)
      echo -e "The value accepted."
      echo -e "\nPaste targets here in the correct format:"
      nano targets.txt
      ;;
    no)
      echo -e "The value accepted."
      ;;
    *)
      echo -e "${RED}ERROR: Unknown parameter. ${RESET}\n"
      exit 1
      ;;
  esac
}

deploy_info_output () {
  echo -e "${YELLOW}\nDeploy and configure AWS (Amazon Web Services): ${RESET}"
  echo -e "${YELLOW}Number of servers:${RESET}        $servers_count"
  echo -e "${YELLOW}mhddos_proxy autostart:${RESET}   $mhddos_proxy_autostart"
  echo -e "${YELLOW}Use ExpressVPN:${RESET}           $expressvpn"
  echo -e "${YELLOW}Targets:${RESET}
`cat targets.txt`"

}

deploy_aws () {
  cd ../terraform/aws
  echo -e "${YELLOW}\nUpdating terraform 'locals.tf'${RESET}: "

  sed -i "s/servers_count .*\".*\"/servers_count           = \"$servers_count\"/" locals.tf
  if [ -z "$mhddos_proxy_autostart" ]; then sed -i "s/mhddos_proxy_autostart .*\".*\"/mhddos_proxy_autostart      = \"$mhddos_proxy_autostart\"/" locals.tf  ; fi || exit
  sed -i "s/expressvpn .*\".*\"/expressvpn                 = \"$expressvpn\"/" locals.tf || exit

  echo -e "${YELLOW}\nRunning 'terraform init':${RESET}"
  terraform init
  echo -e "${YELLOW}\nRunning 'terraform apply':${RESET}"
  terraform apply -auto-approve
}

deploy_azure () {
  cd ../terraform/azure
  echo -e "${YELLOW}\nUpdating terraform 'locals.tf'${RESET}: "

  sed -i "s/servers_count .*\".*\"/servers_count           = \"$servers_count\"/" locals.tf
  if [ -z "$mhddos_proxy_autostart" ]; then sed -i "s/mhddos_proxy_autostart .*\".*\"/mhddos_proxy_autostart      = \"$mhddos_proxy_autostart\"/" locals.tf  ; fi || exit
  sed -i "s/expressvpn .*\".*\"/expressvpn                 = \"$expressvpn\"/" locals.tf || exit

  echo -e "${YELLOW}\nRunning 'terraform init':${RESET}"
  terraform init
  echo -e "${YELLOW}\nRunning 'terraform apply':${RESET}"
  terraform apply -auto-approve
}

deploy_gcp () {
  cd ../terraform/gcp
  echo -e "${YELLOW}\nUpdating terraform 'locals.tf'${RESET}: "

  sed -i "s/servers_count .*\".*\"/servers_count           = \"$servers_count\"/" locals.tf
  if [ -z "$mhddos_proxy_autostart" ]; then sed -i "s/mhddos_proxy_autostart .*\".*\"/mhddos_proxy_autostart      = \"$mhddos_proxy_autostart\"/" locals.tf  ; fi || exit
  sed -i "s/expressvpn .*\".*\"/expressvpn                 = \"$expressvpn\"/" locals.tf || exit

  echo -e "${YELLOW}\nRunning 'terraform init':${RESET}"
  terraform init
  echo -e "${YELLOW}\nRunning 'terraform apply':${RESET}"
  terraform apply -auto-approve
}

deploy_do () {
  cd ../terraform/do
  echo -e "${YELLOW}\nUpdating terraform 'locals.tf'${RESET}: "

  sed -i "s/servers_count .*\".*\"/servers_count           = \"$servers_count\"/" locals.tf
  if [ -z "$mhddos_proxy_autostart" ]; then sed -i "s/mhddos_proxy_autostart .*\".*\"/mhddos_proxy_autostart      = \"$mhddos_proxy_autostart\"/" locals.tf  ; fi || exit
  sed -i "s/expressvpn .*\".*\"/expressvpn                 = \"$expressvpn\"/" locals.tf || exit

  echo -e "${YELLOW}\nRunning 'terraform init':${RESET}"
  terraform init
  echo -e "${YELLOW}\nRunning 'terraform apply':${RESET}"
  terraform apply -auto-approve
}

deploy_gcp () {
  cd ../terraform/gcp
  echo -e "${YELLOW}\nUpdating terraform 'locals.tf'${RESET}: "

  sed -i "s/servers_count .*\".*\"/servers_count           = \"$servers_count\"/" locals.tf
  if [ -z "$mhddos_proxy_autostart" ]; then sed -i "s/mhddos_proxy_autostart .*\".*\"/mhddos_proxy_autostart      = \"$mhddos_proxy_autostart\"/" locals.tf  ; fi || exit
  sed -i "s/expressvpn .*\".*\"/expressvpn                 = \"$expressvpn\"/" locals.tf || exit

  echo -e "${YELLOW}\nRunning 'terraform init':${RESET}"
  terraform init
  echo -e "${YELLOW}\nRunning 'terraform apply':${RESET}"
  terraform apply -auto-approve
}

destroy_cloud () {
    echo -en "
${YELLOW}Destroy cloud servers: ${RESET}
${YELLOW}1.${RESET} AWS (Amazon Web Services)
${YELLOW}2.${RESET} Azure (Microsoft)
${YELLOW}3.${RESET} GCP (Google Cloud)
${YELLOW}4.${RESET} DO (Digital Ocean)
${YELLOW}5.${RESET} Oracle (Orcale cloud)
${YELLOW}6.${RESET} Exit
${YELLOW}Choose an option:${RESET} "
    read -r option
    case $option in
    1)
        echo -e "\nDestroying of AWS resources..."
        sleep 5
        cd ../terraform/aws
        terraform destroy -auto-approve
        ;;
    2)
        echo -e "\nDestroying of Azure resources..."
        sleep 5
        cd ../terraform/azure
        terraform destroy -auto-approve
        ;;
    3)
        echo -e "\nDestroying of GCP resources..."
        sleep 5
        cd ../terraform/gcp
        terraform destroy -auto-approve
        ;;
    4)
        echo -e "\nDestroying of DO resources..."
        sleep 5
        cd ../terraform/do
        terraform destroy -auto-approve
        ;;
    5)
        echo -e "\nDestroying of Oracle resources..."
        sleep 5
        cd ../terraform/oracle
        terraform destroy -auto-approve
        ;;
    *)
        echo -e "${RED}ERROR: Unknown parameter.${RESET}"
        exit 1
        ;;
    esac
}

main
