#!/usr/bin/sh
set -ex
mkdir chroot || true
export DEBIAN_FRONTEND=noninteractive
ln -s sid /usr/share/debootstrap/scripts/yirmiuc-deb || true
debootstrap  --no-check-gpg --arch=amd64 yirmiuc-deb chroot https://depo.pardus.org.tr/pardus
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done

cat > chroot/etc/apt/sources.list << EOF
deb http://depo.pardus.org.tr/pardus yirmiuc main contrib non-free non-free-firmware
deb http://depo.pardus.org.tr/pardus yirmiuc-deb main contrib non-free non-free-firmware
deb http://depo.pardus.org.tr/guvenlik yirmiuc-deb main contrib non-free non-free-firmware
EOF

cat > chroot/etc/apt/sources.list.d/yirmiuc-backports.list << EOF
deb http://depo.pardus.org.tr/backports yirmiuc-backports main contrib non-free non-free-firmware
EOF

chroot chroot apt-get update --allow-insecure-repositories
chroot chroot apt-get install pardus-archive-keyring --allow-unauthenticated -y

chroot chroot apt-get update -y

chroot chroot apt-get install gnupg grub-pc-bin grub-efi-ia32-bin grub-efi live-config live-boot plymouth plymouth-themes -y

echo -e "#!/bin/sh\nexit 101" > chroot/usr/sbin/policy-rc.d
chmod +x chroot/usr/sbin/policy-rc.d

#Kernel
chroot chroot apt-get install -t yirmiuc-backports linux-image-amd64 -y

#Firmwares
chroot chroot apt-get install -y firmware-amd-graphics firmware-atheros \
    firmware-b43-installer firmware-b43legacy-installer \
    firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-linux-free \
    firmware-cavium firmware-intel-sound \
    firmware-iwlwifi  firmware-libertas firmware-linux \
    firmware-linux-nonfree firmware-misc-nonfree firmware-myricom \
    firmware-netxen firmware-qlogic firmware-realtek firmware-samsung \
    firmware-siano firmware-ti-connectivity firmware-zd1211
    
#Init and Window System
chroot chroot apt-get install xorg xinit lightdm -y

#Desktop apps
chroot chroot apt-get install xfce4 xfce4-terminal file-roller -y
chroot chroot apt-get install xfce4-whiskermenu-plugin thunar-archive-plugin xfce4-screenshooter mousepad ristretto -y
chroot chroot apt-get install xfce4-datetime-plugin xfce4-timer-plugin xfce4-mount-plugin xfce4-taskmanager xfce4-battery-plugin xfce4-power-manager -y
chroot chroot apt-get install network-manager-gnome gvfs-backends gnome-calculator synaptic -y
chroot chroot apt-get install pardus-about pardus-installer pardus-lightdm-greeter pardus-night-light pardus-package-installer pardus-software pardus-update -y
chroot chroot apt-get install pardus-xfce-gtk-theme pardus-xfce-icon-theme pardus-xfce-settings pardus-xfce-tweaks -y

#Pardus apps
chroot chroot apt-get install pardus-lightdm-greeter pardus-installer pardus-software pardus-package-installer pardus-night-light pardus-about pardus-update pardus-locales pardus-ayyildiz-grub-theme -y

#Grub update
chroot chroot apt-get upgrade -y
chroot chroot update-grub
chroot chroot apt remove xterm termit xarchiver -y

#### Remove bloat files after dpkg invoke (optional)
cat > chroot/etc/apt/apt.conf.d/02antibloat << EOF
DPkg::Post-Invoke {"rm -rf /usr/share/man || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/help || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/doc || true";};
EOF

chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

mkdir pardus || true
while umount -lf -R chroot/* 2>/dev/null ; do
 : "Umount action"
done
mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
find chroot/var/log/ -type f | xargs rm -f
mkdir -p pardus/live
mv filesystem.squashfs pardus/live/filesystem.squashfs

cp -pf chroot/boot/initrd.img-* pardus/live/initrd.img
cp -pf chroot/boot/vmlinuz-* pardus/live/vmlinuz

mkdir -p pardus/boot/grub/
echo 'terminal_output console' > pardus/boot/grub/grub.cfg
echo 'menuentry "Start Pardus 23 Xfce Backports (Unofficial)" --class pardus {' >> pardus/boot/grub/grub.cfg
echo '    linux /live/vmlinuz boot=live components --' >> pardus/boot/grub/grub.cfg
echo '    initrd /live/initrd.img' >> pardus/boot/grub/grub.cfg
echo '}' >> pardus/boot/grub/grub.cfg

grub-mkrescue pardus -o pardus-xfce-backports.iso
