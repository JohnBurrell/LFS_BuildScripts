#!/bin/bash
#
# NOTE - disk sdb (an ssd) no longer exists - left the code in place in case it's resurrected
# disk sda is used for swap space to spare the nvme disks
# There are three disks here: disk sdb has 10 partitions with 3 operating systems - 
# 3,4,5 has one OS
# 6,7,8 and 9 has another OS
# and 10,11 and 12 has another OS
# M.2 ssd nvme0n1 is an nvme ssd with 11 partitions: 1 is an EFI system partition
# 2 and 3 are the Arch Linux OS, 4 - 7 is LFS (Xfce) and 8 - 1 is for LFS (Gnome) OS.
# M.2 ssd nvme1n1 has 7 available partitions. (p1 - p5 is for Windows 11. p6 - p8 is for Arch (xfce, or whatever is current). P9 - p12 is for an LFS OS, usually to match whatever is loaded on p6 - p8.

# create the fstab file
nvme0="nvme0n1p"
nvme1="nvme1n1p"
label="sdb"
LFS=$LFS
#
nvme0n1=false
nvme1n1=false
sdb=false
rootIsNvme0n1=false
rootIsNvme1n1=false
rootIsSDB=false
diskMounted=""
newLFS=""
declare -a disk
#
checkRootPart () {
# checks that the root partition, partToFind, is in the array of Partitions
# $1 is the array of partition - mountpoint pairs
# $2 is the root partition without /dev/ on the front
declare -a arrayParts=("${!1}")
partToFind=$2
local part
for part in ${arrayParts[@]}; do
  case $part in
     $partToFind)
       return 0 # found
     ;;
  esac
done
return 1 # not found
} # end checkRootPart
#
if [ "$LFS" = "" ]; then
  echo "The LFS variable is not set"
  echo "Will set it to /mnt/lfs"
  export LFS="/mnt/lfs"
fi
if [ "$LFS" = /mnt/lfs ]; then
# determine which partitions are mounted
  nvme0Parts=($(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/nvme0n1p/ && $2~/[/]/) {print $1, $2}}'))
  numnvme0=${#nvme0Parts[@]}
#
  nvme1Parts=( $(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/nvme1n1p/ && $2~/[/]/) {print $1, $2}}') )
  numnvme1=${#nvme1Parts[@]}
#
if [ $numnvme0 -eq 0 ]; then
  echo "nvme0Parts is empty"
elif [ $numnvme0 -eq 2 ]; then # the /boot partition only
  echo "nvme0Parts is the boot partition ${nvme0Parts[@]}"
elif [ $numnvme0 -eq 8 ]; then # the new LFS + /boot disk
  echo "disk nvme0n1 is the new LFS"
  echo "these partitions are mounted"
  echo "${nvme0Parts[@]}"
  newLFS=${nvme0Parts[@]}
  nvme0n1=true
fi
if [ $numnvme1 -eq 0 ]; then
  echo "nvme1Parts is empty"
elif [ $numnvme1 -eq 6 ]; then
  echo "disk nvme1n1 is the new LFS"
  echo "these partitions are mounted"
  echo "${nvme1Parts[@]}"
  newLFS=${nvme1Parts[@]}
  nvme1n1=true
fi
# identify the root partition
rootSystem=$(findmnt -n -o SOURCE /)
echo "root partition is $rootSystem"
rootNoDev=${rootSystem/\/dev\//}
echo "rootNoDev is $rootNoDev"
# declare associative array where the keys are the disk-names and the values are the mount-points
storDisk=""
declare -A mntPointDisk
# # declare associative array where the keys are the disk-names and the values are the UUIDs
declare -A mntPointUUID
for part in ${newLFS[@]}; do
  if [ "$part" = nvme0n1p1 -o "$part" = /boot ]; then # ignore the /boot partitiion for the moment
    :
  elif [ -z "$storDisk" ]; then
    storDisk=$part
  else # key stored so fill array
    mntPointDisk[$storDisk]=$part
    storDisk=""
  fi
done
mntPointDisk["sda1"]=none # swap disk
echo "#
disk name     mount-point"
for KK in "${!mntPointDisk[@]}"; do
  if [ "$KK" = sda1 ]; then
    echo "$KK      --- ${mntPointDisk[$KK]}"
  else
    echo "$KK --- ${mntPointDisk[$KK]}"
  fi
done
# turn each partition name into a UUID
for KK in "${!mntPointDisk[@]}"; do
  disk_uuid=$(blkid -o value -s UUID "/dev/${KK}")
  mntPointUUID[$KK]=$disk_uuid
done
# the swap partition on sda1
disk_uuid=$(blkid -o value -s UUID /dev/sda1) # swap partition
mntPointUUID["sda1"]=$disk_uuid
echo "#
disk name     UUID"
for KK in "${!mntPointDisk[@]}"; do
  if [ "$KK" = sda1 ]; then
    echo "$KK      --- ${mntPointUUID[$KK]}"
  else
    echo "$KK --- ${mntPointUUID[$KK]}"
  fi
done
# begin the fstab file
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system                              mount-point   type     options        dump   fsck
#                                                                                order
EOF
fsckVal=1
dumporder=0
# printf formats
fstabformat="%-46s %-9s %-8s %-12s %5s %5s\n"
thedisc="%-16s\n"
# print the root partition first
for KK in "${!mntPointDisk[@]}"; do
  if [ "${mntPointDisk[$KK]}" = "/" ]; then #print it
    printf "$thedisc" "# /dev/$KK" >> /etc/fstab
    printf "$fstabformat" "UUID=${mntPointUUID[$KK]}" "${mntPointDisk[$KK]}" "ext4" "rw,relatime" "$dumporder" "$fsckVal" >> /etc/fstab
  fi
done
fsckVal=2
# print /home next
for KK in "${!mntPointDisk[@]}"; do
  if [ "${mntPointDisk[$KK]}" = "/home" ]; then #print it
    printf "$thedisc" "# /dev/$KK" >> /etc/fstab
    printf "$fstabformat" "UUID=${mntPointUUID[$KK]}" "${mntPointDisk[$KK]}" "ext4" "rw,relatime" "$dumporder" "$fsckVal" >> /etc/fstab
  fi
done
# print /opt next
for KK in "${!mntPointDisk[@]}"; do
  if [ "${mntPointDisk[$KK]}" = "/opt" ]; then #print it
    printf "$thedisc" "# /dev/$KK" >> /etc/fstab
    printf "$fstabformat" "UUID=${mntPointUUID[$KK]}" "${mntPointDisk[$KK]}" "ext4" "rw,relatime" "$dumporder" "$fsckVal" >> /etc/fstab
  fi
done
# print the ESP
printf "$thedisc" "# /dev/nvme0n1p1" >> /etc/fstab
printf "$fstabformat" "UUID=585E-A734" "/boot" "vfat" "rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro" "$dumporder" "$fsckVal" >> /etc/fstab
#
# print swap last
echo "# /dev/sda1
UUID=${mntPointUUID["sda1"]}      none      swap     defaults         0     0" >> /etc/fstab
cat >> /etc/fstab << "EOF"

# End /etc/fstab
EOF
else
  echo "Don't recognise $LFS"
  echo "You need to edit this script"
fi
