#/!bin/bash

# Tile: Install ZFS Root. This script will install Fedora using a ZFS root filesystem
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


INST_FEDORA_VER='38'
INST_ID=sys
INST_VDEV=
#----Partitioning---------
INST_PARTSIZE_ESP=2
INST_PARTSIZE_BPOOL=4
INST_PARTSIZE_SWAP=8
INST_PARTSIZE_RPOOL=
FINDBBLK=`lsblk -l |grep boot |awk '{print $1}' |cut -c 1-3`
IGNOREBLK=`ls -l /dev/disk/by-id/ |grep $FINDBBLK|egrep -v 'ata|part' |awk '{print $9}'`
DISK_NUM=`lsblk | grep disk |egrep -v 'zram|sda' |wc -l`
BYPATH=`ls /dev/disk/by-path |grep virtio-pci| grep -v part`
BYID=`ls /dev/disk/by-id |grep wwn|egrep -v "part|$IGNOREBLK"`
HW=`dmidecode -s system-manufacturer`

#Capture the Host name and User ID
read -p "Enter the hostname :"  MYHOST
read -p "Please entering your username: " MYUSER

# Work Around: Need to make sure that the installation disk loads the ZFS kernel module
# this will need to be implemented during the instalation image creation
modprobe zfs

#Functions
qemudisk ()
    {
     if [ $DISK_NUM -gt 1 ]; then
        DISK=`read -r a b <<<$(echo $BYPATH) ; echo /dev/disk/by-path/$a /dev/disk/by-path/$b`
      else
        DISK=`read -r a b <<<$(echo $BYPATH) ; echo /dev/disk/by-path/$a`
    fi
    INST_PRIMARY_DISK=$(echo $DISK | cut -f1 -d\ )   
    }

pysdisk ()
    {
    if [ $DISK_NUM -gt 1 ]; then
        DISK=`read -r a b <<<$(echo $BYID) ; echo /dev/disk/by-id/$a /dev/disk/by-id/$b`
      else
        DISK=`read -r a b <<<$(echo $BYID) ; echo /dev/disk/by-id/$a`
    fi
    INST_PRIMARY_DISK=$(echo $DISK | cut -f1 -d\ )           
    }

unecrpool ()
    {
      zfs create -o canmount=off -o mountpoint=none rpool/$INST_ID  
    }

encrpool ()
    {
      zfs create -o canmount=off -o mountpoint=none -o encryption=on -o keylocation=prompt -o keyformat=passphrase rpool/$INST_ID
    }


# Determine the machine type
if [ $HW = "QEMU" ]; then
   qemudisk
 else
   pysdisk
fi

# Partition Disk
for i in ${DISK}; do
    blkdiscard -f $i &
done
wait

for i in ${DISK}; do
    sgdisk --zap-all $i
    sgdisk -n1:1M:+${INST_PARTSIZE_ESP}G -t1:EF00 $i
    sgdisk -n2:0:+${INST_PARTSIZE_BPOOL}G -t2:BE00 $i
    if [ "${INST_PARTSIZE_SWAP}" != "" ]; then
        sgdisk -n4:0:+${INST_PARTSIZE_SWAP}G -t4:8200 $i
    fi
    if [ "${INST_PARTSIZE_RPOOL}" = "" ]; then
        sgdisk -n3:0:0 -t3:BF00 $i
    else
        sgdisk -n3:0:+${INST_PARTSIZE_RPOOL}G -t3:BF00 $i
    fi
    sgdisk -a1 -n5:24K:+1000K -t5:EF02 $i
done

# Re-read partition table 
partprobe

# Create Zpool
disk_num=0; for i in $DISK; do disk_num=$(( $disk_num + 1 )); done
if [ $disk_num -gt 1 ]; then INST_VDEV_BPOOL=mirror INST_VDEV=mirror; fi

