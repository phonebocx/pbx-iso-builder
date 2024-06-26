#!/bin/bash

buildnum=1
BUILD="$BRANCH-$(printf "%03d" $buildnum)"
WORKSPACE=src/live-build-workspace
DISTRO=bookworm

echo -n "Creating $BUILD with kernel ${KERNELVER} - Debian $DISTRO "

if [ "$WITH_FIRMWARE" ]; then
	echo -n "with non-free firmware "
	F=non-free-firmware
else
	F=
	export LB_FIRMWARE_CHROOT=false
	export LB_FIRMWARE_BINARY=false
fi

mkdir -p ${WORKSPACE}
echo "in ${WORKSPACE}"

cd ${WORKSPACE}
lb clean
rm -rf config/ live-image-amd64.*

NAL=noautologin
NAL=

lb config \
        --architectures amd64 --distribution ${DISTRO} --iso-application phonebocx --iso-publisher xrobau --iso-volume phonebocx \
        --archive-areas "main contrib non-free $F" --updates true --security true --backports true \
        --initsystem systemd --memtest memtest86+ --debootstrap-options "--include=apt-transport-https,ca-certificates" \
        --bootappend-live "boot=live hostname=phonebocx ${NAL} union=overlay console=ttyS0,115200 console=tty0 net.ifnames=0 biosdevname=0 nomodeset" \
       	--bootappend-live-failsafe none \
       	--linux-packages linux-image-${KERNELVER} \
       	--linux-flavours ${KERNELREL} \
       	--debootstrap-options "--include=apt-transport-https,ca-certificates"

if [ "$DEBMIRROR" ]; then
	sed -i 's!http://deb.debian.org/debian/!'${DEBMIRROR}'!g' config/bootstrap
fi

mkdir -p config/bootloaders

for x in /usr/share/live/build/bootloaders/*; do
	rsync -a $x config/bootloaders
done

# Put our splash in place to replace the original
cp ${SPLASHSVG} config/bootloaders/syslinux_common/splash.svg

# Merge anything we've put in liveconf across
rsync -av ${LIVECONF}/ config/

# Put our kernel debs in place
mkdir -p config/packages.chroot
cp ${KERNELDEBS} config/packages.chroot/

UF=${UNIFONTDEST}
if [ ! -e $UF ]; then
	echo Unifont file $UF does not exist, fix the makefile
	exit
fi

mkdir -p config/includes.chroot/usr/share/fonts/truetype/
cp $UF config/includes.chroot/usr/share/fonts/truetype/

#lb build 2>&1 | tee build.log
sed -i "s/Live system/PhoneBo.cx ($BUILD)/" config/bootloaders/*/live.cfg.in
sed -i '2 i set timeout=5' config/bootloaders/grub-pc/grub.cfg
sed -i 's/gfxmode=auto/gfxmode=1024x768x32/' config/bootloaders/grub-pc/*.cfg

# Disable beep.
set -i 's/^play/#play/g' config/bootloaders/grub-pc/*.cfg

lb build 2>&1 | tee build.log

exit

