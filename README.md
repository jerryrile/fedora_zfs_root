# Installing Fedora with a ZFS root from Live USB

### Data Loss Warning !!!

### Potential Data loss Warning: This script will delete any existing partition structure on a physical or virtual disks and create a new partitions in its place. If you are dual booting another operating in your system from another physical/virtual drive and wish to retain it. It is Highly recommended that you first remove the other Operating System Hard Drive/SSD/NVME from your system first before executing this script. Other wise this script will assume you wish to create a mirror and Will!! partition the other drives! Accordingly Please make sure your important data is backed-up to an external storage device (such as a CD, DVD, or external USB hard drive) before attempting to run this procedure on your system.


### USB Image Build
- Prerequisites 
	- git
	- 2: Download a variant of Fedora live image and boot from it.
	    - Fedora Workstation (GNOME)
    	- Fedora Spins (Xfce, i3, …)
	- USB Stick or USb Drive (I went with a USB drive as it faster)
	- A VM you can pass through a USB Device to VMware, VirtualBox, KVM, HyperV should all work (I used KVM)

### USB Stick / Disk creation
- create a VM using your prefered hypervisor and attach the Instalation ISO and Passing through the your USB Stick or Drive. 
- Install Fedora to your USB device as you would normaly to a local disk
- Once you have Fedora successfully installed to your USB Stick/Drive shut the VM down and Detach the ISO
- Then adjust the boot order of the VM so that the next time you start up the VM your booting from the newly created USB Drive/Stick

### Fedora USB Image customization
 
- Once the VM has been booted off of the USB Dirve/Stick you can continue to customize the image.

- 1: Set root password or /root/.ssh/authorized_keys.
~~~
[liveuser@localhost-live ~]$ sudo passwd root
Changing password for user root.
New password: 
Retype new password: 
passwd: all authentication tokens updated successfully.
[user@localhost-live ~]$ 
~~~

- 2: Update your SSH configuration to allow root to login remotely
~~~
[user@localhost-live ~]$ sudo vi /etc/ssh/sshd_config

truncated
...

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
PermitRootLogin yes
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

...
truncated
~~~

- 3: Start the SSH service:
~~~
[user@localhost-live ~]$ sudo systemctl enable --now sshd
[sudo] password for user: 

Created symlink /etc/systemd/system/multi-user.target.wants/sshd.service → /usr/lib/systemd/system/sshd.service.
~~~

- 4: Stop and disable Firewalld
~~~
[user@localhost-live ~]$ sudo systemctl stop firewalld

user@localhost-live ~]$ sudo systemctl disable firewalld
Removed /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.
Removed /etc/systemd/system/multi-user.target.wants/firewalld.service.
~~~

- 5: Connect from another computer to contiue the live USB drive customization
~~~
ssh root@192.168.122.174
~~~~

6. Set SELinux to permissive in live environment:
~~~
[liveuser@localhost-live ~]$ sudo vi /etc/selinux/config
~~~
	
- change SELINUX=enforcing to SELINUX=permissive then write and quite the file.
~~~
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
# See also:
# https://docs.fedoraproject.org/en-US/quick-docs/getting-started-with-selinux/#getting-started-with-selinux-selinux-states-and-modes
#
# NOTE: In earlier Fedora kernel builds, SELINUX=disabled would also
# fully disable SELinux during boot. If you need a system with SELinux
# fully disabled instead of SELinux running with no policy loaded, you
# need to pass selinux=0 to the kernel command line. You can use grubby
# to persistently set the bootloader to boot with selinux=0:
#
#    grubby --update-kernel ALL --args selinux=0
#
# To revert back to SELinux enabled:
#
#    grubby --update-kernel ALL --remove-args selinux
#
SELINUX=permissive
# SELINUXTYPE= can take one of these three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
~~~

then selinux can be put in to Permissive mode by runing the following command. Or alternatily you can reboot.
~~~
[root@localhost-live ~]# setenforce 0

[root@localhost-live ~]# getenforce
Permissive
~~~

- Note: SELinux will be enabled on the installed system.

#### Intrestingly Fedora 36 now ships with ZFS-Fuse install by default but disabled. We will not be using it for the installation as the ZFS verion it's based on does not support all the perameters we require.

- 7: remove zfs-fuse ( this will remove fair amount of packages including Boxes and Libvirt which is not required )
~~~
yum remove zfs-fuse-0.7.2.2-21.fc36.x86_64 zfs-release-1-5.fc36.noarch
~~~

- 8: Add ZFS repo:
~~~
[root@localhost-live ~]# dnf install -y https://zfsonlinux.org/fedora/zfs-release.fc36.noarch.rpm
~~~

- 9: Install ZFS and kernel development packages:
~~~
[root@localhost-live ~]# dnf install -y zfs kernel-devel-matched.x86_64
~~~

- 10: Load kernel modules:
~~~
[root@localhost-live ~]# modprobe zfs
~~~

- 11: Install helper script and partition tool:
~~~
dnf install -y arch-install-scripts gdisk dosfstools git
~~~

- 12: Change directorys to /root and use git to clone the fedora_zfs_root repository
~~~
[root@localhost-live ~]# cd /root
~~~

~~~
git clone 
~~~

- 13: Change into the fedora_zfs_root directory and excute the fefora_install_zfs_root script to begin the installation.
~~~
[root@localhost-live ~]# cd fedora_zfs_root/

[root@localhost-live fedora_zfs_root]# ls -l
total 68
-rwxr-xr-x. 1 root root  8791 May 19 00:32 fedora_install_zfs_root.sh
-rw-r--r--. 1 root root 34667 May 19 00:32 LICENSE
-rw-r--r--. 1 root root 11271 May 19 00:32 README.md
-rwxr-xr-x. 1 root root  6389 May 19 00:32 stage2_chroot.sh
~~~

~~~
[root@localhost-live fedora_zfs_root]# ./fedora_install_zfs_root.sh
~~~
~~~
[root@fedora fedora_zfs_root]# ./fedora_install_zfs_root.sh 
Enter the hostname :luna4

[root@fedora fedora_zfs_root]# ./fedora_install_zfs_root.sh 
Enter the hostname :luna4
Please entering your username: user

===========================================
|| Do you wish to Encrypt the root pool! ||
===========================================
1) Yes
2) No
#? 1

./fedora_install_zfs_root.sh: line 50: Enter: command not found

================================================
|| Does this system use an UEFI or Legacy BIOS||
================================================
1) Yes
2) No
#? 2

=========================================================
|| If using legacy booting, install GRUB to every disk ||
=========================================================


===============================
|| Setting the root password ||
===============================
Changing password for user root.
New password: 
Retype new password: 

===================================
|| Setting User Account Password ||
===================================
Changing password for user user.
New password: 
Retype new password:

===============================
|| Setting the root password ||
===============================
Changing password for user root.
New password: 
Retype new password: 
passwd: all authentication tokens updated successfully.
~~~
