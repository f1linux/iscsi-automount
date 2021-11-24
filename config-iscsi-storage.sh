#!/bin/bash

echo
echo "$(tput setaf 5)#######   VERSIONING & ATTRIBUTION   #######$(tput sgr 0)"
echo
echo '# Script Author:	Terrence Houlahan, Linux & Network Engineer F1Linux.com'
echo '# Author Blog:		https://blog.F1Linux.com'
echo '# Author Site:		https://www.F1Linux.com'
echo
echo '# Script Version:	1.00.04'
echo '# Script Date:		20211124'

echo
echo '# These scripts and others by the author can be found at:'
echo
echo '	https://github.com/f1linux'
echo

echo
echo "$(tput setaf 5)#######   LICENSE: GPL Version 3   #######$(tput sgr 0)"
echo "$(tput setaf 5)# Copyright (C) 2021 Terrence Houlahan$(tput sgr 0)"
echo

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, [see](https://www.gnu.org/licenses/)

# Full LICENSE found [HERE](./LICENSE)


#######   INSTRUCTIONS   #######

# STEP 1: Edit "Variables" section below.

# STEP 2: Execute script as 'ubuntu' user:
# 	sudo ./home/ubuntu/config-iscsi-storage.sh

# STEP 3: Partition and format the iSCSI disk after LUN connected.
#	  This is a manual task however not done with any of the scripts.


#######   SET VARIABLES   #######

# Host exposing the LUNs:
STORAGEIP='192.168.1.27'

# Get this value from the storage host exposing the LUN:
IQNTARGET=''


echo
echo "$(tput setaf 5)#######   CHECK OS:   #######$(tput sgr 0)"
echo

if [[ $(lsb_release -d | awk '{print $2}') != 'Ubuntu' ]]; then
	echo 'This script optimized for Ubuntu.'
	echo 'Inconsistent results might be achieved using another Debian derivative,'
	echo 'or if using RHEL or a derivative of it might break in places.'
else
	echo 'NOTE: This script was developed on Ubuntu 20.04 LTS.'
	echo 'Using earlier- or later- versions could produce inconsistent results.'
fi


echo
echo "$(tput setaf 5)#######   INSTALL OPEN-ISCSI   #######$(tput sgr 0)"
echo
if [[ $(dpkg -l | grep "^ii  open-iscsi[[:space:]]") = '' ]]; then
	until apt-get -y install open-iscsi
	do
		echo
		echo "Package $(tput setaf 3)open-iscsi $(tput sgr 0)not found"
		echo
		break
	done
elif [[ $(dpkg -l | grep "^ii  $i[[:space:]]") =  $(dpkg -l | grep "^ii  $i[[:space:]]") ]]; then
	echo "Package open-iscsi already installed"
fi



echo
echo "$(tput setaf 5)#######   CREATE SYSTEMD SERVICE TO CONNECT/DISCONNECT LUN   #######$(tput sgr 0)"
echo

mkdir /root/scripts

echo "$(tput setaf 5)# CREATE CONNECTION SCRIPT: connect-luns.sh$(tput sgr 0)"
echo


cat <<EOF> /root/scripts/connect-luns.sh
#!/bin/bash

# Use of "sendtargets" necessary to wake up the Synology Storage Host:
iscsiadm -m discovery -t sendtargets -p $STORAGEIP

# The iscsiadm command to CONNECT the LUN lives in this file
iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260 --login

if [ $? -eq 0 ]; then
	echo
	echo 'LUN CONNECTED'
	echo
	echo "Output of 'iscsiadm -m session' follows:"
	echo
	iscsiadm -m session
	echo
else
	echo
	echo "Output of 'iscsiadm -m session' follows:"
	echo
	iscsiadm -m session
	echo
	echo 'LUN Already Connected If Below Error Reported:'
	echo 'iscsiadm: default: 1 session requested, but 1 already present'
	echo
	echo 'Any Other Connection Errors:'
	echo "Review CHAP settings in '/etc/iscsi/' and/or Firewall Settings"
	echo

fi

EOF


chmod 700 /root/scripts/connect-luns.sh
chown root:root /root/scripts/connect-luns.sh


echo "$(tput setaf 5)# CREATE DISCONNECTION SCRIPT: disconnect-luns.sh$(tput sgr 0)"
echo

cat <<EOF> /root/scripts/disconnect-luns.sh
#!/bin/bash

# the iscsiadm command to DISCONNECT the LUN lives in this file
iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260, 1 -u

echo "Output of 'iscsiadm -m session' follows:"
echo
iscsiadm -m session
echo

EOF


chmod 700 /root/scripts/disconnect-luns.sh
chown root:root /root/scripts/disconnect-luns.sh



echo "$(tput setaf 5)# CREATE SYSTEMD SERVICE: connect-luns.service$(tput sgr 0)"
echo


cat <<EOF> /etc/systemd/system/connect-luns.service
[Unit]
Description=Connect iSCSI LUN
Documentation=https://github.com/f1linux/iscsi-automount
Requires=network-online.target
#After=

[Service]
User=root
Group=root
Type=oneshot
RemainAfterExit=true
ExecStart=/root/scripts/connect-luns.sh "Connecting LUN"
StandardOutput=journal


[Install]
WantedBy=multi-user.target

EOF


chmod 644 /etc/systemd/system/connect-luns.service

systemctl enable connect-luns.service




echo
echo "$(tput setaf 5)#######   LOCATE iSCSI TARGETS   #######$(tput sgr 0)"
echo
iscsiadm -m discovery -t sendtargets -p $STORAGEIP

echo
echo


echo
echo "$(tput setaf 5)#######   LOCATE ISCSI DISK   #######$(tput sgr 0)"
echo

echo "$(tput setaf 5)# Output of 'fdisk-l'$(tput sgr 0)"
echo
fdisk -l
echo


echo
echo "$(tput setaf 5)#######   NEXT STEPS:   #######$(tput sgr 0)"
echo
echo 'STEP 1: Find the iSCSCI disk in the output above and then partition it,'
echo '	     ie: fdisk /dev/sdX where "X" is the letter of the iSCSI disk'
echo
echo 'STEP 2: Format the iSCSI disk with a filesystem'
echo '	     ie: mkfs.ext4 /dev/sdX1 where the iSCSI disk is /dev/sdX'
echo
echo 'STEP 3: Execute script config-iscsi-storage-mounts.sh to configure auto-mounting the iSCSI disk'
echo '	      to configure mounting the newly formatted iSCSI disks on boot'
echo
