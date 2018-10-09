#!/bin/bash
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash


## Installer colors
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color
WHITE='\e[1;37m'
CYAN='\e[1;36m'

## Get information from user ##
hostname=$(dialog --stdout --inputbox "HOSTNAME" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Default user" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --passwordbox "Default user password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Retype password" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

rootpassword=$(dialog --stdout --passwordbox "root password" 0 0) || exit 1
clear
: ${rootpassword:?"password cannot be empty"}
rootpassword2=$(dialog --stdout --passwordbox "root password" 0 0) || exit 1
clear
[[ "$rootpassword" == "$rootpassword2" ]] || ( echo "Passwords did not match"; exit 1; )

## Set up logging ##
echo -e "${CYAN}Output & Error logging has now been enabled.:${WHITE} ~/.stdout.log stderr.log${NC}\n"
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")
sleep 3

# Rank 5 best mirrors from https://www.archlinux.org/mirrorlist/ and comment out the rest.
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=FI&country=LV&country=NO&country=PL&country=SE&protocol=https&use_mirror_status=on"

echo -e "${YELLOW}Installing pacman-contrib (required for rankmirrors).${NC}\n"
pacman -Sy --noconfirm pacman-contrib
echo -e "${YELLOW}Updating & Ranking the mirror list in:${WHITE} /etc/pacman.d/mirrorlist${NC}\n"

curl -s "$MIRRORLIST_URL" | \
    sed -e 's/^#Server/Server/' -e '/^#/d' | \
    rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

## Select the installation disk, example: /dev/sda or /dev/sdb etc.
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installtion disk" 0 0 0 ${devicelist}) || exit 1
clear
echo -e "${YELLOW}The selected disk is:${WHITE} ${device}${NC}\n"
echo -e "${RED}Now destroying any partition tables on the selected disk.${NC}\n"
sleep 5
sgdisk -Z ${device}
echo -e "${WHITE} ${device}${RED}Has been zapped.${NC}\n"
sleep 3
clear

## Create the partitions
echo -e "${CYAN}Now creating the partitions.${NC}\n"

sgdisk -n 1:0:+200M -t 0:EF00 -c 0:"boot" ${device} # partition 1 (UEFI BOOT), default start block, 200MB, type EF00 (EFI), label: "boot"
sgdisk -n 2:0:+4G -t 0:8200 -c 0:"swap" ${device} # partition 2 (SWAP), default start block, 4GB, type 8200 (swap), label: "swap"
sgdisk -n 3:0:+1G -c 0:"root" ${device} # partition 3 (ROOT), default start block, 80GB, label: "swap"
sgdisk -n 4:0:0 -c 0:"home" ${device} # partition 4, (Arch Linux), default start, remaining space, label: "swap"

## Create the filesystems
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"	# /boot partition1 created by sgdisk
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"	# /swap partition2 created by sgdisk
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"	#   /	partition3 created by sgdisk
part_home="$(ls ${device}* | grep -E "^${device}p?4$")"	# /home partition4 created by sgdisk

echo -e "${CYAN}Now formatting the partitions.${NC}\n"
mkfs.fat -F32 "${part_boot}"
mkswap "${part_swap}"
swapon "${part_swap}"
mkfs.ext4 "${part_root}"
mkfs.ext4 "${part_home}"

## Mount the partitions
echo -e "${CYAN}Now mounting the partitions.${NC}\n"
mount "${part_root}" /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "${part_boot}" /mnt/boot
mount "${part_home}" /mnt/home

## Install the base Arch system
#pacstrap -i /mnt base base-devel --noconfirm
genfstab -U -p /mnt >> /mnt/etc/fstab

##### arch-chroot #####
arch-chroot /mnt << EOF

## Set hostname
echo "${hostname}" > /mnt/etc/hostname

## Set locale -- uncomment #en_US.UTF-8 UTF-8" on line 176, inside /etc/locale.gen
sed -i '176 s/^#en_US/en_US/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
export LANG=en_US.UTF-8

## Set Time & Timezone
ln -s /usr/share/zoneinfo/Europe/Tallinn > /etc/localtime

## Enable DHCPCD (eth0 ethernet service)
systemctl enable dhcpcd@enp0s25.service

## Add wireless
pacman -S dialog wpa_supplicant --noconfirm

## Trim service for SSD drives
systemctl enable fstrim.timer

# Disable PC speaker beep
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

EOF

## Enable multilib in /etc/pacman.conf - this allows the installation of 32bit applications
if [ "$(uname -m)" = "x86_64" ]
then
		cp /etc/pacman.conf /etc/pacman.conf.bkp
		sed '/^#\[multilib\]/{s/^#//;n;s/^#//;n;s/^#//}' /etc/pacman.conf > /tmp/pacman
		mv /tmp/pacman /etc/pacman.conf

		useradd -m -g users -G wheel,storage,power -s /bin/bash "$user"
		echo "root:$rootpassword" | chpasswd
		echo "$user:$password" | chpasswd

fi

## Add AUR repository in the end of /etc/pacman.conf
cat <<EOF >> /etc/pacman.conf

[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
EOF

pacman -Sy
