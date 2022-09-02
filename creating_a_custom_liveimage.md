# Installing Fedora with a ZFS root from Live USB

### USB Image Build
- Requirements 
	- git
	- Existing Fedora Install
	- livecd-tools
	- USB Stick
	- latest Fedora ISO

### Fedora USB Stick creation. 
#### Note: An assumption has been made here that you will be running this process from an installed Fedora base image. In my case I chose to install Fedora first into a VM using KVM then passed though the USB stick to the VM, though this process will also work from an already installed desktop or laptop. 
- Install livecd-tools
~~~
dnf install livecd-tools
~~~

- Download the latest [Fedora live](https://getfedora.org/en/workstation/download/) image. Change to the directory where you downloaded the Fedora Live ISO to and execute the following command to Create a live USB. 
~~~
sudo livecd-iso-to-disk --format --reset-mbr --overlay-size-mb 2048 Fedora-Cinnamon-Live-x86_64-35-1.2.iso /dev/sdb
~~~

- Since my USB Stick already had data on it I added the ``` --format ``` flag to the command to wipe the USB Stick before copying the Fedora Live DVD image to it. During the copy  process a 2GB overlay filesystem was created. The overlay filesystem is a read write partition were all modifications made to the Live USB Stick will installed to and will persist over reboots.

### Fedora Live USB Image customization
- Once the USB stick has successfully been created, boot into it. In this case I'm using KVM with Pass though USB device. However a laptop or desktop will also work.  

- To validate that changes made to the custom Live USB stick will persist over reboots. Make a simple change like creating a file on the desktop or changing the desktop background then rebooting. Once the system comes back up it should have retained the changes you made before rebooting.

### Adding Additional repositories 
1. Upon rebooting the VM or physical machine make sure to disable Secure Boot, ZFS modules can not be loaded if Secure Boot is enabled.

2. Set root password or /root/.ssh/authorized_keys.
~~~
[liveuser@localhost-live ~]$ sudo passwd root
Changing password for user root.
New password: 
Retype new password: 
passwd: all authentication tokens updated successfully.
[liveuser@localhost-live ~]$ 
~~~

3. Start and enable the SSH server:
~~~
[liveuser@localhost-live ~]$ sudo systemctl enable --now sshd

We trust you have received the usual lecture from the local System
Administrator. It usually boils down to these three things:

    #1) Respect the privacy of others.
    #2) Think before you type.
    #3) With great power comes great responsibility.

Created symlink /etc/systemd/system/multi-user.target.wants/sshd.service → /usr/lib/systemd/system/sshd.service.
[liveuser@localhost-live ~]$
~~~

4. Connect from another computer:
~~~
ssh root@192.168.122.19
~~~~

5. Set SELinux to permissive in live environment:
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

#### Note: SELinux will be enabled on the installed system.

6. During my testing I was unable to build the kernel module for the Live image 5.14 kernel. So to solve this I installed the 5.15 LTS kernel from the copr repos.

~~~
sudo dnf copr enable kwizart/kernel-longterm-5.15
sudo dnf install kernel-longterm kernel-longterm-devel
~~~

7. Update Grub to ensure that your booting from the LTS kernel reboot the live image and boot into the LTS kernel
~~~
liveuser@localhost-live ~]$ sudo dnf install grubby
~~~


	8. Run following commands to find and select the default boot kernel.
~~~
[liveuser@localhost-live ~]$ sudo grubby --info=ALL

truncated
... 
index=2
kernel="/boot/vmlinuz-5.15.32-200.fc35.x86_64"
args="rd.live.image rw rd.live.overlay=UUID=b3729456-6894-4c30-9b70-e31c6fa99da0 quiet rhgb"
root="live:UUID=b3729456-6894-4c30-9b70-e31c6fa99da0"
initrd="/boot/initramfs-5.15.32-200.fc35.x86_64.img"
title="Fedora Linux (5.15.32-200.fc35.x86_64) 35 (Cinnamon)"
id="d025b08b44de489e9e59d2b56c9db6fa-5.15.32-200.fc35.x86_64"
... 
truncated
~~~


~~~
liveuser@localhost-live ~]$ sudo grubby --set-default /boot/vmlinuz-5.15.32-200.fc35.x86_64
The default is /boot/loader/entries/d025b08b44de489e9e59d2b56c9db6fa-5.15.32-200.fc35.x86_64.conf with index 2 and kernel /boot/vmlinuz-5.15.32-200.fc35.x86_64
~~~

9. Reboot the custom live image.

10. Add ZFS repo:
~~~
dnf install -y https://zfsonlinux.org/fedora/zfs-release.fc${VERSION_ID}.noarch.rpm
~~~

11. Install ZFS packages:
~~~
dnf install -y zfs
~~~

12. Load kernel modules:
~~~
modprobe zfs
~~~

13. Install helper scripts and partitioning tools, that the fedora_zfs_root scripts will use.
~~~
dnf install -y git arch-install-scripts gdisk dosfstools
~~~

14. The final step will be to add the add the fedora_zfs_root installation script to the custom Live image.
~~~
git clone https://github.com/jerryrile/fedora_zfs_root.git
~~~
   
### Congratulations you've just created a custom installation USB stick with ZFS kernel modules loaded, that can be used to install Fedora with a bootable ZFS filesystem. For further installation instructions please see [README.md](https://github.com/jerryrile/fedora_zfs_root/blob/main/README.md)