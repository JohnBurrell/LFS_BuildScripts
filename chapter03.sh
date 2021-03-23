#!/bin/bash
#
if [ $UID -ne 0 ]; then echo Please run this script as root.; exit 1; fi
LFS=$LFS
clear
if [ "$LFS" = "" ]; then
  echo "The LFS variable is not set"
  echo "Will set it to /mnt/lfs"
  export LFS="/mnt/lfs"
fi
if [ ! -d $LFS ]; then
  echo "Directory $LFS doesn't exist"
  echo "Run chapter02.sh before Chapter03.sh"
  exit 1
fi
if [ ! -d $LFS/sources/BOOK ]; then
  mkdir -pv $LFS/sources/BOOK
fi
if [ ! -d $LFS/tools ]; then
  mkdir -v $LFS/tools
fi
if [ ! -L /tools ]; then
  if [ -d /tools -o -f /tools ]; then
    echo "/tools needs to be a symlink on the host. Please move it in order to continue."
    exit 1
  else
    ln -sv $LFS/tools /
  fi
else
  echo "symbolic link /tools exists"
  echo "will reset it to ensure it is correct"
  rm -v /tools
  ln -sv $LFS/tools /
fi
# set minimal directory layout
mkdir -pv $LFS/{etc,opt,run,var,usr/{,bin,lib}}
case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac
if [ ! -L $LFS/bin ]; then
  echo "create the symlink $LFS/bin"
  ln -sf usr/bin $LFS/bin
else
  echo "symlink $LFS/bin exists"
fi
if [ ! -L $LFS/lib ]; then
  echo "create the symlink $LFS/lib"
  ln -sf usr/lib $LFS/lib
else
  echo "symlink $LFS/lib exists"
fi
if [ ! -L $LFS/sbin ]; then
  echo "create the symlink $LFS/sbin"
  ln -sf usr/bin $LFS/sbin
else
  echo "symlink $LFS/sbin exists"
fi
if [ ! -L $LFS/usr/sbin ]; then
  echo "create the symlink $LFS/usr/sbin"
  ln -sf bin $LFS/usr/sbin
else
  echo "symlink $LFS/usr/sbin exists"
fi
# create the user lfs
ret=false
getent passwd lfs > /dev/null 2>&1 && ret=true
if ! $ret; then # create it
# does uid 1001 exist for lfs?
  if [ $(cat /etc/passwd | awk -F: '{print $3}' | grep -q '^1001$';echo $?) -ne 0 ]; then
    echo "creating user lfs"
    groupadd -g 1001 lfs
    useradd -s /bin/bash -u 1001 -g lfs -m -k /dev/null lfs
    echo "*** set a password for lfs ***"
  else
    echo "cannot use gid 1001 for lfs. Already exists"
    echo "either choose a different gid for user lfs"
    echo "or edit /etc/group and etc/passwd to use 1001"
    exit 1
  fi
else # user lfs exists
  echo "User lfs exists"
fi
ispkguser=true
echo "Installing as pkguser? (Y/n)"
read reply
  case $reply in
     [nN]|[nN][Oo])
          ispkguser=false # installing as root
     ;;
  esac
if $ispkguser; then # does the install group exist
  ret=false
  getent group install > /dev/null 2>&1 && ret=true
  if ! $ret; then # create it
    echo "Creating the install group"
    groupadd -g 9999 install
  else
    echo "group install exists"
  fi
# change the minimal dir layout to install directories
  chgrp install $LFS/{etc,lib64,var,tools,usr/{,bin,lib}}
  chmod 1775 $LFS/{etc,lib64,var,tools,usr/{,bin,lib}}
else # as root
  echo "installing as root"
  echo "will set the owner of the directories as lfs"
# create the environmant
  cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
  cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
export LFS LC_ALL LFS_TGT PATH
EOF
  source /home/lfs/.bash_profile   
# user lfs exists so set the directories to be owned by lfs
  chown -v lfs $LFS/{etc,lib64,var,tools,usr/{,bin,lib}}
fi
# create the files that are in tools/pkguser/installdirs.lst and make them install dirs
#mkdir -pv $LFS/{opt,run,usr/{include,share/{,dict,doc,info,locale,misc,terminfo,zoneinfo,man/{,man1,man2,man3,man4,man5,man6,man7,man8}}},var/{lib,opt,cache,log,local/{,la-files}}}
#chgrp install $LFS/{opt,run,usr/{include,share/{,dict,doc,info,locale,misc,terminfo,zoneinfo,man/{,man1,man2,man3,man4,man5,man6,man7,man8}}},var/{lib,opt,cache,log,local/{,la-files}}}
#chmod 1775 $LFS/{opt,run,usr/{include,share/{,dict,doc,info,locale,misc,terminfo,zoneinfo,man/{,man1,man2,man3,man4,man5,man6,man7,man8}}},var/{lib,opt,cache,log,local/{,la-files}}}
