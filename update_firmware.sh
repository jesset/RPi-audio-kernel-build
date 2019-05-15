#!/bin/bash
# update firmware to latest version
set -e

if [[ $(whoami) != 'root' ]];then
  echo "Error: Please use sudo "
  exit 1
fi

FW_FILES="bootcode.bin "
FW_FILES+="start.elf start_x.elf start_cd.elf start_db.elf "
FW_FILES+="fixup.dat fixup_x.dat fixup_cd.dat fixup_db.dat "
FW_FILES+="COPYING.linux LICENCE.broadcom "

tmpdir=/dev/shm/firmware
#git clone --depth 1  https://github.com/raspberrypi/firmware.git ${tmpdir}
mkdir ${tmpdir}
for file in ${FW_FILES};do
  wget -c -P ${tmpdir}  https://github.com/raspberrypi/firmware/raw/master/boot/${file}
done

if cd ${tmpdir} ;then
  for file in ${FW_FILES};do
    cp -v ${file} /boot/
  done
fi

sync

echo Done.
