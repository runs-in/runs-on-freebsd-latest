#!/bin/bash
set -ex
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

if [[ ! -e ~/.ssh/id_rsa ]]; then
  ssh-keygen -f  ~/.ssh/id_rsa -q -N ""
fi

echo <<EOF >>~/.ssh/config
StrictHostKeyChecking=accept-new
SendEnv CI GITHUB_* VM*

Host freebsd
  User root
  Port 2225
  HostName localhost
EOF

sudo sh <<EOF
echo '' >>/etc/ssh/sshd_config
echo 'StrictModes no' >>/etc/ssh/sshd_config
EOF

sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist

vboxmanage --version
vboxmanage_version=$(vboxmanage --version | cut -d r -f 1)

curl -fsSLo oracle-vm.vbox-extpack "https://download.virtualbox.org/virtualbox/$vboxmanage_version/Oracle_VM_VirtualBox_Extension_Pack-$vboxmanage_version.vbox-extpack"
yes | sudo vboxmanage extpack install --replace oracle-vm.vbox-extpack
vboxmanage list extpacks

sudo vboxmanage controlvm freebsd poweroff || true
sudo vboxmanage unregistervm freebsd --delete || true
sudo rm -rf "$HOME/VirtualBox VMs/freebsd"
rm -f ~/.ssh/known_hosts

if [[ ! -e freebsd.vhd.xz ]]; then
  curl -fsSLo freebsd.vhd.xz https://download.freebsd.org/releases/VM-IMAGES/13.2-RELEASE/amd64/Latest/FreeBSD-13.2-RELEASE-amd64.vhd.xz
fi
if [[ ! -e freebsd.vhd ]]; then
  xz -dv freebsd.vhd.xz
fi

sudo vboxmanage createvm --name freebsd --ostype FreeBSD_64 --default --basefolder freebsd --register
sudo vboxmanage storagectl freebsd --name SATA --add sata --controller IntelAHCI
sudo vboxmanage storageattach freebsd --storagectl SATA --port 0 --device 0 --type hdd --medium freebsd.vhd
sudo vboxmanage modifyvm freebsd --vrde on --vrdeport 3390
sudo vboxmanage modifyvm freebsd --natpf1 'guestssh,tcp,,2225,,22'
sudo vboxmanage modifyhd freebsd.vhd --resize 100000

python3 -m http.server >http-server.log 2>&1 & http_server_pid=$!
cat <<EOF >index.html
<!DOCTYPE html>
<title>FreeBSD</title>
<meta http-equiv="refresh" content="1">
<p>Wait a bit...</p>
EOF

(
  while true; do
    rm -f screenshot.png.tmp
    while ! sudo vboxmanage controlvm freebsd screenshotpng screenshot.png.tmp; do
      sleep 3
    done
    sudo chmod 666 screenshot.png.tmp
    mv screenshot.png.tmp screenshot.png
    "$script_dir/ocr.py" screenshot.png >screenshot.txt
    cat <<EOF >index.html
<!DOCTYPE html>
<title>FreeBSD</title>
<meta http-equiv="refresh" content="1">
<button onclick="stop()">Stop</button>
<img src="screenshot.png" />
<plaintext>$(cat screenshot.txt)
EOF
  done
)& ocr_pid=$!

killall cloudflared || true
curl -fsSLo cloudflared.tgz https://github.com/cloudflare/cloudflared/releases/download/2023.7.1/cloudflared-darwin-amd64.tgz
tar -xzf cloudflared.tgz
./cloudflared tunnel --url http://localhost:8000 >cloudflared.log 2>&1 & cloudflared_pid=$!

while ! grep trycloudflare.com cloudflared.log -C10; do
  sleep 3
done

sudo vboxmanage startvm freebsd --type headless

while ! grep '64 (freebsd) (tty' screenshot.txt; do
  sleep 3
done
sleep 3

sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1
sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1
sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1
sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1
sudo vboxmanage controlvm freebsd keyboardputstring root; sleep 1
sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1
sudo vboxmanage controlvm freebsd keyboardputscancode 1c 9c; sleep 1

cat <<EOF >enable-ssh.txt
echo 'sshd_enable="YES"' >>/etc/rc.conf
service sshd start
echo '' >>/etc/ssh/sshd_config
echo 'PermitRootLogin yes' >>/etc/ssh/sshd_config
echo 'PermitEmptyPasswords yes' >>/etc/ssh/sshd_config
echo 'PasswordAuthentication yes' >>/etc/ssh/sshd_config
echo 'AcceptEnv   *' >>/etc/ssh/sshd_config
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ''
service sshd restart
passwd
EOF

echo "echo $'$(base64 ~/.ssh/id_rsa.pub)' | openssl base64 -d >>~/.ssh/authorized_keys" >>enable-ssh.txt
echo '' >>enable-ssh.txt
echo exit >>enable-ssh.txt

sudo vboxmanage controlvm freebsd keyboardputfile enable-ssh.txt

ssh freebsd sh <<EOF
echo 'StrictHostKeyChecking=accept-new' >>~/.ssh/config
echo 'Host host' >>~/.ssh/config
echo '  HostName 10.0.2.2' >>~/.ssh/config
echo '  User runner' >>~/.ssh/config
echo '  ServerAliveInterval 1' >>~/.ssh/config
EOF

ssh freebsd sh <<EOF
gpart show ada0
gpart recover ada0
gpart resize -i 3  -a 4k ada0
growfs -N /dev/ada0p3
service ntpd enable
service ntpd start
EOF

ssh freebsd 'cat ~/.ssh/id_rsa.pub' >freebsd-id_rsa.pub

ssh freebsd '/sbin/shutdown -p now'

sudo vboxmanage export freebsd --output freebsd.ova
sudo chmod +r freebsd.ova

cp ~/.ssh/id_rsa  local-id_rsa.key

kill $cloudflared_pid
kill $ocr_pid
kill $http_server_pid
