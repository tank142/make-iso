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
LOOP=`losetup -f`
DIR=`realpath "$1"`
SIZE=$(( `du -sm "$DIR" | awk '{print $1}'` ))
if (( "$SIZE" < "50" ));then
	SIZE="50"
fi
rm -f "$DIR".iso
RUN "\033[1;36m\033[2mCreate ISO \033[0m" truncate -s ""$SIZE"M" "$DIR".iso
echo -e "\033[1mSize: \033[1;36m$SIZE MB\n\033[2m$DIR.iso -> $LOOP\033[0m"
RUN "" losetup $LOOP "$DIR".iso
RUN "\033[1;36m\033[2mCreate filesystem $LOOP \033[0m" mkfs.ext4 -F -O ^64bit -L "ammolite-data" $LOOP
RUN "" mkdir "$DIR"_LOOP
RUN "" mount $LOOP "$DIR"_LOOP
RUN "\033[1;36m\033[2mCopy "$DIR" -> "$DIR"_LOOP/ \033[0m" cp -r "$DIR"/* "$DIR"_LOOP/
UMOUNT "$DIR"
RUN "\033[1;36m\033[2mDelete "$DIR"_LOOP \033[0m" rm -r "$DIR"_LOOP
fsck -l $LOOP
RUN "\033[1;36m\033[2mDisable $LOOP \033[0m" losetup -d $LOOP
if [[ "$@" = *vdi* ]];then
	rm -f "$DIR".vdi
	RUN "\033[1;36m\033[2m"$DIR".iso -> "$DIR".vdi \033[0m" VBoxManage convertfromraw "$DIR".iso "$DIR".vdi
	chown tank:tank "$DIR".vdi
fi