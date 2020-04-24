#!/bin/bash
RUN(){
	local run r
	if [[ "${1}" != "" ]];then
		echo -en "${1}"
	fi
	run="$(${@:2} 3>&1 1>&1 2>&1)"
	r=$?
	if [[ $r != 0 ]];then
		echo -e "\033[1;31m[ ERROR: $r ]\n\033[2m${@:2}\033[0m\n$run"
		echo -e "\033[1;31m[ ERROR: $r ]\n\033[2m${@:2}\033[0m\n$run" >> "$DIRSTACK"/"$r".log
		if [[ $LOOP != "" ]];then
			losetup -d "$LOOP"
		fi
		UMOUNT_ALL
		exit $r
	fi
	if [[ "${1}" != "" ]];then
		echo -e "\033[0m\033[1m\033[1;36m[ OK ]\033[0m"
	fi
}
UMOUNT(){
	if [[ "" != `mount | grep "$1"` ]];then
		umount -q -l -f `mount | awk '{print $3}' | grep "$1" | sort -rn`
	fi
}	
UMOUNT_ALL(){
	UMOUNT "`realpath $ROOT_ISO`" 
	UMOUNT "`realpath $ROOT`"
	UMOUNT "`realpath $DIRSTACK`"
}	
if [ -f "$DIRSTACK"/config ]
then
	source "$DIRSTACK"/config
else
	echo -e "\033[1mconfig not found\033[0m";exit 10
fi
UMOUNT_ALL
for f in "$ROOT" "$ROOT_ISO" #"$CACHE_DIR"
do
	if [ -d "$f" ];
	then
		if [[ "" == "$(mount | grep `realpath $f`)" ]];then
			RUN "\033[1;36m\033[2mDelete $f \033[0m" rm -r "$f"
		else
			echo -e "\033[1;31m[ ERROR: 255 ]\n\033[2m"Не отмонтирован $f"\033[0m\n"
			exit 255
		fi
	fi
	RUN "" mkdir -p "$f"
done
#----------------------------
mkdir -p "$CACHE_DIR"
RUN "\033[1;36m\033[2mInstall Debian \033[0m" debootstrap --cache-dir="$CACHE_DIR" "$DEBIAN" "$ROOT"/ https://deb.debian.org/debian/
CHROOT_SETUP() {
	mkdir -m 0755 -p "$1"/var/log "$1"/{dev,run}
	mkdir -m 1777 -p "$1"/tmp
	mkdir -m 0555 -p "$1"/{sys,proc}
	mount proc "$1/proc" -t proc -o nosuid,noexec,nodev
	mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro
	if [ -d /sys/firmware/efi/efivars ]
	then
		mkdir -p "$1/sys/firmware/efi/efivars"
		mount /sys/firmware/efi/efivars "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev
	fi
	mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid
	mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec
	mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev
	mount /run "$1/run" --bind
	mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}
