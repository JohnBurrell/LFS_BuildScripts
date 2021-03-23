#!/bin/bash
#
if [ $UID -ne 0 ]; then echo Please run this script as root. ; exit 1; fi
LFS=$LFS
clear
if [ "$LFS" = "" ]; then
  echo "The LFS variable is not set"
  echo "Will set it to /mnt/lfs"
  export LFS="/mnt/lfs"
fi
#if [ "$LFS" = "" ]; then
#  echo "The LFS variable is not set"
#  echo "Choose one of the following:"
#  echo " "
#  PS3="> "
#  options=("export LFS=mnt/lfs")
#  select opt in "${options[@]}" "Quit"; do
#        case "$REPLY" in
#           1)
#              echo "LFS=/mnt/lfs"
#              export LFS="/mnt/lfs"
#              break
#           ;;
#           $((${#options[@]}+1)))
#              echo "Okay, will exit"
#              exit 1
#           ;;
#           *) echo "Invalid option. Type 1 or 2"
#              :
#           ;;
#        esac
#  done
#fi
if [ ! -d $LFS ]; then
  echo "Directory $LFS doesn't exit"
  echo "Run Chapter02.sh and then Chapter03.sh"
  exit 1
fi
HOMEDIR=/home/john/lfs # on the host
# since LFS-10 the tools dir is no longer a useful entity
# cp the tools dir from the host, if it exists
#if [ -d $HOMEDIR/tools ]; then
#  echo "Copy the tools dir to $LFS? (Y/n)"
#  read reply
#    case $reply in
#       [yY]|[yY][Ee][Ss])
#         rm -rfv $LFS/tools
#         cp -r $HOMEDIR/tools $LFS
#       ;;
#       [nN]|[nN][Oo])
#         echo "Continuing without copying the tools dir"
#       ;;
#       *)
#         rm -rfv $LFS/tools
#         cp -r $HOMEDIR/tools $LFS
#       ;;
#    esac
#else
#  echo "Dir $HOMEDIR/tools doesn't exist"
#  echo "Run Chapter 5 and 6 to create $LFS/tools and copy it to the host"
#fi
# create the sources subdir
mkdir -pv $LFS/sources/BOOK
# fill it with the sources
if [ -d $HOMEDIR/sources/BOOK ]; then
  echo "Copy the sources/BOOK dir to $LFS? (Y/n)"
  read reply
    case $reply in
       [yY]|[yY][Ee][Ss])
         cp -r $HOMEDIR/sources/BOOK/* $LFS/sources/BOOK/
	 echo "Copied sources from $HOMEDIR/sources/BOOK to $LFS/sources/BOOK"
       ;;
       [nN]|[nN][Oo])
         echo "Continuing without copying the sources/BOOK dir"
       ;;
       *)
         cp -r $HOMEDIR/sources/BOOK/* $LFS/sources/BOOK/
       ;;
    esac
else
  echo "No $HOMEDIR/sources dir found. Can't copy the sources."
# check if the sources dir contains files
  if [ -n "$(ls -A ${LFS}/sources/BOOK 2>/dev/null)" ]; then
    echo "$LFS/sources/BOOK contains files"
  else
    echo "$LFS/sources/BOOK is empty"
  fi
fi
# cp the pkguser file
if [ ! -f "$LFS/sources/pkguser.tar.xz" ]; then
  if [ -f $HOMEDIR/pkguser.tar.xz ]; then
    cp -v $HOMEDIR/pkguser.tar.xz $LFS/sources/
  else
    echo "File $HOMEDIR/pkguser.tar.xz doesn't exist. You need to create it."
  fi
else
  echo "file pkguser.tar.xz already in $LFS/sources"
fi
if [ -e "$HOMEDIR/.config" ]; then
  cp -v "$HOMEDIR/.config" $LFS/sources
else
  echo "No $HOMEDIR/.config file present. You'll need to create it manually."
fi
echo "You're now ready to run $HOMEDIR/lfsa"
