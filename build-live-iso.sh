#!/bin/bash

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
rm -rf config/ *-amd64.*

NAL=noautologin
NAL=
lb config \
	--architectures amd64 --distribution ${DISTRO} --iso-application phonebocx --iso-publisher xrobau --iso-volume phonebocx \
	--archive-areas "main contrib non-free $F" --updates true --security true --backports true \
	--image-name "$BUILD" \
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

# Changes to default bootloader configs are in the livebuild directory.
# They are:
#  syslinux_common/live.cfg.in main menu
#  syslinux_common/menu.cfg Removed ^G beep
#  grub-pc/grub.cfg Rewritten
#  grub-pc/config.cfg changes gfxmode=auto to gfxmode=1024x768x32 and disables the beep

# Put our large (1024x768) live splash in place and make sure there's nothing that would
# clobber it
cp ${LIVESPLASHLARGEPNG} config/bootloaders/syslinux_common/splash.png
cp ${LIVESPLASHLARGEPNG} config/bootloaders/syslinux_common/splash1024x768.png
cp ${LIVESPLASHPNG} config/bootloaders/syslinux_common/splash800x600.png
rm -f config/bootloaders/*/*.svg

# Rsync everything in LIVEBUILDSRC over the top of config. This is checked into
# git, and is the same everywhere.
rsync -a ${LIVEBUILDSRC}/ config/

# Then merge everything from staging over the top of that. This allows
# staging to change things in the default LIVEBUILDROOT
rsync -a ${STAGING}/ config/

# Replace __GRUBNAME__ with $THEME
if [ ! "$GRUBNAME" ]; then
	# Uppercase first char of Theme
	GRUBNAME=${THEME^}
fi
# pxelinux is broken, just remove it
rm -rf config/bootloaders/pxelinux

# Now patch our name
sed -i "s/__GRUBNAME__/$GRUBNAME/g" config/bootloaders/*/*cfg

# Put all our debs in place. This isn't done as part of creating STAGING because
# I didn't want to have to care about ordering everything.
mkdir -p config/packages.chroot
cp ${ISODEBS} config/packages.chroot/
echo "Debs to be injected onto iso:"
ls -l config/packages.chroot/

# Copy our squashed packages into /live/packages on the ISO (only)
mkdir -p config/includes.binary/live/packages
rsync -a ${PKGDESTDIR}/ config/includes.binary/live/packages/

# If we have UEFI binaries, copy them in
if [ "$UEFIBINS" ]; then
	echo "UEFI Binaries: $UEFIBINS"
	mkdir -p config/includes.chroot/boot/EFI
	cp $UEFIBINS config/includes.chroot/boot/EFI
fi

BIOUT=config/includes.binary/distro/buildinfo.json
$ISOCOMPONENTS/gitinfo.php >$BIOUT
cp $BIOUT config/includes.chroot/distro/buildinfo.json

lb build 2>&1 | tee build.log
