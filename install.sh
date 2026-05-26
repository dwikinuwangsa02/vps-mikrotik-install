#!/usr/bin/env bash

# Must be root !
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Preparation ..."
apt update && apt install unzip wget -y

# Menggunakan versi pilihanmu
CHR_VERSION=7.22.3

# Mengambil informasi sistem otomatis
DISK=$(lsblk | grep "disk" | head -n 1 | cut -d' ' -f1)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
INTERFACE_IP=$(ip addr show $INTERFACE | grep global | cut -d' ' -f 6 | head -n 1)
INTERFACE_GATEWAY=$(ip route show | grep default | awk '{print $3}')

# Trik anti-corrupt: Jalankan proses dari RAMdisk
mkdir /tmp/ramdisk
mount -t tmpfs -o size=256M tmpfs /tmp/ramdisk
cd /tmp/ramdisk

echo "Downloading MikroTik CHR v${CHR_VERSION}..."
wget -qO routeros.zip https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip && \
unzip routeros.zip && \
rm -rf routeros.zip

# Menyuntikkan konfigurasi IP otomatis agar MikroTik langsung online
mkdir /mnt/mikrotik
mount -o loop,offset=512 chr-$CHR_VERSION.img /mnt/mikrotik

echo "/ip address add address=${INTERFACE_IP} interface=[/interface ethernet find where name=ether1]
/ip route add gateway=${INTERFACE_GATEWAY}
" > /mnt/mikrotik/rw/autorun.scr

umount /mnt/mikrotik

echo "Mengunci disk dan membersihkan cache..."
sync

# Menulis langsung ke disk utama tanpa interupsi OS
echo "Writing image to disk /dev/${DISK}..."
dd if=chr-$CHR_VERSION.img of=/dev/${DISK} bs=4M status=progress && sync

echo "Memicu reboot paksa via Kernel Panic..."
echo 1 > /proc/sys/kernel/panic
echo c > /proc/sysrq-trigger