zpool create -f \
    -o compatibility=grub2 \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=lz4 \
    -O devices=off \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/boot \
    -R /mnt \
    bpool \
    $INST_VDEV_BPOOL \
    $(for i in ${DISK}; do
        printf "$i-part2 "
    done)

zpool create -f \
    -o ashift=12 \
    -o autotrim=on \
    -R /mnt \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    rpool \
    $INST_VDEV \
    $(for i in ${DISK}; do
        printf "$i-part3 "
    done)

# Create manditory ZFS datasets
awk 'BEGIN { printf "===========================================\n|| Do you wish to Encrypt the root pool! ||\n===========================================\n" }'

select yn in "Yes" "No"; do
    case $yn in
        Yes ) encrpool; break;;
        No ) unecrpool; break;;
    esac
done

for i in {bpool/$INST_ID,bpool/$INST_ID/BOOT,rpool/$INST_ID/ROOT,rpool/$INST_ID/DATA}; do
    zfs create -o canmount=off -o mountpoint=none $i
done
zfs create -o mountpoint=/boot -o canmount=noauto bpool/$INST_ID/BOOT/default
zfs create -o mountpoint=/ -o canmount=off rpool/$INST_ID/DATA/default
zfs create -o mountpoint=/ -o canmount=noauto rpool/$INST_ID/ROOT/default
zfs mount rpool/$INST_ID/ROOT/default
zfs mount bpool/$INST_ID/BOOT/default

for i in {usr,var,var/lib}; do
    zfs create -o canmount=off rpool/$INST_ID/DATA/default/$i
done

for i in {home,root,srv,usr/local,var/log,var/spool}; do
    zfs create -o canmount=on rpool/$INST_ID/DATA/default/$i
done

# create User dataset
zfs create -o canmount=on rpool/$INST_ID/DATA/default/home/${MYUSER}

chmod 750 /mnt/root

###OPTIONAL
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/games
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/www
## for GNOME
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/AccountsService
## for Docker
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/docker
## for NFS
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/nfs
## for LXC
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/lxc
## for LibVirt
#zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/libvirt
##other application
# zfs create -o canmount=on rpool/$INST_ID/DATA/default/var/lib/$name


