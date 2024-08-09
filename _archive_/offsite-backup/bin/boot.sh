#!/bin/bash

cd /media/meta/offsite-backup

/usr/bin/git reset --hard >/dev/null
/usr/bin/git pull origin master >/dev/null

[ -e "/dev/mapper/vault-data" ] || {
  cryptsetup isLuks /dev/sda2 && {
    /media/meta/offsite-backup/bin/passkey.sh | cryptsetup open --type luks /dev/sda2 vault-data
  }
}

[ -e "/dev/mapper/vault-data" ] && {
  fgrep -q '/dev/mapper/vault-data' /proc/mounts || {
    mount -o noatime,nodiratime,compress=zstd,commit=15 /dev/mapper/vault-data /media/data
  }
}

source /media/meta/offsite-backup/bin/configure-system.sh
