#!/bin/bash
#
if [ $UID -ne 0 ]; then echo Please run this script as root; exit 1; fi
#
if [ $# -lt 1 -o  $# -gt 3 -o "$1" = "--help" ]; then
  echo 1>&2
  echo 1>&2 'USAGE: '"${0##*/}"' userid groupid delete'
  echo 1>&2
  echo 1>&2 'userid must either be given or "*". If groupid is absent,'
  echo 1>&2 'then if userid is given, groupid=userid. If userid is "*",'
  echo 1>&2 'then groupid must be given.'
  echo 1>&2 'Either userid or groupid can be "*" which will get all files'
  echo 1>&2 'with the given userid or groupid.'
  echo 1>&2 'If delete present, will delete all files in the list.'
  echo 1>&2 'Can specify willdelete which will show which files would'
  echo 1>&2 'be deleted if delete is used.'
  echo 1>&2 '    (numeric UID/GID allowed).'
  exit 1
fi
# $1 is the uid
userid=$1
if [ "$userid" = "*" ]; then
  echo "UID set to wild card."
fi
# $2, if present, is the gid. If absent will set gid=uid
if [ "$2" = "*" ]; then
  if [ "$userid" = "*" ]; then
    echo "You need to specify the GID, as UID is wild."
    exit 1
  else
    echo "GID set to wild card."
    groupid=$2
  fi
elif [ -z $2 ]; then # absent
  if [ "$userid" = "*" ]; then
    echo "You need to specify the GID, as UID is wild."
    exit 1
  else
    groupid=$userid
  fi
else
  groupid=$2
fi
# $3, if present, is delete, to delete all files in the list
# or willdelete to show which files would be deleted.
DELETE=false
WILLDELETE=false
delPkg=$3
delPkg=$(echo ${delPkg,,*}) # make sure delPkg is lowercase
echo " "
echo "Files owned by $userid:$groupid"
if [ "$delPkg" = delete ]; then
  DELETE=true
  echo " "
  echo "*** WARNING! WARNING! WARNING! ***"
  echo "*** Will delete all files in the list for package $userid:$groupid ***"
elif [ "$delPkg" = willdelete ]; then
  WILLDELETE=true
  echo "(The following files would be deleted)"
  echo " "
elif [ ! -z $3 ]; then
  echo "*** $3 not recognised ***"
  echo "*** \$3, if present, must be either willdelete or delete ***"
fi
#
# create unique tmp file to store o/p
tmpfile=/tmp/$(date +%d%B%Y_%H:%M)tmp
#
# don't want to search /proc, /usr/src, /home, /dev, /tools or anything under /mnt, /blfs-commands, /blfs-html, /blfs-sources or /blfsBuildFiles
# want to catch files with uid=$1 or wild, with gid=uid, or $2 or wild
# 
if [ "$userid" = root ]; then # don't include anything under /root, as everything is uid root or /opt as there are no root files under /opt (yet!)
  if [ "$groupid" = "*" ]; then # just specify the userid
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -not \( -path /usr/src -prune \) -not \( -path /home -prune \) -not \( -path /etc/NetworkManager/system-connections -prune \) -not \( -path /dev -prune \) -not \( -path /tools -prune \) -not \( -path /mnt -prune \) -not \( -path /root -prune \) -not \( -path /opt -prune \) -not \( -path /blfs-commands -prune \) -not \( -path /blfs-html -prune \) -not \( -path /blfs-sources -prune \) -not \( -path /blfsBuildFiles -prune \) -user $userid | sort -u > $tmpfile
  else # specify both userid and groupid
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -not \( -path /usr/src -prune \) -not \( -path /home -prune \) -not \( -path /etc/NetworkManager/system-connections -prune \) -not \( -path /dev -prune \) -not \( -path /tools -prune \) -not \( -path /mnt -prune \) -not \( -path /root -prune \) -not \( -path /opt -prune \) -not \( -path /blfs-commands -prune \) -not \( -path /blfs-html -prune \) -not \( -path /blfs-sources -prune \) -not \( -path /blfsBuildFiles -prune \) -user $userid -group $groupid | sort -u > $tmpfile
  fi
elif [ "$userid" = "*" ]; then # just specify the groupid
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -not \( -path /usr/src -prune \) -not \( -path /home -prune \) -not \( -path /root/LFS_BOOK -prune \) -not \( -path /etc/NetworkManager/system-connections -prune \) -not \( -path /dev -prune \) -not \( -path /tools -prune \) -not \( -path /mnt -prune \) -not \( -path /blfs-commands -prune \) -not \( -path /blfs-html -prune \) -not \( -path /blfs-sources -prune \) -not \( -path /blfsBuildFiles -prune \) -group $groupid | sort -u > $tmpfile
elif [ "$groupid" = "*" ]; then # just specify the userid
    find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -not \( -path /usr/src -prune \) -not \( -path /home -prune \) -not \( -path /dev -prune \) -not \( -path /tools -prune \) -not \( -path /mnt -prune \) -not \( -path /blfs-commands -prune \) -not \( -path /blfs-html -prune \) -not \( -path /blfs-sources -prune \) -not \( -path /blfsBuildFiles -prune \) -user $userid | sort -u > $tmpfile
else # both userid and groupid specified
   find / -not \( -path /proc -prune \) -not \( -path /sys -prune \) -not \( -path /usr/src -prune \) -not \( -path /home -prune \) -not \( -path /dev -prune \) -not \( -path /tools -prune \) -not \( -path /mnt -prune \) -not \( -path /blfs-commands -prune \) -not \( -path /blfs-html -prune \) -not \( -path /blfs-sources -prune \) -not \( -path /blfsBuildFiles -prune \) \( -user $userid -a -group $groupid \) | sort -u > $tmpfile
fi
# need the long form of the filenames
if [ -s $tmpfile ]; then # file is not empty
  a=$( < $tmpfile)
#  vim -u NONE +'1d' +wq! $tmpfile #  a clever way of deleting first line of a file
  for file in ${a[@]}; do # block any recursion with maxdepth 0
    if [ "$file" != "/" ]; then # don't want to search everything again!
      find $file -maxdepth 0 -type d -exec ls -ld {} \;
      find $file -maxdepth 0 -type f -exec ls -l {} \;
    fi
  done
  echo " "
  if [ "$userid" = root -o "$userid" = "*" ]; then
    echo "files setuid or setgid root"
    for file in ${a[@]}; do
      if [ "$file" != "/" ]; then
        find $file -maxdepth 0 \( -perm -u+s -o -perm -g+s \) -type f -exec ls -l {} \;
      fi
    done
    echo " "
  fi
  if [ "$groupid" = "*" ]; then
    echo "files with group install"
    for file in ${a[@]}; do
      if [ "$file" != "/" ]; then
        find $file -maxdepth 0 -user $userid -group install -type f -exec ls -l {} \;
        find $file -maxdepth 0 -user $userid -group install -type d -exec ls -ld {} \;
      fi
    done
    echo " "
  fi
  echo "files which are world writable"
  for file in ${a[@]}; do
    if [ "$file" != "/" ]; then
      find $file -maxdepth 0 -perm -o+w -type d -exec ls -ld {} \;
      find $file -maxdepth 0 -perm -o+w -type f -exec ls -l {} \;
    fi
  done
  echo " "
  echo "files which are group writable"
  for file in ${a[@]}; do
    if [ "$file" != "/" ]; then
      find $file -maxdepth 0 -perm /0020 -type d -exec ls -ld {} \;
      find $file -maxdepth 0 -perm /0020 -type f -exec ls -l {} \;
    fi
  done
  echo " "
#  echo "files with hardlinks"
#  for file in ${a[@]}; do
#    find $file -type f -links +1 -printf '%i %n %p\n'
#  done
#  echo " "
  echo "symlinks"
  for file in ${a[@]}; do
    if [ "$file" != "/" ]; then
      find $file -maxdepth 0 -type l -exec ls -l {} \;
    fi
  done
  echo " "
# broken or cyclic symlinks
  echo "symlinks that are broken or cyclic"
  for file in ${a[@]}; do
    if [ "$file" != "/" ]; then
      find $file -maxdepth 0 -type l -exec test ! -e {} \; -print
    fi
  done
  echo " "
# delete files
  if [ $DELETE = true ]; then
    tmparray=($a) # need an array so it can be traversed backwards
    for (( i=${#tmparray[@]}-1; i>=0; i-- )); do
      if [ ! -d ${tmparray[i]} ]; then rm -v ${tmparray[i]}; fi
    done
# delete the dirs which are empty after files have been deleted
    for (( i=${#tmparray[@]}-1; i>=0; i-- )); do
      if [ "${tmparray[i]}" != "/" ]; then # don't delete the root dir
        if [ -d ${tmparray[i]} ]; then rmdir -v ${tmparray[i]}; fi
      fi
    done
  fi
else
  echo "no files found with uid and gid $userid:$groupid"
fi
rm -f $tmpfile