# Format ESP
for i in ${DISK}; do
    mkfs.vfat -n EFI ${i}-part1
    mkdir -p /mnt/boot/efis/${i##*/}-part1
    mount -t vfat ${i}-part1 /mnt/boot/efis/${i##*/}-part1
done

mkdir -p /mnt/boot/efi
mount -t vfat ${INST_PRIMARY_DISK}-part1 /mnt/boot/efi

# Add zfs repo and Install base packages
dnf --installroot=/mnt --releasever=${INST_FEDORA_VER} -y install https://zfsonlinux.org/fedora/zfs-release.fc${INST_FEDORA_VER}.noarch.rpm \
    @core grub2-efi-x64 grub2-pc-modules grub2-efi-x64-modules shim-x64 efibootmgr cryptsetup python3-dnf-plugin-post-transaction-actions

# Add copr Longterm Kernel repo and install LTS kernel and ZFS
#dnf --installroot=/mnt copr enable -y kwizart/kernel-longterm-5.15
#dnf --installroot=/mnt install -y kernel-longterm kernel-longterm-devel 

# Install ZFS and development kernel
dnf --installroot=/mnt install -y zfs zfs-dracut
dnf --installroot=/mnt install -y kernel-core kernel-modules-extra kernel-modules kernel kernel-headers kernel-devel

# Generate fstab
genfstab -U /mnt | sed 's;zfs[[:space:]]*;zfs zfsutil,;g' | grep "zfs zfsutil" >>/mnt/etc/fstab
for i in ${DISK}; do
    echo UUID=$(blkid -s UUID -o value ${i}-part1) /boot/efis/${i##*/}-part1 vfat \
        x-systemd.idle-timeout=1min,x-systemd.automount,noauto,umask=0022,fmask=0022,dmask=0022 0 1 >>/mnt/etc/fstab
done
echo UUID=$(blkid -s UUID -o value ${INST_PRIMARY_DISK}-part1) /boot/efi vfat \
    x-systemd.idle-timeout=1min,x-systemd.automount,noauto,umask=0022,fmask=0022,dmask=0022 0 1 >>/mnt/etc/fstab
if [ "${INST_PARTSIZE_SWAP}" != "" ]; then
    for i in ${DISK}; do
        echo ${i##*/}-part4-swap ${i}-part4 /dev/urandom swap,cipher=aes-cbc-essiv:sha256,size=256,discard >>/mnt/etc/crypttab
        echo /dev/mapper/${i##*/}-part4-swap none swap x-systemd.requires=cryptsetup.target,defaults 0 0 >>/mnt/etc/fstab
    done
fi


#Configure dracut
echo 'add_dracutmodules+=" zfs "' >/mnt/etc/dracut.conf.d/zfs.conf

#Force load mpt3sas module if used
if grep mpt3sas /proc/modules; then
    echo 'forced_drivers+=" mpt3sas "' >>/mnt/etc/dracut.conf.d/zfs.conf
fi

#Enable timezone sync
hwclock --systohc
systemctl enable systemd-timesyncd --root=/mnt

#Non-Interactively set locale, keymap, timezone, hostname and root password:
rm -f /mnt/etc/localtime
systemd-firstboot --root=/mnt --force \
    --locale="en_US.UTF-8" --locale-messages="en_US.UTF-8" \
    --keymap=us --timezone="America/Edmonton" --hostname=$MYHOST

#Generate host id:
zgenhostid -f -o /mnt/etc/hostid

#Install locale package, example for English locale:
dnf --installroot=/mnt install -y glibc-minimal-langpack glibc-langpack-en

#Enable ZFS services:
systemctl enable zfs-import-scan.service zfs-import.target zfs-zed zfs.target --root=/mnt
systemctl disable zfs-mount --root=/mnt

#By default SSH server is enabled, allowing root login by password, disable SSH server:
#systemctl disable sshd --root=/mnt
#systemctl enable firewalld --root=/mnt
####### CHROOT BEGINS #############

cp /root/fedora_zfs_root/stage2_chroot.sh /mnt/root/stage2_chroot.sh
chmod 755 /mnt/root/stage2_chroot.sh

### Prepearing for Stage2 CHROOT
echo "INST_PRIMARY_DISK=$INST_PRIMARY_DISK
INST_LINVAR=$INST_LINVAR
INST_UUID=$INST_UUID
INST_ID=$INST_ID
unalias -a
INST_VDEV=$INST_VDEV
MYHOST=$MYHOST
myUser=${MYUSER}
FINDBBLK=$FINDBBLK
IGNOREBLK=$IGNOREBLK
BYPATH=$BYPATH
BYID=$BYID
DISK=\"$DISK\"" >/mnt/root/chroot

mkdir -p /mnt/run/systemd/resolve/
cp /run/systemd/resolve/stub-resolv.conf /mnt/run/systemd/resolve/stub-resolv.conf

cd /mnt/
mount -o bind /dev dev
mount -o bind /proc proc
mount -o bind /sys sys
mount -o bind /run run
mount -t tmpfs tmpfs tmp


awk 'BEGIN { printf "=================================\n|| Entering Chroot Environment ||\n=================================\n" }'

sleep 5
cd /

# Start stage2 chroot script
chroot /mnt /bin/bash -c ./root/stage2_chroot.sh


# Once chroot has exited unmount
# the ZFS volumes and shutdown the system

#Unmount EFI system partition:
umount /mnt/boot/efi
umount /mnt/boot/efis/*

#Export pools
zpool export -f bpool
zpool export -f rpool

# shutdown
shutdown -h now

#Take a snapshot of the clean installation for future use
#zfs snapshot -r rpool/$INST_ID@install
#zfs snapshot -r bpool/$INST_ID@install