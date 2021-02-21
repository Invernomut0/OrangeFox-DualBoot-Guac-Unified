#!/system/bin/sh
mount_dir(){
  case "$1" in
    "Android"|"lost+found") continue;;
  esac
  dest="/mnt/runtime/default/emulated/0/$1"
  [ -d "$dest" ] || mkdir -p "$dest" 2>/dev/null
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal "/datacommon/$1" "$dest"
}
mount -t <type> -o <flags> /dev/block/by-name/userdata2 /datacommon
touch /datacommon/.nomedia
chown -R 1023:1023 /datacommon
#chcon -R u:object_r:media_rw_data_file:s0 /datacommon
until [ -d /storage/emulated/0/Android ]; do
  sleep 1
done
# Make one folder that has everything in it - for files not in a folder
mkdir /storage/emulated/0/CommonData 2>/dev/null
if [ -f "/system/etc/init/hw/init.rc" ]; then
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal /datacommon /mnt/pass_through/0/emulated/0/CommonData
else
  mount -t sdcardfs -o rw,nosuid,nodev,noexec,noatime,fsuid=1023,fsgid=1023,gid=9997,mask=7,derive_gid,default_normal /datacommon /storage/emulated/0/CommonData
fi
# Mount folders over top - sdcardfs only supports directory mounting
[ -f /datacommon/mounts.txt ] || exit 0
if [ "$(head -n1 /datacommon/mounts.txt | tr '[:upper:]' '[:lower:]')" == "all" ]; then
  for i in $(find /datacommon -mindepth 1 -maxdepth 1 -type d); do
    mount_dir "$(basename "$i")"
  done
else
  while IFS="" read -r i || [ -n "$i" ]; do
    mount_dir "$i"
  done < /datacommon/mounts.txt
fi
#SAHREDAPP SECTION
if [ -d /datacommon/SharedData ]; then
  if [ -f /datacommon/SharedData/datamount.conf ]; then
    setenforce 0
    while IFS="" read -r i || [ -n "$i" ]; do
      mount -o bind $i
      stringarray=($i)
      restorecon -R ${stringarray[1]}
      done < /datacommon/SharedData/datamount.conf
    chmod -R 777 /datacommon/SharedData/*
  fi
else
  chcon -R u:object_r:media_rw_data_file:s0 /datacommon
fi
#END SHAREDAPP

#INACTIVE SLOT MOUNT
if [ -d /datacommon/SharedData ]; then
    if [ -f /datacommon/SharedData/mInactive.conf ]; then
      SLOT=$(/data/adb/Dualboot/bootctl get-current-slot)
		  SUFFIX=$(/data/adb/Dualboot/bootctl get-suffix $SLOT)
		  [[ "$SUFFIX" == "_a" ]] && INACTIVE="b" || INACTIVE="a"
		  DATA_BLKID=$(blkid /dev/block/by-name/userdata_$INACTIVE)
		  [[ "$DATA_BLKID" == *"ext4"* ]] && FSDATA="ext4" || FSDATA="f2fs"
    	while IFS="" read -r i || [ -n "$i" ]; do
      	if [[ $i == *"system"* ]]; then
       	  mount -t $FSDATA /dev/block/by-name/userdata_$INACTIVE /datacommon/DualBoot/InactiveData
      	fi
      	if [[ $i == *"data"* ]]; then
       	  mount -t ext4 /dev/block/by-name/system_$INACTIVE /datacommon/DualBoot/InactiveSystem
      	fi	
    	done < /datacommon/SharedData/mInactive.conf
    fi
fi
#END INACTIVE SLOT MOUNT
exit 0