echo "deb https://deb.debian.org/debian $DEBIAN-backports main" >> "$ROOT"/etc/apt/sources.list # Backports
export DEBIAN_FRONTEND=noninteractive
RUN "\033[1;36m\033[2mMount chroot \033[0m" CHROOT_SETUP "$ROOT"
RUN "\033[1;36m\033[2mSynchronizing package databases \033[0m" chroot "$ROOT" "apt" "update"
RUN "\033[1;36m\033[2mInstalling \033[0m\033[1m\033[1;36m$PKG\033[2m \033[0m" chroot "$ROOT" "apt" "install" $PKG "--assume-yes"
RUN "\033[1;36m\033[2mCopy customization files \033[0m" cp -r -a "$DIRSTACK"/customization/* "$ROOT"/
systemctl stop docker
if [[ "$DOCKER_DIR" != '' ]];then
	UMOUNT "$DOCKER_DIR"
	RUN "\033[1;36m\033[2mCopy docker files \033[0m" cp -r -a "$DOCKER_DIR" "$ROOT"/var/lib/docker
	RUN "\033[1;36m\033[2mCopy docker-compose files \033[0m" cp -r -a /opt/docker "$ROOT"/opt/docker
fi
RUN "\033[1;36m\033[2mDisable docker.service \033[0m" chroot "$ROOT" "systemctl" "disable" "docker.service"
RUN "\033[1;36m\033[2mDisable ssh.service \033[0m" chroot "$ROOT" "systemctl" "disable" "ssh.service"
RUN "\033[1;36m\033[2mDisable getty@tty1.service \033[0m" chroot "$ROOT" "systemctl" "disable" "getty@tty1.service"
RUN "\033[1;36m\033[2mEnable start script \033[0m" chroot "$ROOT" "systemctl" "enable" "start.service"
RUN "\033[1;36m\033[2mUmount chroot \033[0m" UMOUNT "`realpath $ROOT`"
RUN "\033[1;36m\033[2mCleaning \033[0m" rm -rfv "$ROOT"/debootstrap "$ROOT"/var/cache/apt/archives/* "$ROOT"/var/cache/debconf "$ROOT"/var/lib/apt/lists/* "$ROOT"/var/cache/apt/*.bin "$ROOT"/var/log/* "$ROOT"/tmp/* "$ROOT"/root/.bash_history
RUN "" chroot "$ROOT" apt-get clean
SIZE=$(( `du -sm "$ROOT" | awk '{print $1}'` ))
SIZE=$(( $SIZE / 100 * $SIZE_ISO ))
if [[ $BIOS_Legacy = 1 ]];then
	SIZE=$(( $SIZE + 34 ))
fi
if [[ $BIOS_UEFI = 1 ]];then
	SIZE=$(( $SIZE + 34 ))
fi
if [[ $BIOS_UEFI32 = 1 ]];then
	SIZE=$(( $SIZE + 34 ))
fi
RUN "\033[1;36m\033[2mCreate ISO \033[0m" truncate -s ""$SIZE"M" "$DIRSTACK"/"$ISO"
LOOP=`losetup -f`
RUN "" losetup $LOOP "$DIRSTACK"/"$ISO"
echo -e "\033[1mSize: \033[1;36m$SIZE MB\n\033[2m"$ISO" -> $LOOP\033[0m"
RUN "" parted --script "$LOOP" mktable gpt;PART_N=0
if [[ $BIOS_Legacy = 1 ]];then
	RUN "" sgdisk -n 0:0:+34M "$LOOP";((PART_N++));partprobe "$LOOP"
	RUN "" parted "$LOOP" set "$PART_N" bios_grub on
fi
if [[ $BIOS_UEFI = 1 ]];then
	RUN "" sgdisk -n 0:0:+34M "$LOOP";((PART_N++));EFI_PART=""$LOOP"p"$PART_N"";partprobe "$LOOP"
	RUN "\033[1;36m\033[2mFormat EFI partition \033[0m\033[1m\033[1;36m$EFI_PART \033[0m" mkfs.vfat -F32 -v "$EFI_PART"
	RUN "" parted "$LOOP" set "$PART_N" boot on
	RUN "" parted "$LOOP" set "$PART_N" esp on
	RUN "" parted "$LOOP" name"$PART_N" "EFI"
fi
if [[ $BIOS_UEFI32 = 1 ]];then
	RUN "" sgdisk -n 0:0:+34M "$LOOP";((PART_N++));EFI_PART32=""$LOOP"p"$PART_N"";partprobe "$LOOP"
	RUN "\033[1;36m\033[2mFormat 32-EFI partition \033[0m\033[1m\033[1;36m$EFI_PART32 \033[0m" mkfs.vfat -F32 -v "$EFI_PART32"
	RUN "" parted "$LOOP" set "$PART_N" boot on
	RUN "" parted "$LOOP" set "$PART_N" esp on
	RUN "" parted "$LOOP" name"$PART_N" "EFI32"
fi
RUN "" sgdisk -n 0:0:0 "$LOOP";((PART_N++));ROOT_PART=""$LOOP"p"$PART_N""
RUN "" parted "$LOOP" name"$PART_N" "debian"
RUN "" partprobe "$LOOP"
RUN "\033[1;36m\033[2mFormat ROOT partition \033[0m\033[1m\033[1;36m$ROOT_PART \033[0m" mkfs.ext4 -F -O ^64bit -L "debian" "$ROOT_PART"
mkdir -p "$ROOT_ISO"
RUN "" mount "$ROOT_PART" "$ROOT_ISO"
if [[ $BIOS_Legacy = 1 ]];then
	RUN "\033[1;36m\033[2mInstall legasy bootloader \033[0m" grub-install "$LOOP" --target=i386-pc --root-directory="$ROOT_ISO"
fi
if [[ $BIOS_UEFI = 1 ]];then
	mkdir -p "$ROOT_ISO"/boot/EFI
	RUN "" mount "$EFI_PART" "$ROOT_ISO"/boot/EFI
	RUN "\033[1;36m\033[2mInstall EFI bootloader \033[0m" grub-install --target=x86_64-efi --removable --bootloader-id="debian" --root-directory="$ROOT_ISO" --efi-directory="$ROOT_ISO"/boot/EFI/
fi
if [[ $BIOS_UEFI32 = 1 ]];then
	mkdir -p "$ROOT_ISO"/boot/EFI32
	RUN "" mount "$EFI_PART32" "$ROOT_ISO"/boot/EFI32
	RUN "\033[1;36m\033[2mInstall i386-EFI bootloader \033[0m" grub-install --target=i386-efi --removable --bootloader-id="debian" --root-directory="$ROOT_ISO" --efi-directory="$ROOT_ISO"/boot/EFI32/
fi
RUN "\033[1;36m\033[2mInstalling the system in ISO \033[0m" cp -r -a "$ROOT"/* "$ROOT_ISO"/
RUN "\033[1;36m\033[2m"$DIRSTACK"/grub.cfg -> "$ROOT_ISO"/boot/grub/grub.cfg \033[0m" cp "$DIRSTACK"/grub.cfg "$ROOT_ISO"/boot/grub/grub.cfg
UUID=`blkid -o value -s UUID "$ROOT_PART"`
echo "UUID=$UUID / `lsblk "$ROOT_PART" -n -o FSTYPE | head -n1` defaults,rw 0 1" >> "$ROOT_ISO"/etc/fstab
RUN "" sed -i s:UUID_ISO:$UUID: "$ROOT_ISO"/boot/grub/grub.cfg
RUN "" sed -i s:INITRD_IMG:`basename -a "$ROOT_ISO"/boot/*initrd* | head -1`: "$ROOT_ISO"/boot/grub/grub.cfg
RUN "" sed -i s:VMLINUZ:`basename -a "$ROOT_ISO"/boot/*vmlinuz* | head -1`: "$ROOT_ISO"/boot/grub/grub.cfg
RUN "\033[1;36m\033[2mUmount all \033[0m" UMOUNT_ALL
RUN "" losetup -d "$LOOP"
echo -e "\033[1m\033[1;36m[ Successfully ]\033[0m"

if [[ "$@" = *-vdi* ]];then
	name=${ISO%.iso*}
	RUN "\033[1;36m\033[2m"$ISO" -> "$name".vdi \033[0m" VBoxManage convertfromraw "$DIRSTACK"/"$ISO" "$DIRSTACK"/"$name".vdi
fi