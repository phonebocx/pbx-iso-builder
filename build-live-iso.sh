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

# Changes to default bootloader configs are in liveconf.
#  syslinux_common/live.cfg.in main menu
#  syslinux_common/menu.cfg Removed ^G beep
#  grub-pc/grub.cfg Adds set timeout=5
#  grub-pc/config.cfg changes gfxmode=auto to gfxmode=1024x768x32 and disables the beep

# Put our splash in place, which is updated on every build
cp ${SPLASHSVG} config/bootloaders/syslinux_common/splash.svg

# Import our additional repositories
cp ../*.list.* ../*.key.* config/archives

# Put the phonebocx source file inplace for testing
srcdest=config/includes.chroot/etc/apt/sources.list.d
mkdir -p $srcdest
cp ../phonebocx.sources $srcdest

# Merge anything we've put in liveconf across, which also overwrites
# some of the bootloader config files
rsync -av ${LIVECONF}/ config/

# Put all our debs in place
mkdir -p config/packages.chroot
cp ${ISODEBS} config/packages.chroot/
echo "Debs to be injected onto iso:"
ls -l config/packages.chroot/

UF=${UNIFONTDEST}
if [ ! -e $UF ]; then
	echo Unifont file $UF does not exist, fix the makefile
	exit
fi

mkdir -p config/includes.chroot/usr/share/fonts/truetype/
cp $UF config/includes.chroot/usr/share/fonts/truetype/

# Now merge the pbxboot directory in
rsync -av ../../pbxboot/ config/

# The immutable packages are only in the iso, not the live image. They're
# placed in the 'live' folder so the 9991 initram hook can find them.
mkdir -p config/includes.binary/live
rsync -av ../packages config/includes.binary/live

# If we have UEFI binaries, copy them in
if [ "$UEFIBINS" ]; then
	echo "UEFI Binaries: $UEFIBINS"
	mkdir -p config/includes.chroot/boot/EFI
	cp $UEFIBINS config/includes.chroot/boot/EFI
fi

# And finally the theme
rsync -av ${THEMEDESTDIR}/ config/

# And the buildinfo
BIOUT=config/includes.binary/live/buildinfo.json
../../components/gitinfo.php > $BIOUT
cp $BIOUT config/includes.chroot/etc/buildinfo.json

lb build 2>&1 | tee build.log

