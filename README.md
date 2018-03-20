# Build ARM64 real-time kernel for low-latency music play on RPi

- RT kernel
- 64bit
- Currently only support Raspberry Pi 3 Model B
- minimalized kernel modules/features for high quality audio playback

# How to Build

    # 1. prepare a Ubuntu 16.04 x86_64 install, upgrade, and get build tools.
    sudo apt update && sudo apt upgrade -y
    sudo reboot
    sudo apt install -y libncurses5-dev  bc build-essential gcc-aarch64-linux-gnu git unzip

    # 2. build kernel
    ./build-arm64-rt-kernel-for-rpi3.sh

    # 3. install kernel tarball
    # copy kernel tarball to RPi ...
    sudo -i
    cd / && tar --no-same-owner -xf /path/to/kernel_tarball

    # 4. upgrade firmware (optional)
    git clone https://github.com/raspberrypi/firmware.git
    cd firmware
    sudo cp -v start*.elf fixup*.dat bootcode.bin LICENCE.broadcom  /boot/

# Ref

https://isojed.nl/blog/2017/10/25/raspberry-pi-rt-preempt/
https://www.raspberrypi.org/documentation/linux/kernel/building.md
https://medium.com/@metebalci/latency-of-raspberry-pi-3-on-standard-and-real-time-linux-4-9-kernel-2d9c20704495

https://devsidestory.com/build-a-64-bit-kernel-for-your-raspberry-pi-3/
