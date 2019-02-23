#!/bin/sh

host()
{
clear

# Set account
# --------------------------------------------
# hostname
# root password
# new user name
# new user password
# --------------------------------------------
read -rp "Set hostname: " hstname
while true; do
	read -rsp "Set password for root: " rtpswd
	read -rsp $'\nConfirm: ' rtpswd2
	if [ "$rtpswd"x = "$rtpswd2"x ]; then
		break
	else
		echo -e "\nPasswords not match. Try again."
	fi
done
read -rp $'\nSet new username: ' usrname
while true; do
	read -rsp "Set password for $usrname: " usrpswd
	read -rsp $'\nConfirm: ' usrpswd2
	if [ "$usrpswd"x = "$usrpswd2"x ]; then
		break
	else
		echo -e "\nPasswords not match. Try again."
	fi
done
echo ""
if [ -z "$usrname" ]; then usrname=user; fi
if [ -z "$usrpswd" ]; then usrpswd=user; fi
if [ -z "$hstname" ]; then hstname=arch-pc; fi
if [ -z "$rtpswd" ]; then rtpswd=root; fi

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
# Use only mirrors in China
# --------------------------------------------
echo "Configuring pacman mirrors..."
sed -i -ne '/China/{n;p}' /etc/pacman.d/mirrorlist

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
mkdir /mnt/hostlvm
mount --bind /run/lvm /mnt/hostlvm
touch /mnt/export
cat >> /mnt/export << EOF
export usrname=$usrname
export usrpswd=$usrpswd
export hstname=$hstname
export rtpswd=$rtpswd
EOF
wget -O /mnt/arch-install.sh https://raw.githubusercontent.com/Zuyav/scripts/master/arch-install.sh >> /dev/null 2>&1
chmod +x /mnt/arch-install.sh
arch-chroot /mnt /bin/bash -c "./arch-install.sh guest"

echo "  - Cleaning..."
umount /mnt/hostlvm
rm -rf /mnt/hostlvm
rm /mnt/arch-install.sh
rm /mnt/export

echo "  - Unmounting partitions..."
umount -R /mnt

echo "Installation finished. You can reboot now."
exit 0
}

guest()
{
ln -s /hostlvm /run/lvm
source /export

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
echo $hstname > /etc/hostname
cat >> /etc/hosts << EOF
127.0.0.1	localhost
127.0.1.1	$hstname
::1	localhost
EOF

echo "  - Configuring initramfs..."
sed -i -e '/^HOOKS/s/block\ filesystems/block\ lvm2\ filesystems/' /etc/mkinitcpio.conf
mkinitcpio -p linux >> /dev/null 2>&1

echo "  - Setting root password..."
echo -e "$rtpswd\n$rtpswd\n" | passwd >> /dev/null 2>&1

echo "  - Installing grub..."
pacman -S efibootmgr grub --noconfirm >> /dev/null 2>&1
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch >> /dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null 2>&1
mkdir -p /boot/efi/EFI/BOOT
if test ! -e /boot/efi/EFI/BOOT/BOOTX64.EFI; then
	cp /boot/efi/EFI/Arch/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
fi
cat >> /etc/grub.d/40_custom << EOF
menuentry "Shutdown" {
	echo "System shutting down..."
	halt
}

menuentry "Reboot" {
	echo "System rebooting..."
	reboot
}
EOF
grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null 2>&1

echo "  - Adding new user..."
useradd -m $usrname
echo -e "$usrpswd\n$usrpswd\n" | passwd $usrname
pacman -S sudo --noconfirm >> /dev/null 2>&1
sed -i -e "/^root ALL=(ALL) ALL/a $usrname ALL=(ALL) ALL" /etc/sudoers

echo "Configuring pacman mirrors for new system..."
echo "  - Installing pacman-contrib..."
pacman -Syyu >> /dev/null 2>&1
pacman -S pacman-contrib --noconfirm >> /dev/null 2>&1
echo "  - Sorting pacman mirrors..."
curl -s "https://www.archlinux.org/mirrorlist/?country=CN" | sed -e 's/^#Server/Server/' | rankmirrors - > /etc/pacman.d/mirrorlist



echo "  - Exiting chroot environment..."
exit
}

if [ "$1"x = x ]; then
	host
elif [ "$1"x = guestx ]; then
	guest
else
	echo "Invalid parameter!"
	exit 1
fi
