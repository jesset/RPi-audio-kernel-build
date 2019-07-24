#!/bin/bash
set -e
#set -x
export LC_ALL=C
export LANG=C

##  Environment Preparations:
# sudo apt update && sudo apt upgrade -y
# sudo reboot
# sudo apt install -y libncurses5-dev  bc build-essential gcc-aarch64-linux-gnu git unzip bison

################################################################################
############################### EDIT THIS ######################################
################################################################################

## Kernel 4.14 
# kernel_src="git clone -b 'rpi-4.14.y-rt' --depth 1 https://github.com/raspberrypi/linux.git"
# kernel_dir=linux-4.14.git  # must ended with .git
# kernel_config="config-4.14-rt-arm64"
# # patch_rt=''
# patch_others=(
#   kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   usb-dsd-quirks-for-4.14.91.patch
#   kernel-sound-pcm5102a-add-support-for-384k.patch
#   kernel-sound-pcm512x-add-support-for-352k8.patch
#   bcm2835-i2s_samplerate_1536000.patch
# )
# 

# ## Kernel 4.19 
# kernel_src="git clone -b 'rpi-4.19.y-rt' --depth 1 https://github.com/raspberrypi/linux.git"
# kernel_dir=linux-4.19.git  # must ended with .git
# # kernel_config="config-4.19-arm64"
# kernel_config="make bcm2711_defconfig"
# patch_others=(
#   kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
#   usb-dsd-quirks-for-4.19.patch
#   kernel-sound-pcm5102a-add-support-for-384k.patch
#   bcm2835-i2s_samplerate_1536000.patch
# )

## Kernel 4.19 (RT)
kernel_src="git clone -b 'rpi-4.19.y-rt' --depth 1 https://github.com/raspberrypi/linux.git"
kernel_dir=linux-4.19.git  # must ended with .git
kernel_config="config-4.19-arm64-RT"
# kernel_config="make bcm2711_defconfig"
# patch_rt='https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/4.19/patch-4.19.59-rt24.patch.gz'
patch_others=(
  kernel-alsa-support-for-384khz-sample-rates-for-4.14.26.patch
  usb-dsd-quirks-for-4.19.patch
  kernel-sound-pcm5102a-add-support-for-384k.patch
  bcm2835-i2s_samplerate_1536000.patch
)

# Patches ref:
#   1. kernel-alsa-support-for-384khz-sample-rates ( ref: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch )
#   2. USB DAC quirks (ref: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch )
#   3. pcm5102a && pcm512x support (ref: https://github.com/RoPieee/ropieee-kernel)
################################################################################

export USE_CCACHE=true
export CCACHE_DIR=/dev/shm/ccache
export CCACHE_LOGFILE=/dev/shm/ccache.kernelbuild.log
export ARCH=arm64
export CROSS_COMPILE="ccache aarch64-linux-gnu-"

export BOARD=RPI

download_fist(){
  local file="$1"
  local todir="$2"
  # if file not exist in target dir, download it to
  local file_local="${file##*/}"
  if [[ ! -e ${todir}/${file_local} ]] ;then
    # http/https ...
    if echo "${file}" | grep -qP '^(http|https)://';then
      echo "# INFO: downloading ${file_local} to ${todir} ..."
      wget -c -P ${todir} "${file}"
    # git ...
    elif echo "${file}" | grep -qP '^git';then
      echo "# INFO: git clone ${file_local} to ${todir} ..."
      eval "${file} ${file_local}"
      mv "${file_local}" "${kernel_dir}"
    else
      echo "# WARN: ${file_local} not exist in ${todir}, and no way to download, nothing can be done, abort."
      return 1
    fi
  else
    echo "# INFO: ${file_local} already exist in ${todir}, skip."
    return 0
  fi
}

## Ccache setting
if ! test -d ${CCACHE_DIR};then
  mkdir ${CCACHE_DIR}
fi

## kernel source download:
if echo ${kernel_dir} | grep -Pq '\.git$' ;then
  kernel_src_local="${kernel_dir}"
