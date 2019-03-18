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
arch-chroot /mnt echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo 'Enter desired hostname'
read hostname
arch-chroot /mnt echo $hostname > /etc/hostname

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

arch-chroot /mnt touch /home/admin/.zshrc
arch-chroot /mnt echo '# Lines configured by zsh-newuser-install' > /home/admin/.zshrc
arch-chroot /mnt echo 'HISTFILE=~/.zsh_history' >> /home/admin/.zshrc
arch-chroot /mnt echo 'HISTSIZE=1000' >> /home/admin/.zshrc
arch-chroot /mnt echo 'SAVEHIST=1000' >> /home/admin/.zshrc
arch-chroot /mnt echo 'setopt appendhistory autocd' >> /home/admin/.zshrc
arch-chroot /mnt echo 'unsetopt beep' >> /home/admin/.zshrc
arch-chroot /mnt echo 'bindkey -v' >> /home/admin/.zshrc
arch-chroot /mnt echo '# End of lines configured by zsh-newuser-install' >> /home/admin/.zshrc
arch-chroot /mnt echo '# The following lines were added by compinstall' >> /home/admin/.zshrc
arch-chroot /mnt echo "zstyle :compinstall filename '/home/admin/.zshrc'" >> /home/admin/.zshrc
arch-chroot /mnt echo 'autoload -Uz compinit' >> /home/admin/.zshrc
arch-chroot /mnt echo 'compinit' >> /home/admin/.zshrc
arch-chroot /mnt echo '# End of lines added by compinstall' >> /home/admin/.zshrc
arch-chroot /mnt echo "PROMPT='%n%f@%m%f %~%f %# '" >> /home/admin/.zshrc

echo 'Configure WiFi? (y/N)'
read wifi
if [ $wifi = 'y' ] ; then
	arch-chroot /mnt pacman -S --noconfirm networkmanager
	arch-chroot /mnt systemctl enable NetworkManager
fi
arch-chroot /mnt echo "127.0.0.1\tlocalhost" > /etc/hosts
arch-chroot /mnt echo "::1\tlocalhost" >> /etc/hosts
arch-chroot /mnt echo "127.0.1.1\t$hostname.local\t$hostname" >> /etc/hosts

arch-chroot /mnt touch /etc/systemd/system/getty@tty1.service.d/override.conf
arch-chroot /mnt echo '[Service]' > /etc/systemd/system/getty@tty1.service.d/override.conf
arch-chroot /mnt echo 'ExecStart=' > /etc/systemd/system/getty@tty1.service.d/override.conf
arch-chroot /mnt echo 'ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM' > /etc/systemd/system/getty@tty1.service.d/override.conf

umount -R /mnt
cryptsetup close crypthome
