#!/bin/bash
set -e
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

vboxmanage --version
vboxmanage_version=$(vboxmanage --version | cut -d r -f 1)

sudo vboxmanage controlvm freebsd poweroff || true
sudo vboxmanage unregistervm freebsd --delete || true
sudo rm -rf "$HOME/VirtualBox VMs/freebsd"
rm -f ~/.ssh/known_hosts

[[ -e freebsd.vhd.xz ]] || curl -fsSLo freebsd.vhd.xz https://download.freebsd.org/releases/VM-IMAGES/13.2-RELEASE/amd64/Latest/FreeBSD-13.2-RELEASE-amd64.vhd.xz
[[ -e freebsd.vhd ]] || xz -dv freebsd.vhd.xz

sudo vboxmanage createvm --name freebsd --ostype FreeBSD_64 --default --basefolder freebsd --register
sudo vboxmanage storagectl freebsd --name SATA --add sata --controller IntelAHCI
sudo vboxmanage storageattach freebsd --storagectl SATA --port 0 --device 0 --type hdd --medium freebsd.vhd
sudo vboxmanage modifyvm freebsd --vrde on --vrdeport 3390
sudo vboxmanage modifyvm freebsd --natpf1 'guestssh,tcp,,2225,,22'
sudo vboxmanage modifyhd freebsd.vhd --resize 100000
sudo vboxmanage modifyvm --uart1 0x3F8 4 --uartmode1 server /var/run/freebsd-uart1.sock

sudo vboxmanage startvm freebsd --type headless
sleep 10

cat /var/run/freebsd-uart1.sock
