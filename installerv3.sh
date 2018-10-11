#!/bin/bash
## curl -sL https://git.io/fxWcp | bash
### Manual Setup Inside This Script ###
### Set the desired partition sizes ###

logger(){
	echo -e "${CYAN}Output & Error logging has now been enabled:${WHITE} ~/stdout.log ~/stderr.log${NC}\n"
	exec 1> >(tee "stdout.log")
	exec 2> >(tee "stderr.log")
	sleep 5
}

## Error types

err_hostname(){
	dialog --colors --title "\Zr\Z7Attention\ZR\Z0" --msgbox 'You must enter a hostname.' 5 30
}

err_username(){
	dialog --colors --title "\Zr\Z7Attention\ZR\Z0" --msgbox 'You must enter a username.' 5 30
}

err_password_mismatch(){
	dialog --colors --title "\Zr\Z7Attention\ZR\Z0" --msgbox 'Passwords did not match.' 5 30
}

err_password(){
	dialog --colors --title "\Zr\Z7Attention\ZR\Z0" --msgbox 'You must enter a password.' 5 30
}

err_rootpassword(){
	dialog --colors --title "\Zr\Z7Attention\ZR\Z0" --msgbox 'You must enter a root password.' 5 30
}

## User input - names and passwords

input_hostname(){
	hostname=$(dialog --stdout --inputbox "HOSTNAME" 0 0) || exit 1
	clear
		# Check if string is empty using -z. For more 'help test'    
	if [[ -z "$hostname" ]]; then
			err_hostname
			input_hostname
	fi
}

input_username(){
	username=$(dialog --stdout --inputbox "USER NAME" 0 0) || exit 1
	clear
		# Check if string is empty using -z. For more 'help test'    
	if [[ -z "$username" ]]; then
			err_username
			input_username
	fi
}

input_password(){
	password=$(dialog --insecure --stdout --passwordbox "USER PASSWORD" 0 0) || exit 1
	clear
		# Check if string is empty using -z. For more 'help test'    
	if [[ -z "$password" ]]; then
			err_password
			input_password
	fi
	password2=$(dialog --insecure --stdout --passwordbox "RETYPE PASSWORD" 0 0) || exit 1
	clear
	if [[ -z "$password2" ]]; then
			err_password
			input_password
	fi	
	[[ "$password" == "$password2" ]] || ( err_password_mismatch; input_password; )
}

input_rootpassword(){
	rootpassword=$(dialog --insecure --colors --stdout --passwordbox "\Zn\Z1ROOT PASSWORD" 0 0) || exit 1
	clear
		# Check if string is empty using -z. For more 'help test'    
	if [[ -z "$rootpassword" ]]; then
			err_password
			input_rootpassword
	fi
	rootpassword2=$(dialog --insecure --colors --stdout --passwordbox "\Zn\Z1RETYPE PASSWORD" 0 0) || exit 1
	clear
	if [[ -z "$rootpassword2" ]]; then
			err_password
			input_rootpassword
	fi	
	[[ "$rootpassword" == "$rootpassword2" ]] || ( err_password_mismatch; input_rootpassword; )	
}

## User input - system configuration

input_boot_firmware(){
	efivar -l >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
    DETECTED="This device is in UEFI firmware mode."
    OPTION="UEFI"
    UEFI_radio="on"
    BIOS_radio="off"
else
    DETECTED="This device is in BIOS firmware mode."
    OPTION="BIOS"
    UEFI_radio="off"
    BIOS_radio="on"
	fi
	
	dialog --title "FIRMWARE" --radiolist "${DETECTED}\n       You should select ${OPTION}." 10 41 2 1 UEFI "$UEFI_radio" 2 BIOS "$BIOS_radio"
	[[ $DIALOG_RESULT -eq 1 ]] && UEFI=1 || UEFI=0
}

input_selectdisks(){
	devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
	device=$(dialog --stdout --menu "Select installtion disk" 0 0 0 ${devicelist}) || exit 1
	clear
}

input_ethernet(){
	enp=$(ls /sys/class/net | grep -E enp)
	enpinterface=$(dialog --stdout --no-items --menu "Select ethernet interface" 0 0 0 ${enp}) || exit 1
}

input_wireless(){
	wlp=$(ls /sys/class/net | grep -E wlp)
	wlpinterface=$(dialog --stdout --no-items --menu "Select wireless interface" 0 0 0 ${wlp}) || exit 1
}

## Mechanical

destroy_selected_disk(){
	sgdisk -Z ${device}
}

