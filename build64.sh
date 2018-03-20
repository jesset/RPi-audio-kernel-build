#!/bin/bash

set -e
set -x
export LC_ALL=C
export LANG=C

##  Environment Preparations:
# sudo apt update && sudo apt upgrade -y
# sudo reboot
# sudo apt install -y libncurses5-dev  bc build-essential gcc-aarch64-linux-gnu git unzip


## Sources:
_commit=4d78845fd711bdd7c0f20aafb3c976073d86b4e3

#  git clone -b 'rpi-4.14.y' --depth 100 https://github.com/raspberrypi/linux.git
#  cd linux
#  git checkout ${_commit}
#
#  OR:
#
if ! test -e "${_commit}.tar.gz" ;then
  wget -c "https://github.com/raspberrypi/linux/archive/${_commit}.tar.gz"
fi
if ! test -d "linux-${_commit}" ;then
  tar xf ${_commit}.tar.gz
fi
cd linux-${_commit}


#  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcmrpi3_defconfig

# (ksoftirqd rollback before RT patch ...) MUST!!!
patch -p1 --dry-run -i ../4cd13c21b207e80ddb1144c576500098f2d5f882.patch && \
patch -p1           -i ../4cd13c21b207e80ddb1144c576500098f2d5f882.patch

# (RT patch ...)
export rt_patch="patch-4.14.27-rt21.patch.xz"
wget -c -P .. https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/4.14/${rt_patch}
xzcat ../${rt_patch} | patch -p1 --dry-run && \
xzcat ../${rt_patch} | patch -p1

# (EXTRA PATCHES for audio application ...)
#   1. kernel-alsa-support-for-384khz-sample-rates ( ref: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch )
patch -p1 --dry-run -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch && \
patch -p1           -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   2. USB DAC quirks (ref: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch )
patch -p1 --dry-run -i ../usb-dsd-quirks-for-4.14.26.patch && \
patch -p1           -i ../usb-dsd-quirks-for-4.14.26.patch



cp -v ../config-4.14.26-rt19-v8+-arm64 .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-  oldconfig
# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-  menuconfig
#     set Kernel Features -> Preemption Model = Fully Preemptible Kernel (RT)
#     set Kernel Features -> Timer frequency = 1000 Hz



make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-  clean
./scripts/config --disable DEBUG_INFO
make -j`nproc` ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

echo "#########################################################"
echo "############# Build Completed!!! ########################"
echo "#########################################################"

export kernelrel=$(make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -s kernelrelease)

export KERN_INSTALL_HOME=$(mktemp -d ./buildroot-XXXXXXXX)
mkdir -pv $KERN_INSTALL_HOME/boot/overlays

cp -v  arch/arm64/boot/Image $KERN_INSTALL_HOME/boot/kernel8.img
cp -v  .config $KERN_INSTALL_HOME/boot/config-"${kernelrel}"
cp -v  arch/arm64/boot/dts/broadcom/*dtb $KERN_INSTALL_HOME/boot/
cp -v  arch/arm64/boot/dts/overlays/*.dtbo $KERN_INSTALL_HOME/boot/overlays/
cp -v  arch/arm64/boot/dts/overlays/README $KERN_INSTALL_HOME/boot/overlays/ || true

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=$KERN_INSTALL_HOME modules_install
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=$KERN_INSTALL_HOME firmware_install || true # removed in 4.14

kerneltarball=mykernel-"${kernelrel}"-arm64.tgz
tar cvzpf ${kerneltarball} -C ${KERN_INSTALL_HOME} -- boot lib  &&  rm -rf ${KERN_INSTALL_HOME}

echo ""
echo "DONE!"
echo "Your kernel tarball:"
echo ""
ls -lht $(readlink -f ${kerneltarball})
