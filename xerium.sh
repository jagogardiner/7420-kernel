#!/bin/bash

# XeriumO build script

echo -e "${bldcya} Xerium kernel for the S6 ${txtrst}"
echo -e "${bldred} Note: if you are not running as sudo you should be! ${txtrst}"
echo ""

# Colorize and add text parameters
red=$(tput setaf 1) # red
grn=$(tput setaf 2) # green
cya=$(tput setaf 6) # cyan
txtbld=$(tput bold) # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgrn=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
bldcya=${txtbld}$(tput setaf 6) # cyan
txtrst=$(tput sgr0) # Reset

# Set exports for later script use
echo -e "${bldgrn} Setting exports ${txtrst}"
export KERNELDIR=/home/nysadev/xeriumO/
export SCRIPTS=/home/nysadev/xeriumO/xscripts
export ARCH=arm64
export CROSS_COMPILE=/home/nysadev/aarch64-linux-android-5.x/bin/aarch64-linux-android-
echo ""

# Clean up
echo -e "${bldgrn} Clean up ${txtrst}"
make clean
make mrproper
rm -rf out
echo ""

# Prompt the user what they are building for
while true; do
    read -p "${bldblu} What device are you building for? (flat, edge) ${txtrst}" yn
    case $yn in
        # Make for flat
        [flat]* ) export device=flat; export defconfig=flat_defconfig; break;;
        # Make for edge
        [edge]* ) export device=edge; export defconfig=edge_defconfig; break;;
        * ) echo "${bldred} Please answer flat or edge! ${txtrst}"; echo "";;
    esac
done
echo ""

# Make configuration
echo -e "${bldgrn} Making configuration ${txtrst}"
make $defconfig
echo ""

# Make kernel
export cores=$(nproc --all)
echo -e "${bldgrn} Making Xerium Kernel with ${cores} cores  ${txtrst}"
make -j$(nproc --all)
echo ""

# Check for zImage, then compile into boot.img
if [[ -a arch/arm64/boot/zImage ]]; then
  echo -e "${bldgrn} Making zip for ${device}"
  echo ""

  # Copy files to /out for easier access
  echo -e "${bldgrn} Copying files to ./out ${txtrst}"
  mkdir -p /out/system/lib/modules
  echo ""

  # Copy zImage
  cp /arch/arm64/boot/zImage /out/zImage

  # Copy all modules if compiled
  find -name '*.ko' | xargs -I {} cp {} ./out/system/lib/modules/

  # Prompt user if they wish to create a dt.img
  cd ${KERNELDIR}/out
  while true; do
      read -p "${bldblu} Do you want to create a dt.img? (yes, no) ${txtrst}" yn
      case $yn in
          [yes]* ) ${SCRIPTS}/dtbtool -o dt.img -s 2048 -p ./scripts/dtc/dtc ./arch/arm64/boot/dts/; break;;
          [no]* ) break;;
          * ) echo "${bldred} Please answer yes/no! ${txtrst}"; echo "";;
      esac
  done
  echo ""

  # Pack ramdisk up
  echo -e "${bldgrn} Packing ramdisk ${txtrst}"
  cd ${SCRIPTS}
  ./mkbootfs ${KERNELDIR}/${device}/ramdisk | gzip > ${KERNELDIR}/out/ramdisk.gz
  echo ""

  # Prompt the user if they want to use a stock dt.img, or custom made from earlier.
  echo -e "${bldgrn} Creating boot.img ${txtrst}"
  while true; do
      read -p "${bldblu} Do you want to use a stock or custom built dt.img? (s, c) ${txtrst}" yn
      case $yn in
          # Stock
          [s]* ) ./mkbootimg --kernel ${KERNELDIR}/out/zImage --dt ${KERNELDIR}/dt.img --ramdisk ${KERNELDIR}/out/ramdisk.gz --base 0x10000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --pagesize 2048 -o ${KERNELDIR}/out/boot.img; break;;
          # Custom
          [c]* ) ./mkbootimg --kernel ${KERNELDIR}/out/zImage --dt ${KERNELDIR}/out/dt.img --ramdisk ${KERNELDIR}/out/ramdisk.gz --base 0x10000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --pagesize 2048 -o ${KERNELDIR}/out/boot.img; break;;
          * ) echo "${bldred} Please answer s/c! ${txtrst}"; echo "";;
      esac
  done
  echo ""

  # Make archive
  echo -e "${bldgrn} Creating flashable .zip ${txtrst}"
  mkdir -p ${KERNELDIR}/out/${device}
  cp -R ${KERNELDIR}/META-INF ${KERNELDIR}/out/${device}
  cp -R ${KERNELDIR}/out/boot.img ${KERNELDIR}/out/${device}

  cd ${KERNELDIR}/out/${device}
  zip -r xeriumO-${device}-`date +[%d-%m-%y]`.zip .

  echo -e "${bldcya} DONE! Find the kernel in /out/${device}/*.zip ${txtrst}"
  echo -e "${bldcya} Xerium kernel for the S6 ${txtrst}"
  echo -e "${bldcya} Script made by nysadev ${txtrst}"

else
	echo -e "${bldred} KERNEL DID NOT BUILD! ${txtrst}"
  echo -e "${bldred} Please check the above error messages! ${txtrst}"
  echo -e "${bldred} Note: if you are not running as sudo you should be! ${txtrst}"
fi;

exit 0
