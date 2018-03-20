#!/bin/bash
set -e
#set -x

kerneltarb=$(readlink -f $1)

if [[ x == x$kerneltarb ]] || ! test -f $kerneltarb ;then
 echo "Usage: $0 /path/to/kernel.tarball"
 exit
fi

echo "INFO: backuping old kernel...."
kerver=`uname -r`
cp -av /boot/kernel8.img  /boot/kernel8.img.prev."${kerver}"

echo "INFO: extracting new kernel...."
cd / && tar --no-same-owner  -xf $kerneltarb

sync
sync
sync

echo Done.
