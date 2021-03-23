#!/bin/bash
#
# There are three disks here: disk sdb has 10 partitions with 3 operating systems - 
# 3,4,5 has one OS
# 6,7,8 and 9 has another OS
# and 10,11 and 12 has another OS
# M.2 ssd nvme0n1 is an nvme ssd with 9 partitions: 1 is an EFI system partition and 2 is a BIOS boot partition
# 3,4 and 5 has Ubuntu loaded and 6,7,and 8 is for an LFS OS. Partition 9 is swap
# M.2 ssd nvme1n1 has 6 partitions. 1,2 and 3 is for another LFS OS. 4,5 and 6 has Arch Linux loaded.
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
isNvme1=flase
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
    useNvme1=$nvme1
    useNvme0=$nvme0
    suite1="${label}3, 4 and 5"
    suite2="${label}6, 7, 8 and 9"
    suite3="${label}10, 11 and 12"
    suite4="${useNvme1}p1, p2 and p3"
    suite5="${useNvme1}p4, p5 and p6" # Arch Linux OS
    case $rootSystem in
       *p7)
         suite6="${useNvme0}p3, p4, p5" # ubuntu OS
         one="p3"
         two="p4"
         three="p5"
       ;;
       *p4)
         suite6="${useNvme0}p6, p7, p8"
         one="p6"
         two="p7"
         three="p8"
       ;;
    esac
    echo "Choose one:"
    echo " "
    PS3="> "
    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6")
    select opt in "${options[@]}" "Quit"; do
        case "$REPLY" in
           1)
              echo "Will create a file system on partitions $suite1"
              disk1=3
              disk2=4
              disk3=5
              break
           ;;
           2)
              echo "Will create a file system on partitions $suite2"
              disk1=6
              disk2=7
              disk3=8
              disk4=9
              break
           ;;
           3)
              echo "Will create a file system on partitions $suite3"
              disk1=10
              disk2=11
              disk3=12
              break
           ;;
           4)
              echo "Will create a file system on partitions $suite4"
              disk1=p1
              disk2=p2
              disk3=p3
              diskLabel=$nvme1
              break
           ;;
           5)
              echo "Will create a file system on partitions $suite5"
              disk1=p4
              disk2=p5
              disk3=p6
              diskLabel=$nvme1
              break
           ;;
           6)
              echo "Will create a file system on partitions $suite6"
              disk1=$one
              disk2=$two
              disk3=$three
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
#
  elif $isNvme1; then # offer to create a file system on partitions on label, nvme0 or nvme1
    useNvme0=$nvme0
    useNvme1=$nvme1
    suite1="${label}3, 4 and 5"
    suite2="${label}6, 7, 8 and 9"
    suite3="${label}10, 11 and 12"
    suite4="${useNvme0}p3, p4 and p5" # the Ubuntu OS
    suite5="${useNvme0}p6, p7 and p8"
    case $rootSystem in
       *p2)
         suite6="${useNvme1}p4, p5, p6" # the Arch Linux OS
         one="p4"
         two="p5"
         three="p6"
       ;;
       *p5)
         suite6="${useNvme1}p1, p2, p3"
         one="p1"
         two="p2"
         three="p3"
       ;;
    esac
    echo "Choose one:"
    echo " "
    PS3="> "
    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6")
    select opt in "${options[@]}" "Quit"; do
        case "$REPLY" in
           1)
              echo "Will create a file system on partitions $suite1"
              disk1=3
              disk2=4
              disk3=5
              break
           ;;
           2)
              echo "Will create a file system on partitions $suite2"
              disk1=6
              disk2=7
              disk3=8
              disk4=9
              break
           ;;
           3)
              echo "Will create a file system on partitions $suite3"
              disk1=10
              disk2=11
              disk3=12
              break
           ;;
           4)
              echo "Will create a file system on partitions $suite4"
              disk1=p3
              disk2=p4
              disk3=p5
              diskLabel=$nvme0
              break
           ;;
           5)
              echo "Will create a file system on partitions $suite5"
              disk1=p6
              disk2=p7
              disk3=p8
              diskLabel=$nvme0
              break
           ;;
           6)
              echo "Will create a file system on partitions $suite5"
              disk1=$one
              disk2=$two
              disk3=$three
              diskLabel=$nvme1
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
  elif $isDisk; then # offer to create a file system on partitions on remaining label partitions, nvme0 and nvme1
    useNvme=$nvme0
    useNvme1=$nvme1
    case $diskmounted in
       *"/dev/${label}4"*)
         suite1="${label}6, 7, 8 and 9"
         suite2="${label}10, 11 and 12"
         suite3="${useNvme0}p3, p4 and p5" # the Ubuntu OS
         suite4="${useNvme0}p6, p7 and p8"
         suite5="${useNvme1}p1, p2 and p3"
         suite6="${useNvme1}p4, p5 and p6"
       ;;
       *"/dev/${label}7"*)
         suite1="${label}3, 4 and 5"
         suite2="${label}10, 11 and 12"
         suite3="${useNvme0}p3, p4 and p5"
         suite4="${useNvme0}p6, p7 and p8"
         suite5="${useNvme1}p1, p2 and p3"
         suite6="${useNvme1}p4, p5 and p6"
       ;;
       *"/dev/${label}11"*)
         suite1="${label}3, 4 and 5"
         suite2="${label}6, 7, 8 and 9"
         suite3="${useNvme0}p3, p4 and p5"
         suite4="${useNvme0}p6, p7 and p8"
         suite5="${useNvme1}p1, p2 and p3"
         suite6="${useNvme1}p4, p5 and p6"
       ;;
    esac
    echo "Choose one:"
    echo " "
    PS3="> "
    options=("$suite1" "$suite2" "$suite3" "$suite4" "$suite5" "$suite6")
    select opt in "${options[@]}" "Quit"; do
        case "$REPLY" in
           1)
              echo "Will create a file system on partitions $suite1"
              case $diskmounted in
                 *"/dev/${label}4"*)
                   disk1=6
                   disk2=7
                   disk3=8
                   disk4=9
                   break
                 ;;
                 *"/dev/${label}7"*)
                   disk1=3
                   disk2=4
                   disk3=5
                   break
                 ;;
                 *"/dev/${label}11"*)
                   disk1=3
                   disk2=4
                   disk3=5
                   break
                 ;;
              esac
           ;;
           2)
              echo "Will create a file system on partitions $suite2"
              case $diskmounted in
                 *"/dev/${label}4"*)
                   disk1=10
                   disk2=11
                   disk3=12
                   break
                 ;;
                 *"/dev/${label}7"*)
                   disk1=10
                   disk2=11
                   disk3=12
                   break
                 ;;
                 *"/dev/${label}11"*)
                   disk1=6
                   disk2=7
                   disk3=8
                   disk4=9
                   break
                 ;;
              esac
           ;;
           3)
              echo "Will create a file system on partitions $suite3"
              disk1=p3
              disk2=p4
              disk3=p5
              diskLabel=$nvme0
              break
           ;;
           4)
              echo "Will create a file system on partitions $suite4"
              disk1=p6
              disk2=p7
              disk3=p8
              diskLabel=$nvme0
              break
           ;;
           5)
              echo "Will create a file system on partitions $suite5"
              disk1=p1
              disk2=p2
              disk3=p3
              diskLabel=$nvme1
              break
           ;;
           6)
              echo "Will create a file system on partitions $suite6"
              disk1=p4
              disk2=p5
              disk3=p6
              diskLabel=$nvme1
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
else
    echo "Don't recognise LFS=$LFS. Can't create a file system on any partitions."
    echo "exit"
    exit 1
fi
echo "You should do export LFS=$LFS to create the global env variable"