create_partitions(){
	sgdisk -n 1:0:+200M -t 0:EF00 -c 0:"boot" ${device} # partition 1 (UEFI BOOT), default start block, 200MB, type EF00 (EFI), label: "boot"
	sgdisk -n 2:0:+1G -t 0:8200 -c 0:"swap" ${device} # partition 2 (SWAP), default start block, 4GB, type 8200 (swap), label: "swap"
	sgdisk -n 3:0:+3G -c 0:"root" ${device} # partition 3 (ROOT), default start block, 80GB, label: "swap"
	sgdisk -n 4:0:0 -c 0:"home" ${device} # partition 4, (Arch Linux), default start, remaining space, label: "swap"
}

create_filesystems(){
	part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"	# /boot partition1 created by sgdisk
	part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"	# /swap partition2 created by sgdisk
	part_root="$(ls ${device}* | grep -E "^${device}p?3$")"	#   /	partition3 created by sgdisk
	part_home="$(ls ${device}* | grep -E "^${device}p?4$")"	# /home partition4 created by sgdisk

	mkfs.fat -F32 "${part_boot}"
	mkswap "${part_swap}"
	swapon "${part_swap}"
	mkfs.ext4 "${part_root}"
	mkfs.ext4 "${part_home}"
}

mount_partitions(){
	mount "${part_root}" /mnt
	mkdir /mnt/boot
	mkdir /mnt/home
	mount "${part_boot}" /mnt/boot
	mount "${part_home}" /mnt/home
}

install_bootloader(){
if [[ $UEFI -eq 1 ]]; then
arch-chroot /mnt /bin/bash <<EOF
bootctl install
EOF
fi
}

pacstrap(){
yes '' | pacstrap -i /mnt base base-devel
}

genfstab(){
	genfstab -U -p /mnt >> /mnt/etc/fstab
}

localegen(){
arch-chroot /mnt << EOF
locale-gen
EOF
}

add_users_passwords(){
arch-chroot /mnt << EOF
useradd -m -g users -G wheel,storage,power -s /bin/bash $user
EOF

arch-chroot /mnt << EOF
echo "$user:$password" | chpasswd
EOF

arch-chroot /mnt << EOF
echo "root:$rootpassword" | chpasswd
EOF
}

set_hostname(){
arch-chroot /mnt << EOF
echo $hostname > /etc/hostname
EOF
}

## Services

enable_enpinterface(){
arch-chroot /mnt << EOF
systemctl enable dhcpcd@"${enpinterface}".service
EOF
}

enable_wlpinterface(){
arch-chroot /mnt << EOF
systemctl enable "${wlpinterface}"
EOF
}

enable_fstrim(){
arch-chroot /mnt << EOF
systemctl enable fstrim.timer
EOF
}

## Configurations - adding text to files

conf_pcspkr_off(){
arch-chroot /mnt << EOF
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
EOF
}

conf_zoneinfo(){
arch-chroot /mnt << EOF
ln -s /usr/share/zoneinfo/Europe/Tallinn > /etc/localtime
EOF
}

conf_locale_gen(){
arch-chroot /mnt << EOF
sed -i '176 s/^#en_US/en_US/' /etc/locale.gen
EOF
}

conf_locale_conf(){
arch-chroot /mnt << EOF
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8
EOF
}

conf_bootloader(){
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  root=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw
EOF
}

conf_enable_multilib(){
	if [ "$(uname -m)" = "x86_64" ]
	then
		cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bkp
		sed '/^#\[multilib\]/{s/^#//;n;s/^#//;n;s/^#//}' /mnt/etc/pacman.conf > /tmp/pacman
		mv /tmp/pacman /mnt/etc/pacman.conf
		sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf
	fi
}

conf_aur(){
	echo -e '\n[archlinuxfr]\nSigLevel = Never\nServer = http://repo.archlinux.fr/$arch' >> /mnt/etc/pacman.conf
}

conf_sudoers(){
	echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > /mnt/etc/sudoers.d/99_wheel
}

## Misc

install_software(){
arch-chroot /mnt << EOF
pacman -S dialog wpa_supplicant bash-completion --noconfirm
EOF
}

update_repos(){
arch-chroot /mnt << EOF
pacman -Sy
EOF
}

## Categorize functions into blocks

setup_gui(){
	input_boot_firmware
	input_hostname
	input_username
	input_password
	input_rootpassword
	input_ethernet
	input_selectdisks
}

setup_disks(){
	destroy_selected_disk
	create_partitions
	create_filesystems
	mount_partitions
}

setup_install(){
	pacstrap
	genfstab
}

setup_chroot(){
	set_hostname
	add_users_passwords
	conf_sudoers
	install_bootloader
	conf_bootloader
	conf_locale_gen
	localegen
	conf_locale_conf
	conf_zoneinfo
	conf_pcspkr_off
	conf_enable_multilib
	conf_aur
	update_repos
}

setup_services(){
	enable_enpinterface
	enable_fstrim
}

#### Installation ####

logger
setup_gui
setup_disks
setup_install
setup_chroot
setup_services
