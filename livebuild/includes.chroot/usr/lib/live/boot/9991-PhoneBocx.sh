#!/bin/sh

PhoneBocx() {
  # This finds the loop device that '/root/run/live/rootfs/xxxxxx.squashfs' is using
  r=$(grep squashfs /proc/mounts | grep -v overlay | grep run/live/root | cut -d\  -f1)
  if [ ! "$r" ]; then
    log_warning_msg "Can not find root loopback"
    return
  fi
  # get_backing file returns /root/run/live/medium/boot/xxxxxxx/xxxxxxxx.squashfs
  d=$(dirname $(get_backing_file $r))
  if [ ! "$d" ]; then
    log_warning_msg "Can not find backing file for $r"
    return
  fi

  # Now we know that d is where the build is - /root/run/live/medium/boot/xxxxxxx
  pdir=$d/packages
  fdir=$d/factory
  mroot=$(find_mount $d)

  # Have we been asked to revert?
  if grep -q ' revert' /proc/cmdline; then
    if [ ! "$mroot" ]; then
      echo "ERROR: Can't find mountroot to revert packages!" >/dev/console
      log_warning_msg "Can not find mountroot, can not revert"
    else
      mount -o remount,rw $mroot
      echo "Reverting all packages to defaults!" >/dev/console
      log_begin_msg Reverting all packages to Released builds
      rm -rf $pdir.revert
      mv $pdir $pdir.revert
      mkdir $pdir
      for f in $fdir/*; do
        ln $f $pdir/$(basename $f)
      done
    fi
  fi

  tbase=/root/pbx
  if [ -d "$pdir" ]; then
    # If there are any new.*.sha256 files, move them into place
    # now, before they're mounted. The file will only be there if
    # the download was successfully completed
    for n in $pdir/new.*.sha256; do
      if [ -e $n ]; then
        # Wildcard
        mount -o remount,rw $mroot
        w=$(echo $n | sed 's/.sha256//')
        for x in ${w}*; do
          i=$(echo $x | sed 's/new.//')
          rm -f $i
          mv $x $i
        done
      fi
    done
    # Nuke any old things that were partially downloaded and not
    # picked up by the move above
    rm -rf $pdir/new.*

    # If we had mounted it rw, put it back.
    mount -o remount,ro $mroot

    for s in $pdir/*squashfs; do
      p=$(basename $s | sed 's/.squashfs$//')
      ignore=$(echo $p | grep -E '^(old|new)\.')
      if [ "$ignore" ]; then
        continue
      fi
      log_begin_msg Mounting $s on $tbase/$p
      mkdir -p $tbase/$p
      mount $s $tbase/$p
      log_end_msg
    done
    # Make sure that core is mounted.
    if ! grep -q $tbase/core /proc/mounts; then
      log_warning_msg "Core is not mounted! Recovery needed!"
      if [ ! -e $d/factory/core.squashfs ]; then
        log_warning_msg "$d/factory/core.squashfs does not exist, can not use it to recover"
      else
        log_begin_msg Mounting RECOVERY $d/factory/core.squashfs on $tbase/core
        mkdir -p $tbase/core
        mount $d/factory/core.squashfs $tbase/core
        log_end_msg
      fi
    fi
  fi
  if [ ! -e $tbase/core/meta/hooks/initrd ]; then
    log_warning_msg "Can not find core initrd hook"
    return
  fi
  log_begin_msg "Running core initrd hook '$tbase/core/meta/hooks/initrd'"
  . $tbase/core/meta/hooks/initrd
  log_end_msg
  for h in $tbase/*/meta/hooks/initrd; do
    if [ "$h" == "$tbase/core/meta/hooks/initrd" ]; then
      continue
    fi
    log_begin_msg "Running initrd hook $h"
    . $h
    log_end_msg
  done
}

get_backing_file() {
  l=$(echo $1 | sed 's_/dev/__')
  bf=/sys/block/$l/loop/backing_file
  if [ ! -e $bf ]; then
    log_warning_msg "Can not find backing file $bf"
    return
  fi
  cat $bf
}

# Iterate through /var/lib/blah/foop/wibble/herp until we
# find the root mountpoint of it. This is used to find
# /run/live/medium from /run/live/medium/boot/xxxx/blah.squashfs
find_mount() {
  local x=$1
  while :; do
    m=$(grep " $x " /proc/mounts)
    if [ "$m" ]; then
      echo $x
      return
    fi
    x=$(dirname $x)
    if [ ! "$x" ]; then
      return
    fi
  done
}
