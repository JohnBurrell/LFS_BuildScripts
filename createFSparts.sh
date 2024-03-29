#!/bin/bash
#
# NOTE - disk sdb no longer exists - left the code in place in case it's resurrected
# this disk is now sda and sda1 is used as swap
# Assuming disk sdb exists then -
# There are three disks here: disk sdb has 10 partitions with 3 operating systems - 
# change sdb to suit your needs
# M.2 ssd nvme0n1 has 9 available partitions
# 1 to 3 have Arch OS loadeded. nvme1n1p1 is an EFI system partition and mounted as /boot
# NOTE all the kernels for the entire system are on this partition.
# 4 to 6 are for an LFS OS (Xfce)
# 7 to 9 are for another LFS OS of your choosing
# M.2 ssd nvme1n1 has 3 available partitions. 1 to 5 are reserved for Windows 11
# 6 to 8 are for an LFS OS.
#
as_root=true
if [ $UID -ne 0 ]; then
  as_root=false
  echo "Running as $(whoami)"
  echo "will run in test mode but will not create a file system on any partitions"
  echo "Run as root to create a file system on the selected partitions."
fi
LFS=$LFS
nvme0="nvme0n1"
nvme1="nvme1n1"
label="sdb"
diskLabel=$label
disk4=""
# which disk is mounted
isNvme0=false
isNvme1=false
isDisk=false
clear
if [ "$LFS" = "" ]; then
  echo "The LFS variable is not set"
  echo "Will set it to /mnt/lfs"
  export LFS="/mnt/lfs"
fi
if [ ! -d $LFS ]; then
  if $as_root; then
    echo "Directory $LFS doesn't exit"
    echo "Create it? (y/N)"
    read reply
      case $reply in
         [yY]|[yY][Ee][Ss])
              echo "Will create dir $LFS"
              mkdir -pv $LFS
         ;;
         [nN]|[nN][Oo])
              echo "Dir $LFS must exist to continue"
              echo "Exiting now"
              exit 1
         ;;
         *)
              echo "Dir $LFS must exist to continue"
              echo "Exiting now"
              exit 1
         ;;
      esac
  else # not root
    echo "Not running as root. Cannot create $LFS"
  fi
else
  echo "Directory $LFS exists"