else
  kernel_src_local="${kernel_src##*/}"
fi
if ! test -e ${kernel_src_local};then
  download_fist "${kernel_src}" .
fi

## kernel source decompress && cleanup && cd into:
if echo ${kernel_dir} | grep -Pq '\.git$' ;then
  # git cloned repo ...
  cd ${kernel_dir}
  git checkout .
  git clean -fdX
  git clean -fd
else
  # tar balls ...
  if test -d ${kernel_dir} ;then
      echo "WARN: src dir already exists. wait a few seconds then rm -rf it ..."
      for c in 5 4 3 2 1;do printf ${c}... ; sleep 1;done;echo
      rm -rf ${kernel_dir}

      tar xf ${kernel_src_local}
      cd ${kernel_dir}
  fi
fi


# RT patch, if defined
if [[ -n "${patch_rt}" ]];then
  patch_rt_file="${patch_rt##*/}"
  # if not exist,download it first
  download_fist "${patch_rt}" ..

  if zcat ../${patch_rt_file} | patch --silent -p1 --dry-run  ;then
     zcat ../${patch_rt_file} | patch --silent -p1
     [[ $? == 0 ]] && echo "INFO: patched success : ${patch_rt_file}"
  else
    echo "WARN: RT patch defined, but dry-run failed, aborted."
    sleep 3
    exit 1
  fi
fi

# EXTRA PATCHES
for _patch in ${patch_others[@]}
do
  if patch --silent -p1 --dry-run -i ../${_patch} ;then
    patch --silent -p1           -i ../${_patch}
    [[ $? == 0 ]] && echo "INFO: patched success : ${_patch}"
  else
    echo "WARN: patch dry-run failed, aborted, patch file: ${_patch}"
    sleep 3
  fi
done

make  clean

if [[ ${kernel_config:0:5} == "make " ]];then
  ${kernel_config}
else
  cp ../${kernel_config}  .config
fi
make oldconfig
make menuconfig

./scripts/config --disable DEBUG_INFO
make -j`nproc`

echo "################################################################################"
echo "############################# Build Completed!!! ###############################"
echo "################################################################################"

export kernelrel=$(make -s kernelrelease)

export KERN_INSTALL_HOME=$(mktemp -d `pwd`/buildroot-XXXXXXXX)
mkdir -pv $KERN_INSTALL_HOME/boot/overlays

cp -v  .config $KERN_INSTALL_HOME/boot/config-"${kernelrel}"
cp -v  arch/$ARCH/boot/Image $KERN_INSTALL_HOME/boot/kernel8.img
cp -v  arch/$ARCH/boot/dts/broadcom/*dtb $KERN_INSTALL_HOME/boot/
cp -v  arch/$ARCH/boot/dts/overlays/*.dtbo $KERN_INSTALL_HOME/boot/overlays/
cp -v  arch/$ARCH/boot/dts/overlays/README $KERN_INSTALL_HOME/boot/overlays/ || true

make INSTALL_MOD_PATH=$KERN_INSTALL_HOME modules_install

## build kernel tools(perf ..)
#for tool in gpio iio perf spi usb
#do
#    make DESTDIR=${KERN_INSTALL_HOME}/ -C tools/ ${tool}_install  || true
#
#    # pushd tools/$tool
#    # make DESTDIR=${KERN_INSTALL_HOME}/ install
#    # popd
#done

kerneltarball="../kernelbuild-${kernelrel}-${ARCH}-${BOARD}.tar.xz"
tar cvJpf ${kerneltarball} -C ${KERN_INSTALL_HOME} -- $(ls ${KERN_INSTALL_HOME}) &&  rm -rf ${KERN_INSTALL_HOME}

# make bindeb-pkg -j`nproc`

echo "################################################################################"
echo "########################## DONE, Your kernel tarball: ##########################"
ls -lht $(readlink -f ${kerneltarball})
echo "################################################################################"

