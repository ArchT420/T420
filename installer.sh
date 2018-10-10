#!/bin/bash
# This script can be run by executing the following:
# curl -sL https://git.io/fxcQv | bash
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"	#   /	partition3 created by sgdisk
echo -e 'title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initrd\t/initramfs-linux.img\noptions\troot=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw' > /mnt/boot/loader/entries/arch.conf

