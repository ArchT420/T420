#!/bin/bash
#
#
#
# This script can be run by executing the following:
# curl -sL https://git.io/fxZL0 | bash


# Set the mirrorlist from https://www.archlinux.org/mirrorlist/
# and rank 5 best mirrors, while commenting out the rest.



## Select the installation disk, example: /dev/sda or /dev/sdb etc.
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installtion disk" 0 0 0 ${devicelist}) || exit 1
clear

## Zap the selected disk
sgdisk -Z ${device}

## Create partitions on the selected disk
sgdisk -n 1:0:+200M -t 0:EF00 -c 0:"boot" ${device} # partition 1 (UEFI BOOT), default start block, 200MB, type EF00 (EFI), label: "boot"
sgdisk -n 2:0:+4G -t 0:8200 -c 0:"swap" ${device} # partition 2 (SWAP), default start block, 4GB, type 8200 (swap), label: "swap"
sgdisk -n 3:0:+3G -c 0:"root" ${device} # partition 3 (ROOT), default start block, 80GB, label: "swap"
sgdisk -n 4:0:0 -c 0:"home" ${device} # partition 4, (Arch Linux), default start, remaining space, label: "swap"



### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")
