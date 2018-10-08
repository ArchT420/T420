#!/bin/bash
#
#
#
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash





# Set the mirrorlist from https://www.archlinux.org/mirrorlist/
# and rank 5 best mirrors, while commenting out the rest.

#MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=FI&country=LV&country=NO&country=PL&country=SE&protocol=https&use_mirror_status=on"

#pacman -Sy --noconfirm pacman-contrib

#echo "Updating & Ranking the mirror list in: /etc/pacman.d/mirrorlist"
#curl -s "$MIRRORLIST_URL" | \
#    sed -e 's/^#Server/Server/' -e '/^#/d' | \
#    rankmirrors -n 5 - > /etc/pacman.d/mirrorlist


### Get infomation from user ###
#hostname=$(dialog --stdout --inputbox "/mnt/etc/hostname" 0 0) || exit 1
#clear
#: ${hostname:?"hostname cannot be empty"}

#user=$(dialog --stdout --inputbox "Add default user" 0 0) || exit 1
#clear
#: ${user:?"user cannot be empty"}

#password=$(dialog --stdout --passwordbox "Set default user password" 0 0) || exit 1
#clear
#: ${password:?"password cannot be empty"}
#password2=$(dialog --stdout --passwordbox "Retype default user password" 0 0) || exit 1
#clear
#[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

gdisk /dev/sda
x
z
y
y
