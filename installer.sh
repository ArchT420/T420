#!/bin/bash
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash

part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"	# /boot partition1 created by sgdisk
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"	# /swap partition2 created by sgdisk
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"	#   /	partition3 created by sgdisk
part_home="$(ls ${device}* | grep -E "^${device}p?4$")"	# /home partition4 created by sgdisk

echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initrd\t/initramfs-linux.img\noptions\troot=PARTUUID=$(blkid -s PARTUUID -o value ${part_root}) rw" > /mnt/boot/loader/entries/arch.conf

echo "done1"
echo "hyep"
echo "last"
echo "hyep"
