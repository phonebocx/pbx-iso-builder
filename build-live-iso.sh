#!/bin/bash

buildnum=1
BUILD="$BRANCH-$(printf "%03d" $buildnum)"
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

mkdir -p ${ISOBUILDROOT}
echo "in ${ISOBUILDROOT}"

cd ${ISOBUILDROOT}
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

# Copy the default system bootloaders in place.
for x in /usr/share/live/build/bootloaders/*; do
	rsync -a $x config/bootloaders
done

# Changes to default bootloader configs are in the liveconf directory.
# They are:
#  syslinux_common/live.cfg.in main menu
#  syslinux_common/menu.cfg Removed ^G beep
#  grub-pc/grub.cfg Adds set timeout=5
#  grub-pc/config.cfg changes gfxmode=auto to gfxmode=1024x768x32 and disables the beep

# Put our large (1024x768) live splash in place and make sure there's nothing that would
# clobber it
cp ${LIVESPLASHLARGEPNG} config/bootloaders/syslinux_common/splash.png
rm -f config/bootloaders/*/*.svg

# Rsync everything in LIVEBUILDSRC over the top of config. This is checked into
# git, and is the same everywhere.
rsync -a ${LIVEBUILDSRC}/ config/

# Then merge everything from staging over the top of that. This allows
# staging to change things in the default LIVEBUILDROOT
rsync -a ${STAGING}/ config/

# Put all our debs in place. This isn't done as part of creating STAGING because
# I didn't want to have to care about ordering everything.
mkdir -p config/packages.chroot
cp ${ISODEBS} config/packages.chroot/
echo "Debs to be injected onto iso:"
ls -l config/packages.chroot/

# Copy our squashed packages into /live/ on the ISO (only)
mkdir -p config/includes.binary/live
rsync -a ${PKGDESTDIR}/ config/includes.binary/live

# If we have UEFI binaries, copy them in
if [ "$UEFIBINS" ]; then
	echo "UEFI Binaries: $UEFIBINS"
	mkdir -p config/includes.chroot/boot/EFI
	cp $UEFIBINS config/includes.chroot/boot/EFI
fi

BIOUT=config/includes.binary/distro/buildinfo.json
$COMPONENTS/gitinfo.php >$BIOUT
cp $BIOUT config/includes.chroot/distro/buildinfo.json

lb build 2>&1 | tee build.log
