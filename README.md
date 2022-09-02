# Installing Fedora with a ZFS root from Live USB

#### Have you ever wanted to run Fedora Linux with a Cinnamon Desktop and a bootable ZFS root disk but did not know how or where to begin. Fortunately the OpenZFS team has put together some great documentation on how to do this. 

#### To help automate and speed up the installation process I’ve put together two scripts based on their documentation.

#### In The first script fedora_install_zfs_root.sh, partitions your disks, creates the ZFS volumes and installs the Fedora Linux BaseOS packages.

#### The second script stage2.sh is the called from within a CHROOTED environment, Compiles the kernel modules and finalizes the installation of the system including the installation of the Grub2 bootloader, Desktop Environment and Application such as Firefox, Chrome, LibreOffice, Visualstuido Code and more.

#### Before proceeding: Please review the documentation on [Creating a Custom Live image](https://github.com/jerryrile/fedora_zfs_root/blob/main/creating_a_custom_liveimage.md). This custom Live image will be used to install the system. 

#### fedora_install_zfs_root.sh: 
- Prompts you to chose a Hostname and User ID
- Creates new partitions on the detected disk(s) 
- Configures two new zpools on the Disk(s) BPOOL and RPOOL. BPOOL stores the boot files and RPOOL stores the rest of the system data.
- If you only have one disk it will create a ZFS Stripe and if you have two or more it will create a ZFS Mirror.
- Once the zpool creation is completed you will be prompted if you wish to encrypt the RPOOL ZFS volume, IF you select yes you will need to enter in an encryption password (Note: This password must be at least 8 character long or the encryption process will fail)
- The script will then create the required ZFS datasets for the system, where <userName>  is the User ID the you input at the beginning of the script when you first executed it.
```	
	bpool/sys
	bpool/sys/BOOT
	bpool/sys/BOOT/default
	
	rpool/sys
	rpool/sys/DATA
	rpool/sys/DATA/default
	rpool/sys/DATA/default/home
	rpool/sys/DATA/default/home/<userName> 
	rpool/sys/DATA/default/root
	rpool/sys/DATA/default/srv
	rpool/sys/DATA/default/usr 
	rpool/sys/DATA/default/usr/local
	rpool/sys/DATA/default/var
	rpool/sys/DATA/default/var/lib
	rpool/sys/DATA/default/var/log
	rpool/sys/DATA/default/var/spool  
```
- The script will then mount the new zfs volumes then begin the process of the installing the BasOS packages on to the newly created zpools (BPOOL, RPOOL)

#### stage2.sh
- Once the system has completed installing the BaseOS it will then instantiate a CHROOT environment and copy the stage2.sh script to it and launch the script.
- The stage2 script will continue the installation process by Compiling the OpenZFS kernel module and loading it in to the initramfs
- Installing grub2 to the boot disk and BPOOL ZFS volume. 
- Installing any remaining package groups. Such as the Desktop Environment and applications sets such as Firefox, Chrome, LibreOffice, and Visualstuido Code.
- Once completed the system will exit the CHROOT environment and shutdown the system. At this point the installation medium can be removed and you can boot into your newly created bootable ZFS root Fedora Linux system.

#### PLEASE NOTE !!!

#### Potential Data loss Warning: These scripts will delete any existing partition structure on a physical or virtual disks and create a new partitions in its place. If you are dual booting another operating in your system from another physical/virtual drive and wish to retain it. It is Highly recommended that you first remove the other Operating System Hard Drive/SSD/NVME from your system first before executing this script. Other wise this script will assume you wish to create a mirror and Will!! partition the other drives! Accordingly Please make sure your important data is backed-up to an external storage device (such as a CD, DVD, or external USB hard drive) before attempting to run this procedure on your system.

