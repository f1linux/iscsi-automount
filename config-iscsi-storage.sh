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
# along with this program.  If not, [see](https://www.gnu.org/licenses/)

# Full LICENSE found [HERE](./LICENSE)


#######   INSTRUCTIONS   #######

# NOTE:	This Script MUST be executed *BEFORE* "config-iscsi-storage-mounts.sh" which is
#	used to configure the auto-mounting of the iSCSI disks configured by THIS script!

# If loading multiple LUNs, then change the "IQNTARGET" variable for each LUN and re-execute this script.
# Since Open-iSCSI only allows one CHAP Username & CHAP Password, those variables should not require changing
# for other LUNs you're configuring with this script.

# STEP 1: Edit "Variables" section below.

# STEP 2: Execute script as 'ubuntu' user:
# 	cd /home/ubuntu/
# 	sudo ./config-iscsi-storage.sh

# STEP 3: Partition and format the iSCSI disk after LUN connected.
#	  This is a manual task however not done with any of the scripts.
#	  The Instructions on how to accomplish this are printed at the
#	  completion of this script in 'NEXT STEPS'

#######   SET VARIABLES   #######

# Host exposing the LUNs:
STORAGEIP='192.168.1.27'

# Get this value from the storage host exposing the LUN:
IQNTARGET=''

CHAPUSERNAME='HOST3'
CHAPPASSWORD='CHAPpasswd'

################################


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
                echo "Have you executed this script with sudo?"
		echo
		break
	done
elif [[ $(dpkg -l | grep "^ii  $i[[:space:]]") =  $(dpkg -l | grep "^ii  $i[[:space:]]") ]]; then
	echo "Package open-iscsi already installed"
fi


if [[ $(lsb_release -r | awk '{print $2}' | cut -d '.' -f1)='22' ]]; then

        until apt-get -y install linux-modules-extra-$(uname -r)
        do
                echo
                echo "Package $(tput setaf 3)linux-modules-extra-$(uname -r) $(tput sgr 0)not found"
		echo
		echo "Have you executed this script with sudo?"
                echo
                break
        done

fi


echo
echo "$(tput setaf 5)#######   CONFIG OPEN-ISCSI   #######$(tput sgr 0)"
echo

sed -i 's/#node.session.auth.authmethod = CHAP/node.session.auth.authmethod = CHAP/' /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.username = username/node.session.auth.username = $CHAPUSERNAME/" /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.password = password/node.session.auth.password = $CHAPPASSWORD/" /etc/iscsi/iscsid.conf

systemctl restart iscsid.service
systemctl enable iscsid.service

echo
echo "$(tput setaf 5)#######   CREATE SYSTEMD SERVICE TO CONNECT/DISCONNECT LUN   #######$(tput sgr 0)"
echo

if [ ! -d /root/scripts ]; then

	mkdir /root/scripts

fi

echo "$(tput setaf 5)# CREATE CONNECTION SCRIPT: connect-luns.sh$(tput sgr 0)"
echo

if [ ! -f /root/scripts/connect-luns.sh ]; then 

cat <<EOF> /root/scripts/connect-luns.sh
#!/bin/bash

# Use of "sendtargets" necessary to wake up the Synology Storage Host:
iscsiadm -m discovery -t sendtargets -p $STORAGEIP

# The iscsiadm command to CONNECT the LUN lives in this file
iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260 --login
EOF

chmod 700 /root/scripts/connect-luns.sh
chown root:root /root/scripts/connect-luns.sh


else

	echo "iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260 --login" >> /root/scripts/connect-luns.sh

fi



echo "$(tput setaf 5)# CREATE DISCONNECTION SCRIPT: disconnect-luns.sh$(tput sgr 0)"
echo

if [ ! -f /root/scripts/disconnect-luns.sh ]; then

cat <<EOF> /root/scripts/disconnect-luns.sh
#!/bin/bash

# The iscsiadm command to DISCONNECT the LUN lives in this file
iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260, 1 -u
EOF

chmod 700 /root/scripts/disconnect-luns.sh
chown root:root /root/scripts/disconnect-luns.sh

else

	echo "iscsiadm -m node -T $IQNTARGET -p $STORAGEIP:3260, 1 -u" >> /root/scripts/disconnect-luns.sh

fi


echo "$(tput setaf 5)# CREATE SYSTEMD SERVICE: connect-luns.service$(tput sgr 0)"
echo

if [ ! -f /etc/systemd/system/connect-luns.service ]; then

cat <<EOF> /etc/systemd/system/connect-luns.service
[Unit]
Description=Connect iSCSI LUN
Documentation=https://github.com/f1linux/iscsi-automount
Requires=network-online.target
#After=
DefaultDependencies=no

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

systemctl daemon-reload

systemctl enable connect-luns.service
systemctl start connect-luns.service

fi


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
echo 'STEP 1: sudo systemctl reboot'
echo
echo 'STEP 2: Check the LUNs are connect to this host:'
echo
echo '        iscsiadm -m session'
echo
echo 'STEP 3: Find the iSCSCI disk in the output above and then partition it,'
echo '	     ie: fdisk /dev/sdX where "X" is the letter of the iSCSI disk'
echo
echo 'If iSCSI block device not present in output of fdisk -l then skip to  *TROUBLESHOOTING* section below'
echo 'Otherwise then proceed to STEP 2'
echo
echo 'STEP 4: Partition each new LUN'
echo '        sudo fdisk /dev/sdX'
echo '            (n) Create new partition'
echo '            (p) Choose Primary partition'
echo '            Accept all remaining default values'
echo '            (w) Write to save changes and exit'
echo '            Note: Default partition type is Linux- no need to set the value'
echo
echo 'STEP 5: Format the iSCSI disk with a filesystem'
echo '	     ie: mkfs.ext4 /dev/sdX1 where the iSCSI disk is /dev/sdX'
echo '       Pls note that there is a "1" appended to the block device /dev/sdX1'
echo
echo 'STEP 6: Execute script config-iscsi-storage-mounts.sh which configures the'
echo '	      auto-mounting the newly formatted iSCSI disks on boot'
echo

echo
echo "$(tput setaf 5)#######   TROUBLESHOOTING:   #######$(tput sgr 0)"
echo

echo
echo 'If you do NOT see the expected iSCSI block device check to see if the LUN is connected:'
echo
echo 'Output of * iscsiadm -m session * command below'
echo

iscsiadm -m session

echo
echo 'If no output above or the LUN is missing then the block device is not connected to system'
echo

echo
echo 'Review output of * systemctl status connect-luns.service * below for errors'
echo

systemctl status connect-luns.service

echo
echo 'If Error * iscsiadm: initiator reported error (24 - iSCSI login failed due to authorization failure) * then:'
echo 
echo 'STEP 1: Clear Open-iSCSI cached login credentials:'
echo
echo '     sudo rm -rf /etc/iscsi/nodes'
echo '     sudo rm -rf /etc/iscsi/send_targets'
echo
echo 'STEP 2: Verify the CHAP username and Password in storage device match Open-iSCSI credentials in:'
echo
echo '     /etc/iscsi/iscsid.conf'
echo '     /etc/iscsi/initiatorname.iscsi'
echo
echo 'STEP 3: Fix any errors and execute:'
echo
echo '     sudo systemctl restart iscsid.service'
echo '     sudo systemctl restart connect-luns.service'
echo '     sudo iscsiadm -m session'
echo
echo 'STEP 4: If your LUN is now present then execute:'
echo
echo '     sudo fdisk -l'
echo
echo 'Find your iSCSI block device and complete STEPS 1-3 in the * NEXT STEPS * section above this troubleshooting section'
echo
