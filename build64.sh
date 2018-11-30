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

git checkout 32f5076d836518eaf2e7b2caa2e6ee196d27210b

#  make bcmrpi3_defconfig

# (EXTRA PATCHES for audio application ...)
#   1. kernel-alsa-support-for-384khz-sample-rates ( ref: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch )
patch -p1 --dry-run -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch && \
patch -p1           -i ../kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   2. USB DAC quirks (ref: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch )
patch -p1 --dry-run -i ../usb-dsd-quirks-for-4.14.patch && \
patch -p1           -i ../usb-dsd-quirks-for-4.14.patch
#   3. pcm5102a && pcm512x support (ref: https://github.com/RoPieee/ropieee-kernel)
patch -p1 --dry-run -i ../kernel-sound-pcm5102a-add-support-for-384k.patch && \
patch -p1           -i ../kernel-sound-pcm5102a-add-support-for-384k.patch
patch -p1 --dry-run -i ../kernel-sound-pcm512x-add-support-for-352k8.patch && \
patch -p1           -i ../kernel-sound-pcm512x-add-support-for-352k8.patch

patch -p1 --dry-run -i ../kernel-usb-native-dsd-generic-detection.patch && \
patch -p1           -i ../kernel-usb-native-dsd-generic-detection.patch
patch -p1 --dry-run -i ../bcm2835-i2s_samplerate_1536000.patch && \
patch -p1           -i ../bcm2835-i2s_samplerate_1536000.patch

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

export KERN_INSTALL_HOME=$(mktemp -d `pwd`/buildroot-XXXXXXXX)
mkdir -pv $KERN_INSTALL_HOME/boot/overlays

cp -v  .config $KERN_INSTALL_HOME/boot/config-"${kernelrel}"
cp -v  arch/$ARCH/boot/Image $KERN_INSTALL_HOME/boot/kernel8.img
cp -v  arch/$ARCH/boot/dts/broadcom/*dtb $KERN_INSTALL_HOME/boot/
cp -v  arch/$ARCH/boot/dts/overlays/*.dtbo $KERN_INSTALL_HOME/boot/overlays/
cp -v  arch/$ARCH/boot/dts/overlays/README $KERN_INSTALL_HOME/boot/overlays/ || true

make INSTALL_MOD_PATH=$KERN_INSTALL_HOME modules_install
make INSTALL_MOD_PATH=$KERN_INSTALL_HOME firmware_install || true # removed in 4.14

# build kernel tools(perf ..)
for tool in gpio iio perf spi usb
do
    make DESTDIR=${KERN_INSTALL_HOME}/ -C tools/ ${tool}_install  || true

    # pushd tools/$tool
    # make DESTDIR=${KERN_INSTALL_HOME}/ install
    # popd
done

kerneltarball=mykernel-"${kernelrel}"-${ARCH}.tar.xz
tar cvJpf ${kerneltarball} -C ${KERN_INSTALL_HOME} -- $(ls ${KERN_INSTALL_HOME}) &&  rm -rf ${KERN_INSTALL_HOME}

echo ""
echo "DONE!"
echo "Your kernel tarball:"
echo ""
ls -lht $(readlink -f ${kerneltarball})

