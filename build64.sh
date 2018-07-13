#!/bin/bash

set -e
set -x
export LC_ALL=C
export LANG=C

export USE_CCACHE=true
export CCACHE_DIR=/tmp/ccache.rpikernelrt
export CCACHE_LOGFILE=/tmp/ccache.rpikernelrt/ccache.log
export ARCH=arm64
export CROSS_COMPILE="ccache aarch64-linux-gnu-"

##  Environment Preparations:
# sudo apt update && sudo apt upgrade -y
# sudo reboot
# sudo apt install -y libncurses5-dev  bc build-essential gcc-aarch64-linux-gnu git unzip

## Sources:
if test -d linux;then
  cd linux && git checkout . &&  git clean -fdX
else
  git clone -b 'rpi-4.14.y-rt' --depth 1 https://github.com/raspberrypi/linux.git
  cd linux
fi

git checkout 36674db1d99952eb722669a69a659d6ba082847d

#  make bcmrpi3_defconfig

# (EXTRA PATCHES for audio application ...)
#   1. kernel-alsa-support-for-384khz-sample-rates ( ref: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch )
patch -p1 --dry-run -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch && \
patch -p1           -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   2. USB DAC quirks (ref: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch )
patch -p1 --dry-run -i ../usb-dsd-quirks-for-4.14.patch && \
patch -p1           -i ../usb-dsd-quirks-for-4.14.patch


cp -v ../config-4.14-rt-${ARCH} .config
make oldconfig
make menuconfig
#     set Kernel Features -> Preemption Model = Fully Preemptible Kernel (RT)
#     set Kernel Features -> Timer frequency = 1000 Hz



make  clean
./scripts/config --disable DEBUG_INFO
make -j`nproc`

echo "#########################################################"
echo "############# Build Completed!!! ########################"
echo "#########################################################"

export kernelrel=$(make -s kernelrelease)

export KERN_INSTALL_HOME=$(mktemp -d ./buildroot-XXXXXXXX)
mkdir -pv $KERN_INSTALL_HOME/boot/overlays

cp -v  .config $KERN_INSTALL_HOME/boot/config-"${kernelrel}"
cp -v  arch/$ARCH/boot/Image $KERN_INSTALL_HOME/boot/kernel8.img
cp -v  arch/$ARCH/boot/dts/broadcom/*dtb $KERN_INSTALL_HOME/boot/
cp -v  arch/$ARCH/boot/dts/overlays/*.dtbo $KERN_INSTALL_HOME/boot/overlays/
cp -v  arch/$ARCH/boot/dts/overlays/README $KERN_INSTALL_HOME/boot/overlays/ || true

make INSTALL_MOD_PATH=$KERN_INSTALL_HOME modules_install
make INSTALL_MOD_PATH=$KERN_INSTALL_HOME firmware_install || true # removed in 4.14

kerneltarball=mykernel-"${kernelrel}"-${ARCH}.tgz
tar cvzpf ${kerneltarball} -C ${KERN_INSTALL_HOME} -- boot lib  &&  rm -rf ${KERN_INSTALL_HOME}

echo ""
echo "DONE!"
echo "Your kernel tarball:"
echo ""
ls -lht $(readlink -f ${kerneltarball})

