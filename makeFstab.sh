#!/bin/bash
#
# NOTE - disk sdb no longer exists - left the code in place in case it's resurrected
# There are three disks here: disk sdb has 10 partitions with 3 operating systems - 
# 3,4,5 has one OS
# 6,7,8 and 9 has another OS
# and 10,11 and 12 has another OS
# M.2 ssd nvme0n1 is an nvme ssd with 13 partitions: 1 is an EFI system partition and 2 is a BIOS boot partition
# 3,4 and 5 has Ubuntu loaded, 6,7,and 8 is Arch (gnome) and 9,10,11 and 12 is for an LFS (Gnome) OS. Partition 13 is swap
# M.2 ssd nvme1n1 has 7 available partitions and one swap. (p1 - p5 is for Windows 10). p6 - p8 is for Arch (xfce, or whatever is current). P9 - p12 is for an LFS OS, usually to match whatever is loaded on p6 - p8. Partition p13 is swap

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
# declare associative array where the keys are the disk-names and the values are the mount-points
storDisk=""
declare -A mntPointDisk
for part in ${diskMounted[@]}; do
  if [ -z "$storDisk" ]; then # store the disk name
    storDisk=$part
  else # key stored so fill array
    mntPointDisk[$storDisk]=$part
    storDisk=""
  fi
done
echo "disk name and mount-point"
for KK in "${!mntPointDisk[@]}"; do
  echo "$KK --- ${mntPointDisk[$KK]}"
done
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
#
# NOTE - haven't tested all the sdb disk cases
#
# can turn the partition name into a UUID as follows:
count=0
for KK in "${!mntPointDisk[@]}"; do
  disk_uuid[count]=$(blkid -o value -s UUID "/dev/${KK}")
  echo "${mntPointDisk[$KK]} UUID is ${disk_uuid[count]}"
  ((count++))
done
disk_uuid[count]=$(blkid -o value -s UUID /dev/nvme0n1p13) # swap partition
echo "/dev/nvme0n1p13 UUID is ${disk_uuid[count]}"
((count++))
disk_uuid[count]=$(blkid -o value -s UUID /dev/nvme1n1p13) # swap partition
echo "/dev/nvme1n1p13 UUID is ${disk_uuid[count]}"
((count++))
disk_uuid[count]=$(blkid -o value -s UUID /dev/sdb13)
echo "/dev/sdb13 UUID is ${disk_uuid[count]}"
# write the fstab file
  cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system                              mount-point   type     options        dump   fsck
#                                                                                order
EOF
count=0
fsckVal=1
dumporder=0
# printf formats
fstabformat="%-46s %-9s %-8s %-12s %5s %5s\n"
thedisc="%-16s\n"
if [ "$nvme0n1" = true -o "$nvme1n1" = true ]; then
  for KK in "${!mntPointDisk[@]}"; do
    printf "$thedisc" "# /dev/$KK" >> /etc/fstab
    printf "$fstabformat" "UUID=${disk_uuid[count++]}" "${mntPointDisk[$KK]}" "ext4" "rw,relatime" "$dumporder" "$fsckVal" >> /etc/fstab
    fsckVal=2
  done
else # using disk sdb
  for KK in "${!mntPointDisk[@]}"; do
    echo "# /dev/$KK
UUID=${disk_uuid[count++]}     ${mntPointDisk[$KK]} $buffer     ext4    rw,relatime       0     $fsckVal" >> /etc/fstab
    ((count++))
    if [ $count -eq 1 ]; then
      buffer="    "
      fsckVal=2
    elif [ $count -eq 3 ]; then
      buffer=" "
      fsckVal=2
    else
      buffer=""
    fi
  done
fi
#
# set the rest of fstab
echo "# /dev/nvme0n1p13
UUID=${disk_uuid[count]}      none      swap     defaults         0     0" >> /etc/fstab
((count++))
echo "# /dev/nvme1n1p13
UUID=${disk_uuid[count]}      none      swap     defaults         0     0" >> /etc/fstab
cat >> /etc/fstab << "EOF"

# End /etc/fstab
EOF
else
  echo "Don't recognise $LFS"
  echo "You need to edit this script"
fi
