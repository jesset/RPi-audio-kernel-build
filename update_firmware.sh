#!/bin/bash
set -e
#set -x

firmwaretarball=$(readlink -f $1)

if [[ x == x$firmwaretarball ]] || ! test -f $firmwaretarball ;then
 exit
fi

echo "INFO: extracting new firmware ...."
cd /boot && tar --no-same-owner  -xf $firmwaretarball

sync
sync
sync

echo Done.
