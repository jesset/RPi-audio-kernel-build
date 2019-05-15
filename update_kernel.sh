#!/bin/bash
set -e
#set -x

if [[ $(whoami) != 'root' ]];then
  echo "Error: Please use sudo "
  exit 1
fi

kerneltarb=$(readlink -f $1)

if [[ x == x$kerneltarb ]] || ! test -f $kerneltarb ;then
 echo "Usage: $0 /path/to/kernel.tarball"
 exit
fi

# echo "INFO: backuping old kernel...."
oldkerver=`uname -r`
cp -av /boot/kernel8.img  /boot/kernel8.img.PREV."${oldkerver}"

echo "INFO: extracting new kernel...."
cd / && tar --no-same-owner  -xf $kerneltarb

sync
sync

echo Done.
