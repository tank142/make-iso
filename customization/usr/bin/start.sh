#!/bin/bash
#Пароль рута
echo -e "\033[0m\033[1mAdd \033[1;31mroot\033[0m\033[1m password\033[0m"
while true; do 
	passwd
	r=$?
	if [[ $r == 0 ]];then
		break
	fi
	if [[ $r == 127 ]];then
		break
	fi
done
RUN(){
	local run r
	if [[ "${1}" != "" ]];then
		echo -en "${1}"
	fi
	run="$(${@:2} 3>&1 1>&1 2>&1)"
	r=$?
	if [[ $r != 0 ]];then
		echo -e "\033[1;31m[ ERROR: $r ]\n${@:2}\033[0m\n$run"
	fi
	if [[ "${1}" != "" ]];then
		echo -e "\033[0m\033[1m\033[1;36m[ OK ]\033[0m"
	fi
}
#Возвращает устройство с указанным разделом
PARTITION_DEVICE(){
	for f in `lsblk -n | grep -v '─' | awk '{print $1}'`;do
		if [[ "$1" == *"$f"* ]];then
			echo "$f"
			break
		fi
	done
}
#Расшаперивает раздел на свободное место
PARTITION_RESIZE(){
	local start_sector=`sgdisk /dev/$2 -i "$3" | grep 'First sector' | grep -oP ':\K.*' | awk '{print $1}'`
	#Проверка существования таблицы разделов.
	if [[ "" != `lsblk "$1" -o PTTYPE -n | awk '{print $1}'` ]];then
		RUN "\033[1;36m\033[2mDelete $1 \033[0m" sgdisk "/dev/$2" -d "$3"
		RUN "\033[1;36m\033[2mCreate $1 \033[0m" sgdisk -n 0:$start_sector:0 /dev/"$2"
		sync
		RUN "" partprobe /dev/"$2"
	fi
	RUN "\033[1;36m\033[2mExpansion of $1 partition \033[0m" resize2fs "$1"
}
RUN "" hostnamectl set-hostname archlinux
DEV_ROOT_PART=`mount | grep '/ ' | awk '{print $1}'`
DEV_ROOT=`PARTITION_DEVICE "$DEV_ROOT_PART"`
DEV_ROOT_P=${DEV_ROOT_PART##*[A-z]}
RUN "\033[1;36m\033[2mUpdate partition table /dev/$DEV_ROOT \033[0m" sgdisk -e /dev/"$DEV_ROOT"
RUN "" sgdisk -s /dev/"$DEV_ROOT"
PARTITION_RESIZE "$DEV_ROOT_PART" "$DEV_ROOT" "$DEV_ROOT_P"
#---------------------------------------------------------
RUN "" systemctl disable start.service 
RUN "\033[1;36m\033[2mEnable getty@tty1.service \033[0m" systemctl enable getty@tty1.service
RUN "\033[1;36m\033[2mDelete start script \033[0m" rm /usr/bin/start.sh /usr/lib/systemd/system/start.service
lsblk -D -f -n -o NAME,SIZE,MODEL,FSTYPE,FSUSE%,MOUNTPOINT
uname -s -r
bash
