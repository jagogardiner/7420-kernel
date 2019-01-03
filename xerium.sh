#!/bin/bash

# XeriumO build script

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

echo -e "${bldcya} Xerium kernel for the S6 ${txtrst}"
echo -e "${bldred} Note: if you are not running as sudo you should be! ${txtrst}"
echo ""

# Set exports for later script use
echo -e "${bldgrn} Setting exports ${txtrst}"
export KERNELDIR=~/xeriumO
export SCRIPTS=~/xeriumO/xscripts
export ARCH=arm64
export CROSS_COMPILE=~/aarch64-linux-android-7.3.2/bin/aarch64-linux-gnu-
echo ""

# Clean up
echo -e "${bldgrn} Clean up ${txtrst}"
sudo make clean
sudo make mrproper
sudo rm -rf out
echo ""

# Prompt the user what they are building for
echo "${bldblu} Please choose your device (g920x, g925x, g920t, g925t) ${txtrst}"
read n
case $n in
    g920x) export device=g920x; export defconfig=zeroflte_defconfig;;
    g925x) export device=g925x; export defconfig=zerolte_defconfig;;
    g920t) export device=g920t; export defconfig=zeroflte_defconfig;;
    g925t) export device=g925t; export defconfig=zerolte_defconfig;;
    *) invalid option;;
esac
mkdir -p ${KERNELDIR}/out/${device}
mkdir -p ${KERNELDIR}/out/${device}/temp
echo ""

while true; do
    read -p "${bldblu} Would you like to build with an experimental ramdisk image? (yes, no) ${txtrst}" yn
    case $yn in
        # Make for flat
        [yes]* ) export ramdisk=${KERNELDIR}/${device}/exp_ramdisk; break;;
        # Make for edge
        [no]* ) export ramdisk=${KERNELDIR}/${device}/ramdisk; break;;
        * ) echo "${bldred} Please answer yes or no! ${txtrst}"; echo "";;
    esac
done

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
if [ -e $KERNELDIR/arch/arm64/boot/Image ]; then
  echo -e "${bldgrn} Making zip for ${device}"
  echo ""

  # Copy files to /out for easier access
  echo -e "${bldgrn} Copying files to ./out ${txtrst}"
  echo ""

  # Copy zImage
  sudo cp $KERNELDIR/arch/arm64/boot/Image $KERNELDIR/out/$device/temp/Image

  # Prompt user if they wish to create a dt.img
  cd ${KERNELDIR}/out/$device/temp
  while true; do
      read -p "${bldblu} Do you want to create a dt.img? (yes, no) ${txtrst}" yn
      case $yn in
          [yes]* ) ${SCRIPTS}/dtbtool -o dt.img -s 2048 -p ${SCRIPTS}/xscripts/dtc/dtc ${KERNELDIR}/arch/arm64/boot/dts/; break;;
          [no]* ) break;;
          * ) echo "${bldred} Please answer yes/no! ${txtrst}"; echo "";;
      esac
  done
  echo ""

  # Pack ramdisk up
  echo -e "${bldgrn} Packing ramdisk ${txtrst}"
  cd ${SCRIPTS}
  ./mkbootfs ${ramdisk} | gzip > ${KERNELDIR}/out/$device/temp/ramdisk.gz
  echo ""

  # Prompt the user if they want to use a stock dt.img, or custom made from earlier.
  echo -e "${bldgrn} Creating boot.img ${txtrst}"
  while true; do
      read -p "${bldblu} Do you want to use a stock or custom built dt.img? (s, c) ${txtrst}" yn
      case $yn in
          # Stock
          [s]* ) ./mkbootimg --kernel ${KERNELDIR}/out/$device/temp/Image --dt ${KERNELDIR}/$device/dt.img --ramdisk ${KERNELDIR}/out/$device/temp/ramdisk.gz --base 0x10000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --pagesize 2048 -o ${KERNELDIR}/out/$device/boot.img; break;;
          # Custom
          [c]* ) ./mkbootimg --kernel ${KERNELDIR}/out/$device/temp/Image --dt ${KERNELDIR}/out/$device/temp/dt.img --ramdisk ${KERNELDIR}/out/$device/temp/ramdisk.gz --base 0x10000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --pagesize 2048 -o ${KERNELDIR}/out/$device/boot.img; break;;
          * ) echo "${bldred} Please answer s/c! ${txtrst}"; echo "";;
      esac
  done
  echo ""

  # Make archive
  echo -e "${bldgrn} Creating flashable .zip ${txtrst}"
  cp -R ${KERNELDIR}/META-INF ${KERNELDIR}/out/${device}/
  cd ${KERNELDIR}/out/${device}
  zip -r xeriumO-${device}-`date +[%d-%m-%y]`.zip . -x \*temp\*
  sudo rm -rf ${KERNELDIR}/out/${device}/temp
  echo -e "${bldcya} DONE! Find the kernel in /out/${device}/*.zip ${txtrst}"
  echo -e "${bldcya} Xerium kernel for the S6 ${txtrst}"
  echo -e "${bldcya} Script made by nysadev ${txtrst}"

else
	echo -e "${bldred} KERNEL DID NOT BUILD! ${txtrst}"
  echo -e "${bldred} Please check the above error messages! ${txtrst}"
  echo -e "${bldred} Note: if you are not running as sudo you should be! ${txtrst}"
fi;

exit 0