fi
echo "LFS is set to $LFS"
#
checkRootPart () {
# checks that the root partition, partToFind, is in the array of Partitions
# $1 is the array of partition - mountpoint pairs
# $2 is the root partition without /dev/ on the front
declare -a arrayParts=("${!1}")
local partToFind=$2
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
echo "Will determine which partitions to use to create a file system."
# determine which disks are already mounted
echo "Looking for partitions that are mounted:" 
if [ "$LFS" = /mnt/lfs ]; then
  nvme0Parts=($(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/nvme0n1p/ && $2~/[/]/) {print $1, $2}}'))
  numnvme0=${#nvme0Parts[@]}
  if [ $numnvme0 -gt 0 ]; then
    echo "disk $nvme0 is mounted"
    echo "these partitions are mounted"
    echo "${nvme0Parts[@]}"
    isNvme0=true
    theOne=$nvme0
    diskMounted="${nvme0Parts[@]}"
  else
    echo "disk $nvme0 is not mounted"
  fi
  nvme1Parts=( $(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/nvme1n1p/ && $2~/[/]/) {print $1, $2}}') )
  numnvme1=${#nvme1Parts[@]}
  if [ $numnvme1 -gt 0 ]; then
    echo "disk $nvme1 is mounted"
    echo "these partitions are mounted"
    echo "${nvme1Parts[@]}"
    isNvme1=true
    theOne=$nvme1
    diskMounted="${nvme1Parts[@]}"
  else
    echo "disk $nvme1 is not mounted"
  fi
#
  labelParts=( $(lsblk --noheadings --raw -o NAME,MOUNTPOINT | awk '{if ($1~/sdb/ && $2~/[/]/) {print $1, $2}}') )
  numsdb=${#labelParts[@]}
  if [ $numsdb -gt 0 ]; then
    echo "disk $label is mounted"
    echo "these partitions are mounted"
    echo "${labelParts[@]}"
    isDisk=true
    theOne=$label # the sdb disk
    diskMounted="${labelParts[@]}"
  else
    echo "disk $label is not mounted"
  fi
#
# get the root partition to identify the host
  rootSystem=$(findmnt -n -o SOURCE /)
  echo "root partition is $rootSystem"
  rootNoDev=${rootSystem/\/dev\//}
#  echo "rootNoDev is $rootNoDev"
# check that the root partition, rootSystem, is in the array of mounted partitions
  checkRootPart diskMounted[@] $rootNoDev
  if [ "$?" = 0 ]; then
    echo "root partition $rootSystem found on the mounted disk $theOne - ** this is the host **"
  else
    echo "root partition $rootSystem is not one of ${diskMounted[@]}"
    echo "You need to unmount ${diskMounted[@]}"
    echo "Aborting"
    exit 1
  fi
  if $isNvme0; then # offer to create a file system on partitions on label, nvme0 or nvme1
    suite1="${label}3, 4 and 5 (LFS)"
    suite2="${label}6, 7, 8 and 9 (LFS)"
    suite3="${label}10, 11 and 12 (Arch KF5 plasma)"
    case $rootSystem in
       *p2) # Arch is mounted
         suite4="${nvme0}p4, p5 and p6 (LFS Xfce)"
         one="p4"
         two="p5"
         three="p6"
         suite5="${nvme0}p7, p8, p9 (LFS)"
         four="p7"
         five="p8"
         six="p9"
         suite6="${nvme1}p6, p7 and p8 (LFS)"
         seven="p6"
         eight="p7"
         nine="p8"
       ;;
       *p4) # LFS Xfce mounted
         suite4="${nvme0}p2 and p3 (Arch)"
         one="p2"
         two="p3"
         three=""    
         suite5="${nvme0}p7, p8, p9 (LFS)"
         four="p7"
         five="p8"
         six="p9"
         suite6="${nvme1}p6, p7 and p8 (LFS)"
         seven="p6"
         eight="p7"
         nine="p8"
       ;;
       *p7) # LFS mounted
         suite4="${nvme0}p2 and p3 (Arch)"
         one="p2"
         two="p3"
         three=""
         suite5="${nvme0}p4, p5 and p6 (LFS Xfce)"
         four="p4"
         five="p5"
         six="p6"
         suite6="${nvme1}p6, p7 and p8 (LFS)"
         seven="p6"
         eight="p7"
         nine="p8"
       ;;
       *p6)
         suite4="${nvme0}p2 and p3 (Arch)"
         one="p2"
         two="p3"
         three=""
         suite5="${nvme0}p4, p5 and p6 (LFS Xfce)"
         four="p4"
         five="p5"
         six="p6"
         suite6="${nvme0}p7, p8, p9 (LFS)"
         seven="p7"
         eight="p8"
         nine="p9"
       ;;
    esac
    echo "Choose one:"
    echo " "
    PS3="> "
    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6")
    select opt in "${options[@]}" "Quit"; do
        case "$REPLY" in
           1)
              echo "If sdb existed, would create a file system on partitions $suite1"
              disk1=3
              disk2=4
              disk3=5
              diskLabel=$label
              break
           ;;
           2)
              echo "If sdb existed, would create a file system on partitions $suite2"
              disk1=6
              disk2=7
              disk3=8
              disk4=9
              diskLabel=$label
              break
           ;;
           3)
              echo "If sdb existed, would create a file system on partitions $suite3"
              disk1=10
              disk2=11
              disk3=12
              diskLabel=$label
              break
           ;;
           4)
              echo "Will create a file system on partitions $suite4"
              disk1=$one
              disk2=$two
              disk3=$three
              diskLabel=$nvme0
              break
           ;;
           5)
              echo "Will create a file system on partitions $suite5"
              disk1=$four
              disk2=$five
              disk3=$six
              diskLabel=$nvme0
              break
           ;;
           6)
              echo "Will create a file system on partitions $suite6"
              disk1=$seven
              disk2=$eight
              disk3=$nine
              disklabel=$nvme0
              if [ "$disk1" = p6 ]; then diskLabel=$nvme1; fi
              break
           ;;
           $((${#options[@]}+1)))
              echo "Okay, will exit"
              exit 1
           ;;
           *) echo "Invalid option. Type 1, 2, 3, 4, 5, 6 or 7"
              :
           ;;
        esac
    done
#
  elif $isNvme1; then # if this disk is the host the partitions are p6, p7 and p8
    suite1="${label}3, 4 and 5 (LFS)"
    suite2="${label}6, 7, 8 and 9 (LFS)"
    suite3="${label}10, 11 and 12 (Arch KF5 plasma)"
    suite4="${nvme0}p2 and p3 (Arch)"
    suite5="${nvme0}p4, p5 and p6 (LFS Xfce)"
    suite6="${nvme0}p7, p8, and p9 (LFS)"
    echo "Choose one:"
    echo " "
    PS3="> "
    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6")
    select opt in "${options[@]}" "Quit"; do
        case "$REPLY" in
           1)
              echo "If sdb existed, would create a file system on partitions $suite1"
              disk1=3
              disk2=4
              disk3=5
              break
           ;;
           2)
              echo "If sdb existed, would create a file system on partitions $suite2"
              disk1=6
              disk2=7
              disk3=8
              disk4=9
              break
           ;;
           3)
              echo "If sdb existed, would create a file system on partitions $suite3"
              disk1=10
              disk2=11
              disk3=12
              break
           ;;
           4)
              echo "Will create a file system on partitions $suite4"
              disk1=p2
              disk2=p3
              disk3=""
              diskLabel=$nvme0
              break
           ;;
           5)
              echo "Will create a file system on partitions $suite5"
              disk1=p4
              disk2=p5
              disk3=p6
              diskLabel=$nvme0
              break
           ;;
           6)
              echo "Will create a file system on partitions $suite6"
              disk1=p7
              disk2=p8
              disk3=p9
              diskLabel=$nvme0
              break
           ;;
           $((${#options[@]}+1)))
              echo "Okay, will exit"
              exit 1
           ;;
           *) echo "Invalid option. Type 1, 2, 3, 4, 5, 6 or 7"
              :
           ;;
        esac
    done
# disk sdb1 not currently used so cannot be the host. Left the code as this may change
#  elif $isDisk; then # offer to create a file system on partitions on remaining label partitions, nvme0 and nvme1
#    suite1="${nvme0}p3, p4 and p5 (Ububtu)"
#    suite2="${nvme0}p6, p7 and p8 (Arch)"
#    suite3="${nvme0}p9, p10, p11 and p12 (LFS)"
#    suite4="${nvme1}p6, p7 and p8 (LFS xfce)"
#    suite5="${nvme1}p9, p10, p11 and p12 (LFS)"
#    case $rootSystem in
#       *sdb4)
#         one="6"
#         two="7"
#         three="8"
#         four="9"
#         suite6="${label}6, 7, 8 and 9"
#         five="10"
#         six="11"
#         seven="12"
#         eight=""
#         suite7="${label}10, 11 and 12"
#       ;;
#       *sdb7)
#         one="3"
#         two="4"
#         three="5"
#         four=""
#         suite6="${label}3, 4 and 5"
#         five="10"
#         six="11"
#         seven="12"
#         eight=""
#         suite7="${label}10, 11 and 12"
#       ;;
#       *sdb11)
#         one="3"
#         two="4"
#         three="5"
#         four=""
#         suite6="${label}3, 4 and 5"
#	 five="6"
#         six="7"
#         seven="8"
#         eight="9"
#         suite7="${label}6, 7, 8 and 9"
#       ;;
#    esac
#    echo "Choose one:"
#    echo " "
#    PS3="> "
#    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6" "$suite7")
#    select opt in "${options[@]}" "Quit"; do
#        case "$REPLY" in
#           1)
#              echo "Will create a file system on partitions $suite1"
#              disk1=p3
#              disk2=p4
#              disk3=p5
#              diskLabel=$nvme0
#              break
#           ;;
#           2)
#              echo "Will create a file system on partitions $suite2"
#              disk1=p6
#              disk2=p7
#              disk3=p8
#              diskLabel=$nvme0
#              break
#           ;;
#           3)
#              echo "Will create a file system on partitions $suite3"
#              disk1=p9
#              disk2=p10
#              disk3=p11
#              disk4=p12
#              diskLabel=$nvme0
#              break
#           ;;
#           4)
#              echo "Will create a file system on partitions $suite4"
#              disk1=p6
#              disk2=p7
#              disk3=p8
#              diskLabel=$nvme1
#              break
#           ;;
#           5)
#              echo "Will create a file system on partitions $suite5"
#              disk1=p9
#              disk2=p10
#              disk3=p11
#              disk4=p12
#              diskLabel=$nvme1
#              break
#           ;;
#           6)
#              echo "Will create a file system on partitions $suite6"
#              disk1=$one
#              disk2=$two
#              disk3=$three
#              if [ ! -z "$four" ]; then disk4=$four; fi
#              break
#           ;;
#           7)
#              echo "Will create a file system on partitions $suite7"
#              disk1=$five
#              disk2=$six
#              disk3=$seven
#              if [ ! -z "$eight" ]; then disk4=$eight; fi
#              break
#           ;;
#           $((${#options[@]}+1)))
#              echo "Okay, will exit"
#              exit 1
#           ;;
#           *) echo "Invalid option. Type 1, 2, 3, 4, 5, 6, 7 or 8"
#              :
#           ;;
#        esac
#    done
  fi
#
  if ! $as_root; then
    echo "If running as root, would create a filesystem on partitions:"
    echo "/dev/${diskLabel}${disk1}"
    echo "/dev/${diskLabel}${disk2}"
    echo "/dev/${diskLabel}${disk3}"
    if [ ! -z "$disk4" ]; then
      echo "/dev/${diskLabel}${disk4}"
    fi
    echo "Aborting"
    exit 1
  else
    echo "Running as root, will create a filesystem on partitions:"
    echo "/dev/${diskLabel}${disk1}"
    echo "/dev/${diskLabel}${disk2}"
    echo "/dev/${diskLabel}${disk3}"
    if [ ! -z "$disk4" ]; then
      echo "/dev/${diskLabel}${disk4}"
    fi
#
#exit 1
#
    mkfs.ext4 -jv /dev/${diskLabel}${disk1}
    mkfs.ext4 -jv /dev/${diskLabel}${disk2}
    mkfs.ext4 -jv /dev/${diskLabel}${disk3}
    if [ ! -z "$disk4" ]; then
      mkfs.ext4 -jv /dev/${diskLabel}${disk4}
    fi
  fi
# try and mount the swap partition
  if [ -e /dev/sda1 ]; then
    echo "swap partition is /dev/sda1"
# the swap partition may be in use
    echo "check if it's mounted"
    if [ $(swapon -s | grep -ci "/dev/sda1") -gt 0 ]; then 
      echo "swap partition /dev/sda1 is in use"
    else # make the swap partition
      mkswap -c --verbose /dev/sda1
    fi
  fi
else
    echo "Don't recognise LFS=$LFS. Can't create a file system on any partitions."
    echo "exit"
    exit 1
fi
echo "You should do export LFS=$LFS to create the global env variable"
