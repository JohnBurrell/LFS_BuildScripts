#!/bin/bash
#
if [ $UID -ne 0 ]; then echo Please run this script as root.; exit 1; fi
# if using systemd-networkd uncomment the following line
#ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
cat > /etc/resolv.conf << "EOF"
# Generated by NetworkManager
# /etc/resolv.conf.head can replace this line
search mynet
nameserver 192.168.1.1
nameserver fe80::1%wlp37s0
# /etc/resolv.conf.tail can replace this line
# End /etc/resolv.conf
EOF
# unhash the next line if using systemd-networkd for network configuration
#ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1   localhost
127.0.1.1   pc

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

# End /etc/hosts
EOF
echo "pc" > /etc/hostname
cat > /etc/locale.conf << "EOF"
# Begin /etc/locale.conf

LANG=en_US.UTF-8
LC_COLLATE=C

# End /etc/locale.conf
EOF
# hardware clock set to local time
cat > /etc/adjtime << "EOF"
0.0 0 0.0
0
LOCAL
EOF
cat > /etc/profile << "EOF"
# Begin /etc/profile
LANG=en_US.UTF-8
# End /etc/profile
EOF
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
# disable screen clearance at boot time
mkdir -pv /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << EOF
[Service]
TTYVTDisallocate=no
EOF
umask 0022
echo "Now run makeFstab.sh to create /etc/fstab"
