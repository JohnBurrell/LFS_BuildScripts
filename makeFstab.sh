#!/bin/bash
#
# There are three disks here: disk sdb has 10 partitions with 3 operating systems - 
# sdb3 ,4, 5 has one OS
# sdb6, 7, 8 and 9 has another OS
# and sdb10, 11 and 12 has another OS
# M.2 ssd nvme0n1 is an nvme ssd with 9 partitions: 1 is an EFI system partition and 2 is a BIOS boot partition
# 3, 4 and 5 has Ubuntu loaded and 6, 7 and 8 is for an LFS OS. Partition 9 is swap
# M.2 ssd nvme1n1 has 6 partitions. 1, 2 and 3 is for another LFS OS. 4, 5 and 6 has Arch Linux loaded.
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
  labelParts=( $(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/sdb/ && $2~/[/]/) {print $1, $2}}') )
  numsdb=${#labelParts[@]}
#
  if [ $numnvme0 -gt 0 ]; then
    echo "disk nvme0n1 is mounted"
    echo "these partitions are mounted"
    diskMounted=${nvme0Parts[@]}
    echo "${diskMounted[@]}"
    nvme0n1=true
  else
    echo "disk nvme0n1 is not mounted"
  fi
  if [ $numnvme1 -gt 0 ]; then
    echo "disk nvme1n1 is mounted"
    echo "these partitions are mounted"
    if [ ! -z "$diskMounted" ]; then
      echo "diskMounted already filled - more than one disk mounted"
      echo "Investigate - Aborting"
      exit 1
    else
      diskMounted=${nvme1Parts[@]}
      echo "${diskMounted[@]}"
      nvme1n1=true
    fi
  else
    echo "disk nvme1n1 is not mounted"
  fi
  if [ $numsdb -gt 0 ]; then
    echo "disk sdb is mounted"
    echo "these partitions are mounted"
    if [ ! -z "$diskMounted" ]; then
      echo "diskMounted already filled - more than one disk mounted"
      echo "Investigate - Aborting"
      exit 1
    else
      diskMounted=${labelParts[@]}
      echo "${diskMounted[@]}"
      sdb=true
    fi
  else
    echo "disk sdb is not mounted"
  fi
#
# get the root partition to identify the partition to use
  rootSystem=$(findmnt -n -o SOURCE /)
  echo "root partition is $rootSystem"
  rootNoDev=${rootSystem/\/dev\//}
#  echo "rootNoDev is $rootNoDev"
#
# find the disk on which the root partition is mounted
  checkRootPart diskMounted[@] $rootNoDev
  if [ "$?" = 0 ]; then
    echo "root partition found on the mounted disk"
    if $nvme0n1; then
      echo "${nvme0/p/}"
      rootIsNvme0n1=true
    fi
    if $nvme1n1; then
      echo "${nvme1/p/}"
      rootIsNvme1n1=true
    fi
    if $sdb; then
      echo "$label"
      rootIsSDB=true
    fi
  else
    echo "return from checkRootPart is 1. Root partition not found"
    echo "Aborting"
    exit 1
  fi
#
echo "** Check that only one of the following is true **"
echo "rootIsNvme0n1 is $rootIsNvme0n1"
echo "rootIsNvme1n1 is $rootIsNvme1n1"
echo "rootIsSDB is $rootIsSDB"
  count=0
  for partnum in ${diskMounted[@]}; do
    disk[count]="${partnum}"
    ((count++))
  done
#
# TODO test all the sdb disk cases
#
# can turn the partition name into a UUID as follows:
disk0_uuid=$(blkid -o value -s UUID "/dev/${disk[0]}")
disk2_uuid=$(blkid -o value -s UUID "/dev/${disk[2]}")
disk4_uuid=$(blkid -o value -s UUID "/dev/${disk[4]}")
disk9_uuid=$(blkid -o value -s UUID /dev/nvme0n1p9) # swap partition
if $rootIsSDB; then # use /dev/sdb13 as swap
  disk13_uuid=$(blkid -o value -s UUID /dev/sdb13)
  echo "/dev/sdb13 UUID is $disk13_uuid"
fi
# following used when /opt is separate partition on sdb
if [ ! -z "${disk[6]}" ]; then
  disk6_uuid=$(blkid -o value -s UUID "/dev/${disk[6]}")
  echo "${disk[6]} UUID is $disk6_uuid"
fi
echo "${disk[0]} UUID is $disk0_uuid"
echo "${disk[2]} UUID is $disk2_uuid"
echo "${disk[4]} UUID is $disk4_uuid"
echo "/dev/nvme0n1p9 UUID is $disk9_uuid"
#
  cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system                              mount-point   type     options        dump   fsck
#                                                                                order
EOF
  echo "# /dev/${disk[0]}
UUID=$disk0_uuid     ${disk[1]}          ext4    rw,relatime       0     1
# /dev/${disk[2]}
UUID=$disk2_uuid     ${disk[3]}      ext4    rw,relatime       0     2
# /dev/${disk[4]}
UUID=$disk4_uuid     ${disk[5]}      ext4    rw,relatime       0     2" >> /etc/fstab
  if [ ! -z "${disk[6]}" ]; then
    echo "# /dev/${disk[6]}
UUID=$disk6_uuid     ${disk[7]}      ext4    rw,relatime       0     2" >> /etc/fstab
  fi
# set the rest of fstab
echo "# /dev/nvmeon1p9
UUID=$disk9_uuid      none      swap     defaults         0     0" >> /etc/fstab
  if $rootIsSDB; then
    echo "# /dev/sdb13
UUID=$disk13_uuid      none      swap     defaults         0     0" >> /etc/fstab
  fi
  cat >> /etc/fstab << "EOF"

# End /etc/fstab
EOF
else
  echo "Don't recognise $LFS"
  echo "You need to edit this script"
fi
