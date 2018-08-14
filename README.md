# Build ARM64 real-time kernel for low-latency music play on RPi

- RT kernel
- arm64/aarch64
- minimalized kernel modules/features for high quality audio playback
    * disable IPv6/Netfilter/serial modules ... (not needed by audio playback, basically)
    * Support PCM 352k8 and 384k sample rates [1]
    * Support More USB DAC (native DSD) [2]
- only support Raspberry Pi 3 Model B/B+
- only support ext2/3/4/vfat/xfs filesystem

# How to Build

    # 1. prepare a Ubuntu 16.04 x86_64 install, upgrade, and get build tools.
    sudo apt update && sudo apt upgrade -y
    sudo reboot
    sudo apt install -y libncurses5-dev  bc build-essential gcc-aarch64-linux-gnu git unzip ccache

    # 2. build kernel
    git clone https://github.com/jesset/RPi-audio-kernel-build.git
    cd RPi-audio-kernel-build
    ./build64.sh
    # or, add a localversion
    export LOCALVERSION=-my-r1 ; ./build64.sh

    # 3. install kernel tarball
    # copy kernel tarball to RPi ...
    sudo -i
    cd / && tar --no-same-owner -xf /path/to/mykernel-XYZ-arm64.tar.xz

    # 4. upgrade firmware (optional)
    git clone --depth 1 https://github.com/raspberrypi/firmware.git
    cd firmware
    sudo cp -v start*.elf fixup*.dat bootcode.bin LICENCE.broadcom  /boot/


# Ref

https://isojed.nl/blog/2017/10/25/raspberry-pi-rt-preempt/

https://www.raspberrypi.org/documentation/linux/kernel/building.md

https://medium.com/@metebalci/latency-of-raspberry-pi-3-on-standard-and-real-time-linux-4-9-kernel-2d9c20704495

https://devsidestory.com/build-a-64-bit-kernel-for-your-raspberry-pi-3/

https://github.com/RoPieee/ropieee-kernel.git

[1]: https://github.com/DigitalDreamtimeLtd/linux/commit/6224bb2a856146111815a1215732cad18df1d016.patch

[2]: https://github.com/RoPieee/ropieee-kernel/blob/master/usb-dsd-quirks.patch
