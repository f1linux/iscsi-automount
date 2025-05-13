#!/bin/bash

echo
echo "$(tput setaf 5)#######   VERSIONING & ATTRIBUTION   #######$(tput sgr 0)"
echo
echo '# Script Author:  Terrence Houlahan, Linux & Network Engineer F1Linux.com'
echo '# Author Site:            http://www.F1Linux.com'
echo
echo '# Script Version: 1.12.00'
echo '# Script Date:            20250513'
echo
echo '# Compatibility: Tested and known to be correct with Ubuntu 24.04 LTS'

echo
echo '# These scripts and others by the author can be found at:'
echo
echo '  https://github.com/f1linux'
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

#######       INTRO      ####### 

# This script assists you in moving verbose logging onto external storage.
# My use case is running dockerized apps on Raspberry Pis and these use SD cards.
# Docker-Compose ignores the logging directives and will write everything to syslog.
# Not only will verbose logging fill the root filesystem on my Pi impairing the container(s) running on it
# but all the excessive writes will trash the SD card and depending on where Pi is located this may be a huge prob.

#######   INSTRUCTIONS   #######

# This script can be used as an adjunct to the other (2) scripts which config & mount an iSCSI LUN.
# It is a fairly straightforward and readable script.

# Create and mount a chunk of iSCSI storage using the other 2 scripts before executing this one.
# Then specify the folder that the chunk of iSCSI storage is mounted in the "SET VARIABLES" section and execute it.

# NOTE TO NON-UBUNTU USERS:
# -------------------------
# This script is tailored to Ubuntu and tested and proven to be correct with 22.04.
# It has various customizations which are probably specific to Ubuntu- ie modifying AppArmor.
# If using a distro other than Ubuntu please review & tweak accordingly before executing.


######    SET VARIABLES  #######

# ** PLEASE READ: **
# This script implies that the iscsi disk is mount in the path:
#    /mnt/$ISCSILOGFOLDER
# If the root of the path is NOT "/mnt" you need to tweak the paths in the script below

ISCSILOGFOLDER='syslog'


# Exit if variable "ISCSILOGFOLDER" is unset
if [ -z "${ISCSILOGFOLDER-}" ]; then
   echo 'Please set "ISCSILOGFOLDER" variable and re-execute script. Exiting....'
   exit 1
fi


# Exit if script not executed with sudo
if [ `id -u` -ne 0 ]; then
  echo
  echo "Re-execute script as root or using sudo!"
  echo
  exit
fi


# Ubuntu defaults to rsyslog- might need to be tweaked if using a different distro
systemctl stop syslog.socket rsyslog.service

# NOT optional: /var/log dir MUST be moved out of path we are symlinking or it will hose everything:
mv /var/log /var/log.OLD

# LEAVE THIS CHECK IF MODIFYING SCRIPT: It will stop you from cutting your head off making a duff tweak.
if [[ -d "/var/log" ]]; then
	echo
	echo 'Dir "/var/log" present: please mv to /var/log.OLD'
	echo 'Exiting- please re-execute after clearing error'
	echo
	exit
fi

# Symlink the iscsi mounted storage- here mounted in a folder named "syslog"- to /var/log 
ln -s /mnt/$ISCSILOGFOLDER/ /var/log

# Copy all logs to new LUN storage where logs will now be written and managed
cp -rp /var/log.OLD/* /var/log/

# Free space  that syslog was using on local storage after copying to LUN
truncate -s 0 /var/log.OLD/syslog

# Apparmor breaks logging outside of /var/log so we add an exception:
sed -i "/\/var\/log\//a\  /mnt\/$ISCSILOGFOLDER\/\*\*                rw," /etc/apparmor.d/usr.sbin.rsyslogd

systemctl daemon-reload
systemctl start syslog.socket rsyslog.service


# "ProtectSystem=full" restricts writing to logs outside of expected path /var/log.
# For "ReadWritePaths=" only specify a single path. If further exceptions required
# then add further entries for "ReadWritePaths". 

bash -c "echo "ReadWritePaths=/mnt/$ISCSILOGFOLDER/" >> /lib/systemd/system/logrotate.service"
systemctl daemon-reload
systemctl restart logrotate.service
