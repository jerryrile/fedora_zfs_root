#!/bin/bash
 
# Tile: Install ZFS Root. this is the Stage 2 script that is ment to be
# executed from within the CHROOT environment
# Copyright (C) 2022  Jerry Riley
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# source the variable script
source /root/chroot

#Functions

#If using legacy booting, install GRUB to every disk:
bios ()
    {
    
    awk 'BEGIN { printf "=========================================================\n|| If using legacy booting, install GRUB to every disk ||\n=========================================================\n" }'

    for i in ${DISK}; do
      grub2-install --boot-directory /boot/efi/EFI/fedora --target=i386-pc $i
    done

    cp -r /usr/lib/grub/i386-pc/ /boot/efi/EFI/fedora
    }

 #If your using EFI bios:
uefi ()
    {
    for i in ${DISK}; do
      efibootmgr -cgp 1 -l "\EFI\fedora\shimx64.efi" -L "fedora-${i##*/}" -d ${i}
    done
     
    cp -r /usr/lib/grub/x86_64-efi/ /boot/efi/EFI/fedora
    }

dnf makecache

df -h

sleep 10

#For SELinux, relabel filesystem on next boot
fixfiles -F onboot

echo "Build ZFS modules"

for directory in /lib/modules/*; do
  kernel_version=$(basename $directory)
  dkms autoinstall -k $kernel_version
done

#GRUB Notes:
# grub2-probe fails to get canonical path
# When persistent device names /dev/disk/by-id/* are used with ZFS, GRUB will fail to resolve the path of the boot pool device. 

echo 'export ZPOOL_VDEV_NAME_PATH=YES' >>/etc/profile.d/zpool_vdev_name_path.sh
source /etc/profile.d/zpool_vdev_name_path.sh

#Pool name missing Notes:
#See this bug report (https://savannah.gnu.org/bugs/?59614). Root pool name is missing from root=ZFS=rpool_$INST_UUID/ROOT/default kernel cmdline in generated grub.cfg file.
##A workaround is to replace the pool name detection with zdb command:

sed -i "s|rpool=.*|rpool=\`zdb -l \${GRUB_DEVICE} \| grep -E '[[:blank:]]name' \| cut -d\\\' -f 2\`|" /etc/grub.d/10_linux


##Install Grub
#If using virtio disk, add driver to initrd:
echo 'filesystems+=" virtio_blk "' >>/etc/dracut.conf.d/fs.conf

#Generate initrd
rm -f /etc/zfs/zpool.cache
touch /etc/zfs/zpool.cache
chmod a-w /etc/zfs/zpool.cache
chattr +i /etc/zfs/zpool.cache
for directory in /lib/modules/*; do
  kernel_version=$(basename $directory)
  dracut --force --kver $kernel_version
done

#Disable BLS
echo "GRUB_ENABLE_BLSCFG=false" >>/etc/default/grub

#Create GRUB boot directory, in ESP and boot pool:
mkdir -p /boot/efi/EFI/fedora       # EFI GRUB dir
mkdir -p /boot/efi/EFI/fedora/grub2 # legacy GRUB dir
mkdir -p /boot/grub2

#Boot environment-specific configuration (kernel, etc) is stored in /boot/grub2/grub.cfg, enabling rollback.
#When in doubt, install both legacy boot and EFI.

# determine if yor using UEFI or Legacy BIOS

 awk 'BEGIN { printf "================================================\n|| Does this system use an UEFI or Legacy BIOS||\n================================================\n" }'

select yn in "Yes" "No"; do
    case $yn in
        Yes ) uefi; break;;
        No ) bios; break;;
    esac
done

#cp -r /usr/lib/grub/x86_64-efi/ /boot/efi/EFI/fedora

#Generate GRUB Menu:

grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
cp /boot/efi/EFI/fedora/grub.cfg /boot/efi/EFI/fedora/grub2/grub.cfg
cp /boot/efi/EFI/fedora/grub.cfg /boot/grub2/grub.cfg

#For both legacy and EFI booting: mirror ESP content:
ESP_MIRROR=$(mktemp -d)
unalias -a
cp -r /boot/efi/EFI $ESP_MIRROR
for i in /boot/efis/*; do
  cp -r $ESP_MIRROR/EFI $i
done

#Automatically regenerate GRUB menu on kernel update
tee /etc/dnf/plugins/post-transaction-actions.d/00-update-grub-menu-for-kernel.action <<EOF >/dev/null
# kernel-core package contains vmlinuz and initramfs
# change package name if non-standard kernel is used
kernel-core:in:/usr/local/sbin/update-grub-menu.sh
kernel-core:out:/usr/local/sbin/update-grub-menu.sh
EOF

tee /usr/local/sbin/update-grub-menu.sh <<-'EOF' >/dev/null
#!/bin/sh
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export ZPOOL_VDEV_NAME_PATH=YES
source /etc/os-release
grub2-mkconfig -o /boot/efi/EFI/${ID}/grub.cfg
cp /boot/efi/EFI/${ID}/grub.cfg /boot/efi/EFI/${ID}/grub2/grub.cfg
cp /boot/efi/EFI/${ID}/grub.cfg /boot/grub2/grub.cfg
ESP_MIRROR=$(mktemp -d)
cp -r /boot/efi/EFI $ESP_MIRROR
for i in /boot/efis/*; do
 cp -r $ESP_MIRROR/EFI $i
done
rm -rf $ESP_MIRROR
EOF

chmod +x /usr/local/sbin/update-grub-menu.sh

awk 'BEGIN { printf "===============================\n|| Setting the root password ||\n===============================\n" }'

passwd root

# update entry in fstab
sed -i "s|/home/User|/home/${myUser}|g" /etc/fstab

# add user
useradd --no-create-home --user-group --home-dir /home/${myUser} --comment "${myUser}" ${myUser}

# delegate snapshot and destroy permissions of the home dataset to
# new user
zfs allow -u ${myUser} mount,snapshot,destroy $(df --output=source /home | tail -n +2)/${myUser}

# fix permissions
chown --recursive ${myUser}:${myUser} /home/${myUser}
chmod 700 /home/${myUser}

# fix selinux context
restorecon /home/${myUser}

# set new password for user
awk 'BEGIN { printf "\n\n\n===================================\n|| Setting User Account Password ||\n===================================\n" }'
passwd ${myUser}

#Set up cron job to snapshot user home everyday

#systemctl enable --now crond
#crontab -eu ${myUser}
##@daily /usr/sbin/zfs snap $(df --output=source /home/${myUser} | tail -n +2)@$(dd if=/dev/urandom of=/dev/stdout bs=1 count=100 2>/dev/null |tr -dc 'a-z0-9' | cut -c-6)
#0 12 * * * /usr/sbin/zfs snap $(df --output=source /home/${myUser} | tail -n +2)@$(date +%F_%H:%M:%S)
#zfs list -t snapshot -S creation $(df --output=source /home/${myUser} | tail -n +2)

# Install Desktop
dnf group install -y 'Cinnamon Desktop'
dnf install -y libreoffice.x86_64 apostrophe.noarch gnome-software.x86_64 elementary-wallpapers.noarch
dnf install -y fedora-workstation-repositories
dnf config-manager --set-enabled google-chrome
dnf install -y google-chrome-stable

dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install -y vlc podman.x86_64 gnome-boxes.x86_64

rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf install -y code

# Exit CHROOT
exit
