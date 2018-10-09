#!/bin/bash
# Installscript v2
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash

########## Variables ##########
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=FI&country=LV&country=NO&country=PL&country=SE&protocol=https&use_mirror_status=on"

## Installer colors
RED='\033[0;31m'
NC='\033[0m' # No Color
###############################

function rank_mirrors(){
echo Helloo
printf "${RED}Installing pacman-contrib${NC}\n"
pacman -Sy --noconfirm pacman-contrib
echo "Updating & Ranking the mirror list in: /etc/pacman.d/mirrorlist"
curl -s "$MIRRORLIST_URL" | \
    sed -e 's/^#Server/Server/' -e '/^#/d' | \
    rankmirrors -n 5 - > /etc/pacman.d/mirrorlist
}

rank_mirrors
echo ranking done
