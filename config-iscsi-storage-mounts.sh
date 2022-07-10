#!/bin/bash

echo
echo "$(tput setaf 5)#######   VERSIONING & ATTRIBUTION   #######$(tput sgr 0)"
echo
echo '# Script Author:	Terrence Houlahan, Linux & Network Engineer F1Linux.com'
echo '# Author Site:		http://www.F1Linux.com'
echo
echo '# Script Version:	1.11.00'
echo '# Script Date:		20220710'

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
# along with this program. If not, [see](https://www.gnu.org/licenses/)

# Full LICENSE found [HERE](./LICENSE)


#######   INSTRUCTIONS   #######

# If auto-mounting multiple LUNs, then change- at a minimum- the "ISCSIDEVICE" variable for each LUN and re-execute this script.

# This script mounts an already formatted iSCSI LUN to a folder in the path '/mnt/' per FHS guidance
# with an arbitrary name which is specified in a variable.

# STEP 1:	First execute './config-iscsi-storage.sh' to connect the formatted iSCSI block device to the host.

# STEP 2:	Modify variables in "SET VARIABLES" section below

# STEP 3:	Execute this script as the 'ubuntu' user:
#			sudo ./config-iscsi-storage-mounts.sh


#######   SET VARIABLES   #######

# Default value 'sda1' works if you load a single LUN on a Raspberry Pi partitioned by accepting fdisk default options.
# The first LUN appears in 'fdisk -l' as DISK 'sda' and 2nd LUN as DISK 'sdb' on your Pi.
# If you chose default values when partitioning the iSCSI * DISK * then 'fdisk -l' shows
# * DEVICES * '/dev/sda1' for LUN1 and '/dev/sdb1' for LUN2.
# Do 'fdisk -l' if unsure how the device is specified

ISCSIDEVICE='sda1'

# The script will create the folder with the name supplied in "ISCSIDISKMOUNTFOLDER" variable
# in the path /mnt. Therefore do NOT manually create the folder the LUN is mounted to.
#
# NAMING REQUIREMENTS: Do NOT specify a folder name with a hypnen in folder name that the LUN will be mounted on.
#         This will cause the SystemD mount to fail.
#         ie: "logsproxy" is a valid name and WILL work but "logs-proxy" will NOT and cause the mount to fail.
#
ISCSIDISKMOUNTFOLDER='logs'

# Filesystem type the LUN was formatted for which is supplied in the 'Type' field below
FILESYSTEM='ext4'

# SystemD mount file comment:
# Below variable sets "Description" field in the file that starts the mount.
MOUNTDESCRIPTION='Persistent Data living on iSCSI LUN'

#######   EDIT BELOW WITH CAUTION   #######

## NOTE: Most settings below show work out of the box


echo "$(tput setaf 5)#######   CHECK IF LUN CONNECTED   #######$(tput sgr 0)"
echo

echo "$# Check if a LUN is connected and if not exit the script with a notification to connect it first:$(tput sgr 0)"
echo
# NOTE: 'iscsiadm' directs output to stderr so we need to redirect to stdout '2>&1' or our test will fail
if [[ $(iscsiadm -m session 2>&1) = 'iscsiadm: No active sessions.' ]]; then
	echo
	echo 'No LUNs connected.'
	echo 'Execute "config-iscsi-storage.sh" script '
	echo 'Script exiting'
	exit
else
	echo 'Connected LUN found: Script will continue'
	echo
fi



echo "$(tput setaf 5)#######   CREATE SYSTEMD MOUNT FOR LUN   #######$(tput sgr 0)"
echo

echo "$(tput setaf 5)# Create directory /mnt/$ISCSIDISKMOUNTFOLDER for the iSCSI device to mount to$(tput sgr 0)"

if [ ! -d /mnt/$ISCSIDISKMOUNTFOLDER ]; then

	mkdir /mnt/$ISCSIDISKMOUNTFOLDER
	chmod 770 /mnt/$ISCSIDISKMOUNTFOLDER

fi

echo "$(tput setaf 5)# Create mnt-$ISCSIDISKMOUNTFOLDER.mount$(tput sgr 0)"
echo

if [ ! -f /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.mount ]; then

cat <<EOF> /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.mount
[Unit]
Description=$MOUNTDESCRIPTION
After=connect-luns.service
DefaultDependencies=no

[Mount]
What=/dev/disk/by-uuid/$(ls -al /dev/disk/by-uuid | grep $ISCSIDEVICE | awk '{print $9}')
Where=/mnt/$ISCSIDISKMOUNTFOLDER
Type=$FILESYSTEM
StandardOutput=journal

[Install]
WantedBy=multi-user.target

EOF

chown root:root /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.mount
chmod 644 /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.mount

systemctl daemon-reload
systemctl enable mnt-$ISCSIDISKMOUNTFOLDER.mount
sudo systemctl start mnt-$ISCSIDISKMOUNTFOLDER.mount

else

	echo "'/etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.mount' already exists"

fi



echo "$(tput setaf 5)# Create mnt-$ISCSIDISKMOUNTFOLDER.automount$(tput sgr 0)"
echo

if [ ! -f /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.automount ]; then

cat <<EOF> /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.automount
[Unit]
Description=$MOUNTDESCRIPTION
Requires=network-online.target
#After=

[Automount]
Where=/mnt/$ISCSIDISKMOUNTFOLDER

[Install]
WantedBy=multi-user.target

EOF

chown root:root /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.automount
chmod 644 /etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.automount

else

	echo "'/etc/systemd/system/mnt-$ISCSIDISKMOUNTFOLDER.automount' already exists"

fi



echo
echo "$(tput setaf 5)#######   NEXT STEPS:   #######$(tput sgr 0)"
echo
echo 'Reboot and verify that the iscsi disk automatically mounted on boot using the "mount" command'
echo
