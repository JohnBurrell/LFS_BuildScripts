#!/bin/bash

export LFS=/mnt/lfs
bootdir=${LFS}/boot
if [ ! -e $bootdir ]; then
  echo "Can't access $bootdir"
  echo "Chroot into $LFS in order to continue"
  exit 1
fi
GetvmVersion () {
# $1 is the name of the vmlinuz file
# $2 is the name to remove
# $3 is the name to trim against - SVN in this case
local vmFileName=$1
local remove=$2
local trim=$3
vmFileVers=""
vmExt="${vmFileName#*${remove}}"
vmFileVers="${vmExt%${trim}*}"
return 0
} # end GetvmVersion
#
ntor () {
local remove="simple-"
while read -r line
do
  case $line in
    *Linux-*)
       etitle=$( echo $line | awk '{print $2}' )
       etitle=${etitle#"'"} # remove the quotes
       etitle=${etitle%"'"}
       esda8=$( echo $line | awk '{print $10}' )
       esda8="${esda8#*${remove}}"
       esda8=${esda8%"'"}
    ;;
    *ahci0,gpt6*)
       esda6=$( echo $line | awk '{print $NF}' )
    ;;
    *vmlinuz-[0-9]*)
       evmlinuz=$( echo $line | awk '{print $2}' )
       evmlinuz=${evmlinuz#"/"} # remove the / at the beginning
    ;;
  esac
done < $grub_file
} # end ntor
#
uuid_sda8=$( blkid | grep sda8 | awk -F\" '{print $2}' )
uuid_sda6=$( blkid | grep sda6 | awk -F\" '{print $2}' )
grub_file="/boot/grub/grub.cfg"
ntor # set up the replacement strings
echo "These strings - "
echo $esda8
echo $esda6
echo $evmlinuz
echo $etitle
echo "will be replaced by these - "
# update the file
echo $uuid_sda8
echo $uuid_sda6
sed -e "s/$esda8/$uuid_sda8/" \
    -e "s/$esda6/$uuid_sda6/g" \
    -i $grub_file
# check if more than one vmlinuz file present in bootdir
getFile=( $(ls -l $bootdir | grep vmlinuz | awk '{print $NF}') )
count=${#getFile[@]}
if [ $count -eq 0 ]; then
  echo "No vmlinuz file found in $bootdir"
  echo "Exit now"
  exit 1
elif [ $count -gt 1 ]; then
  echo "There are $count vmlinuz files in $bootdir"
  echo "Which one do you want to use?"
  for (( i=0; i<count; i++ )); do
    echo ${getFile[i]}
    echo "Do you want this one? (Y/n)"
    read reply
    case $reply in
      [yY]|[yY][Ee][Ss])
        echo "okay will use ${getFile[i]}"
        vmFile=${getFile[i]}
      ;;
      [nN]|[nN][Oo])
        continue
      ;;
      *)
        echo "okay will use ${getFile[i]}"
        vmFile=${getFile[i]}
      ;;
    esac
  done
else
  vmFile=${getFile[i]}
fi

sed -e "s/$evmlinuz/$vmFile/" -i $grub_file
echo $vmFile
GetvmVersion $vmFile vmlinuz -SVN
title="Linux${vmFileVers}"
sed -e "s/$etitle/$title/" -i $grub_file
echo $title
