#!/bin/bash
# This script can be run by executing the following:
# curl -sL https://git.io/fxcQv | bash


## Installer colors
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color
WHITE='\e[1;37m'
CYAN='\e[1;36m'
GREEN='\e[1;32m'
#### UEFI / BIOS detection

start() {
    DIALOG_RESULT=$(dialog --clear --stdout "$@" 2>/dev/null)
}

start --title "Welcome" --msgbox "You have launched the Arch Linux bootstrapper. Follow the instructions on the screen.\n" 6 60

efivar -l >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    UEFI_BIOS_text="UEFI detected."
    UEFI_radio="on"
else
	: ${YOU ARE IN BIOS MODE - this installer requires UEFI}
fi

start --title "UEFI check" --radiolist "${UEFI_BIOS_text}\nPress <Enter> to accept." 10 30 1 1 UEFI "$UEFI_radio"
[[ $DIALOG_RESULT -eq 1 ]] && UEFI=1 || UEFI=0

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
echo -e "${WHITE} ${device}${RED} Has been zapped.${NC}\n"
sleep 3
clear

## Create the partitions
echo -e "${CYAN}Now creating the partitions.${NC}\n"

sgdisk -n 1:0:+200M -t 0:EF00 -c 0:"boot" ${device} # partition 1 (UEFI BOOT), default start block, 200MB, type EF00 (EFI), label: "boot"
sgdisk -n 2:0:+4G -t 0:8200 -c 0:"swap" ${device} # partition 2 (SWAP), default start block, 4GB, type 8200 (swap), label: "swap"
sgdisk -n 3:0:+3G -c 0:"root" ${device} # partition 3 (ROOT), default start block, 80GB, label: "swap"
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
echo -e "${WHITE}Partitions formatted.${NC}\n"

## Mount the partitions
echo -e "${CYAN}Now mounting the partitions.${NC}\n"
mount "${part_root}" /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "${part_boot}" /mnt/boot
mount "${part_home}" /mnt/home
echo -e "${WHITE}Partitions mounted.${NC}\n"

## Install the base Arch system
echo -e "${CYAN}Installing packages ${YELLOW}base base-devel ${CYAN}to: ${WHITE}/mnt${NC}\n"
yes '' | pacstrap -i /mnt base base-devel

echo -e "${CYAN}Generating fstab to: ${WHITE}/mnt/etc/fstab${NC}\n"
genfstab -U -p /mnt >> /mnt/etc/fstab


##### arch-chroot #####
echo -e "${RED}[arch-chroot] ${YELLOW}setting hostname${NC} ${CYAN}"${hostname}"${NC} in: ${WHITE}/etc/hostname${NC}\n"
arch-chroot /mnt << EOF
echo $hostname > /etc/hostname
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}uncommenting ${CYAN}#en_US${NC} ${YELLOW}in:${NC} ${WHITE}/etc/locale.gen${NC}\n"
arch-chroot /mnt << EOF
sed -i '176 s/^#en_US/en_US/' /etc/locale.gen
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}generating locales${NC}\n"
arch-chroot /mnt << EOF
locale-gen
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}setting locales${NC}\n"
arch-chroot /mnt << EOF
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}setting timezones${NC}\n"
arch-chroot /mnt << EOF
ln -s /usr/share/zoneinfo/Europe/Tallinn > /etc/localtime
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}enabling dhcpcd service${NC}\n"
arch-chroot /mnt << EOF
systemctl enable dhcpcd@enp0s25.service
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}installing ${CYAN}dialog wpa_supplicant bash-completion${NC}\n"
arch-chroot /mnt << EOF
pacman -S dialog wpa_supplicant bash-completion --noconfirm
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}enabling SSD trim service${NC}\n"
arch-chroot /mnt << EOF
systemctl enable fstrim.timer
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}blacklisting pcspkr${NC}\n"
arch-chroot /mnt << EOF
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}adding default user${NC} ${CYAN}"${user}"${NC}\n"
arch-chroot /mnt << EOF
useradd -m -g users -G wheel,storage,power -s /bin/bash $user
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}setting default user password${NC}\n"
arch-chroot /mnt << EOF
echo "$user:$password" | chpasswd
EOF

echo -e "${RED}[arch-chroot] ${YELLOW}setting root password${NC}\n"
arch-chroot /mnt << EOF
echo "root:$rootpassword" | chpasswd
EOF

echo -e "${RED}Adding "${user}" to sudoers.${NC}\n"
arch-chroot /mnt << EOF
echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > /mnt/etc/sudoers.d/99_wheel
EOF
echo -e "${RED}[arch-chroot] ${CYAN}"${user}"${NC} ${YELLOW}is now part of the group ${WHITE}%wheel.${NC}\n"

### Install boot loader
echo -e "${RED}[arch-chroot] ${YELLOW}Installing bootloader...${NC}\n"
if [[ $UEFI -eq 1 ]]; then
arch-chroot /mnt /bin/bash <<EOF
bootctl install
EOF
fi
echo -e "${RED}[arch-chroot] ${WHITE}Bootloader installed.${NC}\n"

echo -e "${RED}[arch-chroot] ${YELLOW}Configuring the bootloader in: ${WHITE}/boot/loader/entries/arch.conf${NC}\n"
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw
EOF
echo -e "${RED}[arch-chroot] ${WHITE}Bootloader configured.${NC}\n"

## Enable multilib in /etc/pacman.conf - this allows the installation of 32bit applications
echo -e "${RED}[arch-chroot] ${YELLOW}Enabling [multilib] in: ${WHITE}/etc/pacman.conf${NC}\n"
if [ "$(uname -m)" = "x86_64" ]
then
cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bkp
sed '/^#\[multilib\]/{s/^#//;n;s/^#//;n;s/^#//}' /mnt/etc/pacman.conf > /tmp/pacman
mv /tmp/pacman /mnt/etc/pacman.conf
fi
echo -e "${RED}[arch-chroot] ${WHITE}Multilib enabled.${NC}\n"

## Add AUR repository in the end of /etc/pacman.conf
echo -e "${RED}[arch-chroot] ${YELLOW}Enabling AUR repository in: ${WHITE}/etc/pacman.conf${NC}\n"
echo -e '\n[archlinuxfr]\nSigLevel = Never\nServer = http://repo.archlinux.fr/$arch' >> /mnt/etc/pacman.conf
echo -e "${RED}[arch-chroot] ${WHITE}AUR repository added.${NC}\n"

echo -e "${RED}[arch-chroot] ${YELLOW}Synchronizing...${NC}\n"
arch-chroot /mnt << EOF
pacman -Sy
EOF
echo -e "${RED}[arch-chroot] ${YELLOW}Synced.${NC}\n"
echo -e "${WHITE}[arch-chroot] ${RED}leaving arch-chroot environment.${NC}\n"
echo -e "${CYAN}Unmounting partitions.${NC}\n"
umount -R /mnt
echo -e "${WHITE}Arch Linux installation complete. Ready to {RED}reboot.${NC}\n"
