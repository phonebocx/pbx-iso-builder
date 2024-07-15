#!/bin/sh

PhoneBocx() {
  r=$(grep squashfs /proc/mounts | grep -v overlay | grep run/live/root | cut -d\  -f1)
  if [ ! "$r" ]; then
    log_warning_msg "Can not find root"
    return
  fi
  d=$(dirname $(get_backing_file $r))
  if [ ! "$d" ]; then
    log_warning_msg "Can not find backing file for $r"
    return
  fi

  mount_spool

  pdir=$d/packages
  tbase=/root/pbx
  if [ -d "$pdir" ]; then
    # If there are any new.*.sha256 files, move them into place
    # now, before they're mounted. The file will only be there if
    # the download was successfully completed
    for n in $pdir/new.*.sha256; do
      if [ -e $n ]; then
        # Wildcard
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
      continue;
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

mount_spool() {
  # If this is not a live boot, mount /spool
  if ! grep -q BOOT_IMAGE=/live /proc/cmdline; then
    sdev=$(blkid --label fe018191bdc0)
    if [ "$sdev" ]; then
      mkdir -p /root/spool
      mount $sdev /root/spool
    fi
  fi
}


