#!/bin/sh

hname=VM-Arch
pswd=quantenna

host()
{
# Disk Partitioning
# --------------------------------------------
# sda - sda1 - 256MiB - EFI
#     - sda2 - free space - LVM
# --------------------------------------------
echo "Partitioning disk..."
echo -e "o\nY\nn\n\n\n+256M\nef00\nn\n\n\n\n8e00\nw\nY\n" | gdisk /dev/sda >> /dev/null 2>&1

# Configure Partition
# --------------------------------------------
# Create a volume group "vg1" using sda2
# Create a logical volume "lv1" on "vg1"
# Setup file system
# mount partitions
# --------------------------------------------
echo "Configuring partitions..."
vgcreate vg1 /dev/sda2 >> /dev/null 2>&1
lvcreate -l +100%FREE vg1 -n lv1 >> /dev/null 2>&1
mkfs.fat -F32 /dev/sda1 >> /dev/null 2>&1
mkfs.ext4 /dev/vg1/lv1 >> /dev/null 2>&1
mount /dev/vg1/lv1 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

# Configure Pacman Mirrors
# --------------------------------------------
# The pacman-contrib package provides a script
#     called rankmirrors to rank the mirrors
# List of mirrors to be ranked is fetched from
#     the offiial Pacman Mirrorlist Generator
# --------------------------------------------
echo "Configuring pacman mirrors..."
echo "  - Installing pacman-contrib..."
pacman -Sy >> /dev/null 2>&1
pacman -S pacman-contrib --noconfirm >> /dev/null 2>&1
echo "  - Ranking mirrors..."
curl -s "https://www.archlinux.org/mirrorlist/?country=CN&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors - > /etc/pacman.d/mirrorlist

# Install Basic System
# --------------------------------------------
# 
# --------------------------------------------
echo "Installing Basic System..."
pacstrap /mnt base >> /dev/null 2>&1

# Configure system
# --------------------------------------------
# Generate fstab file
# --------------------------------------------
echo "Configuring system..."
echo "  - Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "  - Changing root..."
wget -O /mnt/arch-install.sh https://raw.githubusercontent.com/Zuyav/scripts/master/arch-install.sh >> /dev/null 2>&1
chmod +x /mnt/arch-install.sh
mkdir /mnt/hostlvm
mount --bind /run/lvm /mnt/hostlvm
arch-chroot /mnt /bin/bash -c "./arch-install.sh guest"

echo "  - Unmounting partitions..."
umount -R /mnt

echo "Installation finished. You can reboot now."
exit 0
}

guest()
{
ln -s /hostlvm /run/lvm

echo "  - Setting time zone..."
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock -w

echo "  - Localizing..."
sed -i -e 's/^#en_US.UTF-8/en_US.UTF-8/' -e 's/^#zh_CN.UTF-8/zh_CN.UTF-8/' -e 's/^#zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen
locale-gen >> /dev/null 2>&1
touch /etc/locale.conf
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "  - Setting hostname..."
touch /etc/hostname
echo $hname > /etc/hostname
cat >> /etc/hosts << EOF
127.0.0.1	localhost
127.0.1.1	$hname
::1	localhost
EOF

echo "  - Configuring initramfs..."
sed -i -e '/^HOOKS/s/block\ filesystems/block\ lvm2\ filesystems/' /etc/mkinitcpio.conf
mkinitcpio -p linux

echo "  - Setting root password..."
echo -e "$pswd\n$pswd\n" | passwd

echo "  - Installing grub..."
pacman -S efibootmgr grub --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

echo "  - Exiting chroot environment..."
exit
}

if [ "$1"x = x ]; then
	host
elif [ "$1"x = guestx ]; then
	guest
else
	echo "Invalid parameter!"
fi
