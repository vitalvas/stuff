# Install

## Install packages

```shell
apt update -qy
apt upgrade -qy

apt install -qy xfsprogs btrfs-progs btrfs-compsize git udev cryptsetup parted
```

## Prepare disk

```shell
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart primary 0% 64G
parted -s /dev/sda mkpart primary 64G 100%
parted -s /dev/sda align-check optimal 1
parted -s /dev/sda align-check optimal 2
```

```shell
mkfs.xfs -L vault-meta -f /dev/sda1

mkdir -p /media/{meta,data}

chattr +i /media/meta
chattr +i /media/data
chattr +i /media
```

## Install app

```shell
systemd-mount -t xfs /dev/sda1 /media/meta/

git clone https://github.com/vitalvas/offsite-backup.git /media/meta/offsite-backup/
```

## Encrypted disk

```shell
/media/meta/offsite-backup/bin/passkey.sh | cryptsetup --batch-mode luksFormat /dev/sda2
/media/meta/offsite-backup/bin/passkey.sh | cryptsetup open --type luks /dev/sda2 vault-data
```

```shell
mkfs.btrfs --data single --metadata single --label vault /dev/mapper/vault-data
```

```shell
mount -o noatime,nodiratime,compress=zstd,commit=15 /dev/mapper/vault-data /media/data
```
