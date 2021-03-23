#!/bin/bash
# when installing lfs:
LFS="/mnt/lfs"
#
# if installing OpenELEC, set $1 to openelec
if [ ! -z $1 ]; then
  if [ "$1" = openelec ]; then
    LFS="/mnt/openelec"
  else
    echo "Don't recognise $1. Will exit."
    exit 1
  fi
fi
rm -rf pkguser.tar.xz
tar -cJf pkguser.tar.xz pkguser
cp pkguser.tar.xz ${LFS}/sources
