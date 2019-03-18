#!/bin/zsh


if ls /sys/firmware/efi/efivars > /dev/null 2>&1 ; then
	echo 'Using UEFI'
else
	echo 'Using BIOS'
fi

timedatectl set-ntp true
timedatectl status

lsblk -p
echo 'Please select a disk to partition'
read archdisk
(
	echo o
	echo n; echo p; echo 1; echo ''; echo +550M; echo t; echo '83'; echo a
	echo n; echo p; echo 2; echo ''; echo +1G; echo t; echo 2; echo '82'
	echo n; echo p; echo 3; echo ''; echo +9G; echo t; echo 3; echo '83'
	echo n; echo p; echo ''; echo ''; echo t; echo 4; echo '83'
	echo w; echo q
) | fdisk $archdisk

mkfs.ext4 $archdisk'3'
mount $archdisk'3' /mnt

mkfs.ext4 $archdisk'1'
mkdir /mnt/boot
mount $archdisk'1' /mnt/boot

mkswap $archdisk'2'
swapon $archdisk'2'

cryptsetup -y -v luksFormat --type luks2 $archdisk'4'
cryptsetup open $archdisk'4' crypthome
mkfs.ext4 /dev/mapper/crypthome
mkdir /mnt/home
mount /dev/mapper/crypthome /mnt/home

pacstrap /mnt base

genfstab -U /mnt > /mnt/etc/fstab
echo "crypthome\tUUID=`lsblk -fp | grep $archdisk'4' | awk '{ print $3 }'`\tnone\tluks" > /mnt/etc/crypttab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/US/Eastern /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

echo 'Enter desired hostname'
read hostname
echo $hostname > /mnt/etc/hostname

arch-chroot /mnt mkinitcpio -p linux

arch-chroot /mnt pacman -S --noconfirm grub
arch-chroot /mnt grub-install --target=i386-pc $archdisk
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

arch-chroot /mnt pacman -S --noconfirm vim
arch-chroot /mnt pacman -S --noconfirm zsh
arch-chroot /mnt pacman -S --noconfirm sudo
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh admin
arch-chroot /mnt passwd admin

echo '# Lines configured by zsh-newuser-install' > /mnt/home/admin/.zshrc
echo 'HISTFILE=~/.zsh_history' >> /mnt/home/admin/.zshrc
echo 'HISTSIZE=1000' >> /mnt/home/admin/.zshrc
echo 'SAVEHIST=1000' >> /mnt/home/admin/.zshrc
echo 'setopt appendhistory autocd' >> /mnt/home/admin/.zshrc
echo 'unsetopt beep' >> /mnt/home/admin/.zshrc
echo 'bindkey -v' >> /mnt/home/admin/.zshrc
echo '# End of lines configured by zsh-newuser-install' >> /mnt/home/admin/.zshrc
echo '# The following lines were added by compinstall' >> /mnt/home/admin/.zshrc
echo "zstyle :compinstall filename '/home/admin/.zshrc'" >> /mnt/home/admin/.zshrc
echo 'autoload -Uz compinit' >> /mnt/home/admin/.zshrc
echo 'compinit' >> /mnt/home/admin/.zshrc
echo '# End of lines added by compinstall' >> /mnt/home/admin/.zshrc
echo "PROMPT='%n%f@%m%f %~%f %# '" >> /mnt/home/admin/.zshrc
chown admin:admin /mnt/home/admin/.zshrc

echo 'Configure WiFi? (y/N)'
read wifi
if [ $wifi = 'y' ] ; then
	arch-chroot /mnt pacman -S --noconfirm networkmanager
	arch-chroot /mnt systemctl enable NetworkManager
fi
echo "127.0.0.1\tlocalhost" > /mnt/etc/hosts
echo "::1\tlocalhost" >> /mnt/etc/hosts
echo "127.0.1.1\t$hostname.local\t$hostname" >> /mnt/etc/hosts

arch-chroot /mnt mkdir /etc/systemd/system/getty@tty1.service.d
echo '[Service]' >> /mnt/etc/systemd/system/getty@tty1.service.d/override.conf
echo 'ExecStart=' >> /mnt/etc/systemd/system/getty@tty1.service.d/override.conf
echo 'ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM' >> /mnt/etc/systemd/system/getty@tty1.service.d/override.conf

#umount -R /mnt
#cryptsetup close crypthome
