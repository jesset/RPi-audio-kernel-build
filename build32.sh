#!/bin/bash

set -e
set -x
export LC_ALL=C
export LANG=C

##  Environment Preparations:
# sudo apt update && sudo apt upgrade -y
# sudo reboot
# sudo apt-get install libncurses5-dev bc build-essential


## toolkit
test -d ~/tools || git clone https://github.com/raspberrypi/tools.git ~/tools

export KERNEL=kernel7
export ARCH=arm
export CONCURRENCY_LEVEL=$(nproc)
export CROSS_COMPILE=~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-
# echo 'PATH=$PATH:~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin' >> ~/.bashrc
# source ~/.bashrc


## Sources:
_commit=ad350a581a442f790b54abb81364295e937fe26b

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


# (ksoftirqd rollback before RT patch ...) MUST!!!
patch -p1 --dry-run -i ../4cd13c21b207e80ddb1144c576500098f2d5f882.patch && \
patch -p1           -i ../4cd13c21b207e80ddb1144c576500098f2d5f882.patch

# (RT patch ...)
wget -c -P .. https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/4.14/patch-4.14.24-rt19.patch.xz
xzcat ../patch-4.14.24-rt19.patch.xz | patch -p1 --dry-run && \
xzcat ../patch-4.14.24-rt19.patch.xz | patch -p1

# (EXTRA PATCHES for audio application ...)
#   1. kernel-alsa-support-for-384khz-sample-rates ( ref: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch )
patch -p1 --dry-run -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch && \
patch -p1           -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   2. USB DAC quirks (ref: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch )
patch -p1 --dry-run -i ../usb-dsd-quirks-for-4.14.patch && \
patch -p1           -i ../usb-dsd-quirks-for-4.14.patch


# make bcm2709_defconfig
# cp -v ../config-4.14.26-rt19-v8+ .config
cp -v ../config-4.14.26-rt19-v8+-armhf .config
make oldconfig
# make  menuconfig
#     set Kernel Features -> Preemption Model = Fully Preemptible Kernel (RT)
#     set Kernel Features -> Timer frequency = 1000 Hz


make clean
./scripts/config --disable DEBUG_INFO
make -j$(nproc)
# make -j$(nproc) deb-pkg
# make -j$(nproc) targz-pkg


echo "#########################################################"
echo "############# Build Completed!!! ########################"
echo "#########################################################"

export kernelrel=$(make -s kernelrelease)

export KERN_INSTALL_HOME=$(mktemp -d ./buildroot-XXXXXXXX)
mkdir -pv $KERN_INSTALL_HOME/boot/overlays

cp -v  arch/arm/boot/Image $KERN_INSTALL_HOME/boot/kernel7.img
cp -v  .config $KERN_INSTALL_HOME/boot/config-"${kernelrel}"
cp -v  arch/arm/boot/dts/*dtb $KERN_INSTALL_HOME/boot/
cp -v  arch/arm/boot/dts/overlays/*.dtbo $KERN_INSTALL_HOME/boot/overlays/
cp -v  arch/arm/boot/dts/overlays/README $KERN_INSTALL_HOME/boot/overlays/ || true

make INSTALL_MOD_PATH=$KERN_INSTALL_HOME modules_install
make INSTALL_MOD_PATH=$KERN_INSTALL_HOME firmware_install || true # removed in 4.14

kerneltarball=mykernel-"${kernelrel}"-armhf.tgz
tar cvzpf ${kerneltarball} -C ${KERN_INSTALL_HOME} -- boot lib  &&  rm -rf ${KERN_INSTALL_HOME}

echo ""
echo "DONE!"
echo "Your kernel tarball:"
echo ""
ls -lht $(readlink -f ${kerneltarball})
