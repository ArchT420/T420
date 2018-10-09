#!/bin/bash
#
#
# 's/^#en_US/en_US/'
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash

# Set the mirrorlist from https://www.archlinux.org/mirrorlist/
# and rank 5 best mirrors, while commenting out the rest.
MIRRORLIST_URL="https://www.archlinux.org/mirrorlist/?country=FI&country=LV&country=NO&country=PL&country=SE&protocol=https&use_mirror_status=on"

pacman -Sy --noconfirm pacman-contrib

echo "Updating & Ranking the mirror list in: /etc/pacman.d/mirrorlist"
curl -s "$MIRRORLIST_URL" | \
    sed -e 's/^#Server/Server/' -e '/^#/d' | \
    rankmirrors -n 5 - > /etc/pacman.d/mirrorlist

## Get infomation from user ##
hostname=$(dialog --stdout --inputbox "/mnt/etc/hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Add default user" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(dialog --stdout --passwordbox "Set default user password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Retype password" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

rootpassword=$(dialog --stdout --passwordbox "Set ROOT password" 0 0) || exit 1
clear
: ${rootpassword:?"password cannot be empty"}
rootpassword2=$(dialog --stdout --passwordbox "Retype ROOT password" 0 0) || exit 1
clear
[[ "$rootpassword" == "$rootpassword2" ]] || ( echo "Passwords did not match"; exit 1; )

## Select the installation disk, example: /dev/sda or /dev/sdb etc.
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installtion disk" 0 0 0 ${devicelist}) || exit 1

## Set up logging ##
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

## Create the partitions
sgdisk -n 1:0:+200M -t 0:EF00 -c 0:"boot" ${device} # partition 1 (UEFI BOOT), default start block, 200MB, type EF00 (EFI), label: "boot"
sgdisk -n 2:0:+4G -t 0:8200 -c 0:"swap" ${device} # partition 2 (SWAP), default start block, 4GB, type 8200 (swap), label: "swap"
sgdisk -n 3:0:+1G -c 0:"root" ${device} # partition 3 (ROOT), default start block, 80GB, label: "swap"
sgdisk -n 4:0:0 -c 0:"home" ${device} # partition 4, (Arch Linux), default start, remaining space, label: "swap"

## Create the filesystems
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"	# /boot partition created by sgdisk
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"	# /swap partition created by sgdisk
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"	#   /	partition created by sgdisk
part_home="$(ls ${device}* | grep -E "^${device}p?4$")"	# /home partition created by sgdisk

mkfs.fat -F32 "${part_boot}"
mkswap "${part_swap}"
swapon "${part_swap}"
mkfs.ext4 "${part_root}"
mkfs.ext4 "${part_home}"

## Mount the partitions
mount "${part_root}" /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "${part_boot}" /mnt/boot
mount "${part_home}" /mnt/home

## Install the base Arch system
pacstrap -i --noconfirm /mnt base base-devel
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
timedatectl set-ntp true

## Enable DHCPCD (eth0 ethernet service)
systemctl enable dhcpcd@enp0s25.service

## Enable multilib in /etc/pacman.conf- this allows the installation of 32bit applications
if [ "$(uname -m)" = "x86_64" ]
then
        cp /etc/pacman.conf /etc/pacman.conf.bkp
        sed '/^#\[multilib\]/{s/^#//;n;s/^#//;n;s/^#//}' /etc/pacman.conf > /tmp/pacman
        mv /tmp/pacman /etc/pacman.conf
fi

## Add wireless
pacman -S dialog wpa_supplicant --noconfirm

## Trim service for SSD drives
systemctl enable fstrim.timer

# Disable PC speaker beep
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

useradd -m -g users -G wheel,storage,power -s /bin/bash "$user"

echo "$user:$password" | chpasswd --root /mnt
echo "root:$rootpassword" | chpasswd --root /mnt
EOF

## Add AUR repository in /etc/pacman.conf
cat <<EOF >> /etc/pacman.conf
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
EOF

pacman -Sy
