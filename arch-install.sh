#!/bin/bash

#-------------------------------------------------------------------------------
# 全局变量
# 都是用来设置echo样式的
#-------------------------------------------------------------------------------
red='\x1b[38;2;170;0;0m'
green='\x1b[38;2;0;170;0m'
blue='\x1b[38;2;23;147;209m'
bold=$(tput bold)
norlmal=$(tput sgr0)

#-------------------------------------------------------------------------------
# 一条****从左向右循环移动
#-------------------------------------------------------------------------------
spinner()
{
	while true; do
		for bar in "  ****  " "   **** " "    ****" "*    ***" "**    **" "***    *" "****    " " ****   "; do
			echo -e "\r[${blue}${bold}$bar${normal}\033[0m] $1\c"
			sleep .5
		done
	done
}

#-------------------------------------------------------------------------------
# 安排一个命令
# 让它开始执行, 输出重定向到文件
# 并且显示一个彩色的spinner来指示状态
# 用法: anPai '要执行的指令' "要显示的字符串"
#-------------------------------------------------------------------------------
anPai()
{
	spinner "$2" &
	local PID=$!
	$1 > ./arch-install.log 2>&1
	kill $PID > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\r[${green}${bold}   OK   ${normal}\033[0m] $2"
		rm ./arch-install.log
		return 0
	else
		echo -e "\r[${red}${bold} FAILED ${normal}\033[0m] $2"
		cat ./arch-install.log | tail -n 10
		echo "Complete log could be found in ./arch-install.log"
		exit 1
	fi
	
}

#-------------------------------------------------------------------------------
# 设置用户名, 密码, 主机名等
#-------------------------------------------------------------------------------
readInput()
{
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
}

#-------------------------------------------------------------------------------
# 检查网络状态
# ping Arch Linux官网
#-------------------------------------------------------------------------------
checkNetwork()
{
	ping -c5 archlinux.org
}

#-------------------------------------------------------------------------------
# 磁盘分区
# 使用gdisk - 新建GPT分区表
#           - 新建EFI分区, 512MB
#           - 新建Root分区, 剩余空间
#-------------------------------------------------------------------------------
partitionDisk()
{
	sgdisk -o /dev/sda
	sgdisk -n 0:0:+512M /dev/sda
	sgdisk -n 0:0:0 /dev/sda
	sgdisk -t 1:ef00 /dev/sda
	sgdisk -t 2:8304 /dev/sda
	sgdisk -c 1:efi /dev/sda
	sgdisk -c 2:system /dev/sda
}

#-------------------------------------------------------------------------------
# 格式化分区
# EFI分区格式化为fat32格式
# Root分区格式化为ext4格式
#-------------------------------------------------------------------------------
formatPartition()
{
	mkfs.fat -F32 /dev/sda1
	mkfs.ext4 /dev/sda2
}

#-------------------------------------------------------------------------------
# 挂载分区
# 首先挂载Root分区到/mnt
# 然后挂载EFI分区到/mnt/boot/efi
#-------------------------------------------------------------------------------
mountPartition()
{
	mount /dev/sda2 /mnt
	mkdir -p /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi
}

#-------------------------------------------------------------------------------
# 设置pacman镜像
# 只保留中国的镜像源
#-------------------------------------------------------------------------------
selectMirror()
{
	wget -O /etc/pacman.d/mirrorlist "https://www.archlinux.org/mirrorlist/?country=CN"
	sed -i -e 's/^#Server/Server/' /etc/pacman.d/mirrorlist
}

#-------------------------------------------------------------------------------
# 安装base组和base-devel组的包
#-------------------------------------------------------------------------------
installBaseSystem()
{
	pacstrap /mnt base base-devel
}

#-------------------------------------------------------------------------------
# 生成fstab
# fstab文件告知操作系统文件系统如何组织以及如何挂载它们
#-------------------------------------------------------------------------------
generateFstab()
{
	genfstab -U /mnt
	genfstab -U /mnt >> /mnt/etc/fstab
}

#-------------------------------------------------------------------------------
# 传递参数
# 用于设置账户
#-------------------------------------------------------------------------------
passParameter()
{
	echo "export usrname=$usrname" > /mnt/export
	echo "export usrpswd=$usrpswd" >> /mnt/export
	echo "export hstname=$hstname" >> /mnt/export
	echo "export rtpswd=$rtpswd" >> /mnt/export
}

#-------------------------------------------------------------------------------
# 下载安装脚本
# 放入guset的目录中以便在chroot后运行
#-------------------------------------------------------------------------------
downloadScript()
{
	wget -O /mnt/arch-install.sh https://raw.githubusercontent.com/Zuyav/scripts/master/arch-install.sh
	chmod +x /mnt/arch-install.sh
}

#-------------------------------------------------------------------------------
# Change root到新安装的系统, 并继续运行安装脚本
#-------------------------------------------------------------------------------
changeRoot()
{
	arch-chroot /mnt /bin/bash -c "./arch-install.sh guest"
}

#-------------------------------------------------------------------------------
# 清理安装过程中的临时文件
#-------------------------------------------------------------------------------
cleanTemp()
{
	rm /mnt/arch-install.sh
	rm /mnt/export
}

unmountPartition()
{
	umount -R /mnt
}

#-------------------------------------------------------------------------------
# 在host系统中运行的部分
#-------------------------------------------------------------------------------
host()
{
	clear
	readInput

	anPai 'checkNetwork' "Start to check network status."
	anPai 'partitionDisk' "Start to partition the disks."
	anPai 'formatPartition' "Start to format the partitions."
	anPai 'mountPartition' "Start to mount the partitions."
	anPai 'selectMirror' "Start to select pacman mirrors."
	anPai 'installBaseSystem' "Start to install the base packages."
	anPai 'generateFstab' "Start to generate file system table."
	anPai 'passParameter' "Start to pass parameter to the guest system."
	anPai 'downloadScript' "Start to download installation script for the guest system."

	changeRoot

	anPai 'cleanTemp' "Start to remove temporary files."
	anPai 'unmountPartition' "Start to unmount partitions."

	anPai '' "System installation is completed. You could reboot now!"
	
	exit 0
}

#-------------------------------------------------------------------------------
# 导入参数
#-------------------------------------------------------------------------------
importParameter()
{
	source /export
}

#-------------------------------------------------------------------------------
# 设置时区
#-------------------------------------------------------------------------------
setTimeZone()
{
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	hwclock -w
}

#-------------------------------------------------------------------------------
# 本地化
#-------------------------------------------------------------------------------
localize()
{
	sed -i -e 's/^#en_US.UTF-8/en_US.UTF-8/' -e 's/^#zh_CN.UTF-8/zh_CN.UTF-8/' -e 's/^#zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen
	locale-gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
}

#-------------------------------------------------------------------------------
# 配置网络
# 设置主机名
# 编辑hosts文件
# 使用传统网络命名规则
# 开启DHCP客户端服务
#-------------------------------------------------------------------------------
configureNetwork()
{
	echo $hstname > /etc/hostname
	echo "127.0.0.1	localhost" >> /etc/hosts
	echo "127.0.1.1	$hstname" >> /etc/hosts
	echo "::1	localhost" >> /etc/hosts
	ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
	systemctl enable dhcpcd.service
}

#-------------------------------------------------------------------------------
# 更新系统
#-------------------------------------------------------------------------------
updateSystem()
{
	pacman -Syyu --noconfirm
}

#-------------------------------------------------------------------------------
# 获取中国镜像源并按速度进行排序
#-------------------------------------------------------------------------------
sortMirror()
{
	pacman -S pacman-contrib --noconfirm
	curl -s "https://www.archlinux.org/mirrorlist/?country=CN" | sed -e 's/^#Server/Server/' | rankmirrors - > /etc/pacman.d/mirrorlist
}

#-------------------------------------------------------------------------------
# 设置root密码
# 添加新用户并设置密码
# 配置sudo权限
#-------------------------------------------------------------------------------
configureUserAccount()
{
	echo -e "$rtpswd\n$rtpswd\n" | passwd
	useradd -G wheel -m $usrname
	echo -e "$usrpswd\n$usrpswd\n" | passwd
	sed -i -e "/^root ALL=(ALL) ALL/a $usrname ALL=(ALL) ALL" /etc/sudoers
}

#-------------------------------------------------------------------------------
# 安装grub作为bootloader
# 添加shutdown和reboot选项
#-------------------------------------------------------------------------------
installGrub()
{
	pacman -S efibootmgr grub --noconfirm
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
	grub-mkconfig -o /boot/grub/grub.cfg
	mkdir -p /boot/efi/EFI/BOOT
	if test ! -e /boot/efi/EFI/BOOT/BOOTX64.EFI; then
		cp /boot/efi/EFI/Arch/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
	fi
	echo 'menuentry "Shutdown" {' >> /etc/grub.d/40_custom
	echo '	echo "System shutting down..."' >> /etc/grub.d/40_custom
	echo '	halt' >> /etc/grub.d/40_custom
	echo '}' >> /etc/grub.d/40_custom
	echo '' >> /etc/grub.d/40_custom
	echo 'menuentry "Reboot" {' >> /etc/grub.d/40_custom
	echo '	echo "System rebooting..."' >> /etc/grub.d/40_custom
	echo '	reboot' >> /etc/grub.d/40_custom
	echo '}' >> /etc/grub.d/40_custom
	grub-mkconfig -o /boot/grub/grub.cfg
}

#-------------------------------------------------------------------------------
# 安装GNOME
#-------------------------------------------------------------------------------
installGnome()
{
	pacman -S xorg-server xorg-xinit gnome gnome-extra
	systemctl enable gdm.service
}

#-------------------------------------------------------------------------------
# 退出chroot, 回到live环境
#-------------------------------------------------------------------------------
exitChroot()
{
	exit
}

#-------------------------------------------------------------------------------
# 在guest系统中运行的部分
#-------------------------------------------------------------------------------
guest()
{
	anPai 'importParameter' "Start to import parameters from the host system."
	anPai 'setTimeZone' "Start to set time zone."
	anPai 'localize' "Start to localize the system."
	anPai 'configureNetwork' "Start to configure network."
	anPai 'updateSystem' "Start to update the system."
	anPai 'sortMirror' "Start to sort pacman mirrors."
	anPai 'configureUserAccount' "Start to configure user accounts."
	anPai 'installGrub' "Start to install bootloader grub."
	anPai 'exitChroot' "Start to exit chroot environment."
}

#-------------------------------------------------------------------------------
# 主函数
#-------------------------------------------------------------------------------
main()
{
	if [ "$1"x = x ]; then
		host
	elif [ "$1"x = guestx ]; then
		guest
	else
		echo "Invalid parameter!"
		exit 1
	fi
}

main $1
