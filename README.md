

VERSIONING & ATTRIBUTION
-
- Script Author:		Terrence Houlahan, Linux & Network Engineer F1Linux.com
- Author Blog:		https://blog.F1Linux.com
- Author Site:		https://www.F1Linux.com

- Script Version:	1.00.01
- Script Date:		20211116

These scripts and others by the author can be found at:

- [https://github.com/f1linux](https://github.com/f1linux)


INTRO
-

These scripts automate- as much as reasonably possible- the grunt work of configuring an **UBUNTU** host to connect to an iSCSI disk on boot and then mount it.

The original use case for writing these scripts was for a HowTo article on configuring a pile of Raspberry Pi's- the 8GB models- to run Docker applications on 64bit Ubuntu. Frequent writes to a Pi's SD card will hammer it, so if we can load a chunk of iSCSI storage for operations requiring frequent writes it's a better situation as iSCSI doesn't write to the local filesystem. 

Creating the required systemd service & systemd mount on a bunch of Pi's manually was just donkey work, so I automated the configuration so folks could get on with the more interesting Docker stuff. Anyhoo, these scripts are generally useful and with a (small) bit of tweaking could be adapted to enterprise use for any version of Linux; knock yourselves out.

The Docker HowTo can be found [HERE](https://blog.F1Linux.com).


What these (2) scripts DO:
-

config-iscsi-storage.sh:
--
Creates a systemd service ***connect-luns.service*** to connect the LUN on boot. It also checks to see that the _open-iscsi_ package is installed as well as checking if the OS is Ubuntu.


config-iscsi-storage-mounts.sh:
--
Creates systemd services ***mnt-logs.mount*** and ***mnt-logs.automount*** to mount the iscsi disk on boot in /mnt - consistent with FHS guidance. The ***automount*** service is additionally configured for the sake of completeness: it's not required as it's is actually for mounting on-demand whereas we just want to mount the external storage on boot.


What these (2) scripts DON'T do:
-

- Partition the conected iSCSI disk
- Format the iSCSI disk with a filesystem

COMPATIBILITY
-

These scripts were developed using **Ubuntu 20.04 LTS** and ***should*** just work out of the box with other versions of Ubuntu and other Debian derivatives.

Where RHEL or Red Hat derivatives are being used, some tweaking with the package management parts of the script will of course require modification.

But the Systemd stuff and anything which is straight bash should "_just work_" be largely distribution independent.

INSTRUCTIONS
-

- **STEP 0**: Create some LUNs on your storage box. Even a cheap Synology SoHo storage appliance can export LUNs.

- **STEP 1**: Execute ***config-iscsi-storage.sh***. Be sure to plug-in values to the few variables prior to executing script.

- **STEP 2**: Partition the iSCSI disk after it connects: ie, `fdisk /dev/sdX` where "X" is the letter of the iSCSI disk

- **STEP 3**: Format the iSCSI disk with a filesystem: ie, `mkfs.ext4 /dev/sdX1` where the iSCSI disk is /dev/sdX

- **STEP 4**: Execute ***config-iscsi-storage-mounts.sh*** last. Again, be sure to plug-in values to the few variables prior to executing script.

- **STEP 5**: Reboot and verify that your iSCSI disk mounted on boot with the `mount` command.



DEPENDENCIES
-
***mnt-logs.mount***: uses the "After=" directive creating a dependency on the ***connect-luns.service***; if the LUN isn't connected, there's nothing to mount! So where the ***connect-luns.service*** fails, then the ***mnt-logs.mount*** service will also be broken.

***mnt-logs.automount***: This service relies on the ***mnt-logs.mount*** service to be correct. If it's not, then the ***mnt-logs.automount*** will of course fail. But the primary use case I wrote the scripts for was to automate bringing the LUN up on boot in our host & mounting it rather than mounting it conditionally when a process needed to write to it.



MANAGING SERVICES
-

To start or check the status of the custom systemd services created by these scripts:

    sudo systemctl [start/status] connect-luns.service

    sudo systemctl [start/status] mnt-logs.mount

    sudo systemctl [start/status] mnt-logs.automount



LICENSE
-

These scripts are licensed under GPL 3.0.