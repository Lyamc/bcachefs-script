#!/bin/bash

set -e

mounttarget="/mnt"
distro=$(lsb_release -cs)
script_name=$(basename $0)
script_path=$(dirname $0)
script="$script_path/$script_name"
username="$USER"

clear

echo "Bcachefs install script v0.1"
echo ""
echo "This interactive script is designed to be run on Ubuntu and will install Ubuntu onto an entire disk."
echo "This requires several GBs."
echo "Required packages will be downloaded and installed."
echo "The kernel is downloaded and built from source."
echo "THIS WILL TAKE A LONG TIME"
echo ""
echo "You will be prompted for confirmation before writing partition changes."
echo ""
echo "----------"
echo ""

sleep 2

function update-dep
{
echo "Adding additional repositories"
sudo apt-add-repository -syn multiverse
sudo apt-add-repository -syn universe
sudo apt-add-repository -syn restricted
sudo apt-add-repository -syn main
grep '# deb-src.*main' /etc/apt/sources.list | sed 's|# deb-src|deb-src|g' | sudo tee /etc/apt/sources.list.d/deb-src.list
echo "Getting new repository information"
sudo apt update

echo "Getting bcachefs dependencies"
sudo apt install -y debootstrap tasksel devscripts gcc git libaio-dev libattr1-dev libblkid-dev libkeyutils-dev liblz4-dev libscrypt-dev libsodium-dev liburcu-dev libzstd-dev make pkg-config uuid-dev zlib1g-dev valgrind python3-pytest

echo "Getting Linux Kernel Build Dependencies"
sudo apt build-dep -y linux
}

function update-bcachefs-tools
{
echo "Setup build direct"
mkdir -p ~/build
cd ~/build
rm -Rf ./bcachefs-tools
rm -f bcachefs*.deb

echo "Getting Bcachefs Tools"
git clone https://evilpiepirate.org/git/bcachefs-tools.git

echo "Building Bcachefs Tools"
cd bcachefs-tools

make deb -j $(nproc)

cd ..

echo "Installing Bcachefs Tools"

sudo dpkg -i bcachefs*.deb
sudo apt -f install -y
}

function update-bcachefs
{
echo "Getting Linux Kernel"
mkdir -p ~/build
cd ~/build
rm -Rf ./bcachefs
rm -Rf ./*.orig
rm -f linux*.deb

git clone https://evilpiepirate.org/git/bcachefs.git

echo "Setting Kernel Configuration"

cd ./bcachefs

make olddefconfig

## CONFIG_DEBUG_INFO controls whether or not make will spit out linux-image-blahblah-dbg.deb
scripts/config --disable CONFIG_DEBUG_INFO
scripts/config --enable CONFIG_BCACHEFS_FS
scripts/config --enable CONFIG_BCACHEFS_QUOTA
scripts/config --enable CONFIG_BCACHEFS_POSIX_ACL
scripts/config --disable CONFIG_BCACHEFS_DEBUG
scripts/config --disable CONFIG_BCACHEFS_TESTS

echo "Building Linux Kernel"

make bindeb-pkg -j $(nproc) EXTRAVERSION=-$(git rev-parse --short HEAD) LOCALVERSION=

cd ..

echo "Installing Linux Kernel"

sudo dpkg -i linux*.deb
sudo apt -f install -y
}


function install-distro
{
echo ""
echo "Listing all disks"
echo ""



while true; do
		
	echo ""
	sudo lsblk | grep 'disk' | awk '{print NR ") /dev/"$1, $4}' OFS='\t'
	echo ""
	
	read -r -p "Select disk number (1, 2...): " response1
	disk=$(sudo lsblk | grep 'disk' | awk -v var=$response1 'FNR == var {print $1}')
	echo ""
	echo "You have selected: /dev/$disk"
	sudo lsblk | grep "$disk"
	echo ""


read -r -p "Are you sure? THIS WILL ERASE ALL DATA ON $disk [y/N]: " response2
	case "$response2" in
		[Yy][Ee][Ss]|[Yy]) # Yes or Y (case-insensitive).
			break
			;;
		[Nn][Oo]|[Nn]|"")  # No or N or empty.
			echo ""
			;;
      		*) # Anything else is invalid.
			echo "Invalid response"
			echo ""
			;;
    	esac
done

if [[ $disk == *"nvme"* ]]
then
  targetdisk="/dev/$disk"
  targetefi="$targetdisk"p1
  targetboot="$targetdisk"p2
  targetroot="$targetdisk"p3
  targetswap="$targetdisk"p4
else
  targetdisk="/dev/$disk"
  targetefi="$targetdisk"1
  targetboot="$targetdisk"2
  targetroot="$targetdisk"3
  targetswap="$targetdisk"4
fi

echo "Paritions to be Created"
echo "$targetefi"
echo "$targetboot"
echo "$targetroot"
echo "$targetswap"
echo ""

sleep 1

echo "Formatting $targetdisk"

sed -e 's/#.*$//;/^$/d' << GDISK_CMDS1  | sudo gdisk $targetdisk
o      # create new GPT partition table
y
n      # add new partition (EFI)
1      # partition number
       # default - first sector 
+250MiB # partition size
ef00      # Set GUID Code
n      # add new partition
2      # partition number
       # default - first sector 
+4GiB       # default - last sector 
8300      # Set GUID Code
n      # add new partition
3      # partition number
       # default - first sector 
-8GiB       # default - last sector 
8304      # Set GUID Code
n      # add new partition
4      # partition number
       # default - first sector 
       # default - last sector 
8200      # Set GUID Code
b      # write partition table to FILE
gdisk.bak
q
GDISK_CMDS1

sed 's/#.*$//;/^$/d' << GDISK_CMDS2  | sudo gdisk $targetdisk
r      # Use recovery/backup options
l      # Load from backup
gdisk.bak
p      # show part table
q
GDISK_CMDS2

echo ""
while true; do
read -r -p "Do you accept these changes? [Y/n] " response3
case "$response3" in
	[Yy][Ee][Ss]|[Yy]|"") # Yes or Y or empty (case-insensitive).
		break
	;;
	[Nn][Oo]|[Nn])  # No or N.
		echo "Exiting..."
		exit
	;;
		*) # Anything else (including a blank) is invalid.
	;;
esac
done

		echo "Writing Changes"
sed 's/#.*$//;/^$/d' << GDISK_CMDS3  | sudo gdisk $targetdisk
r      # Use recovery/backup options
l      # Load from backup
gdisk.bak
w      # write partition table to DISK
y
GDISK_CMDS3

echo "Formatting partitions"
sudo mkfs.vfat $targetefi -n EFI
sudo mkfs.ext2 $targetboot -L BOOT
sudo mkfs.bcachefs $targetroot -L ROOT
sudo mkswap $targetswap -L SWAP

echo "Formatting complete"
echo ""
echo ""
sleep 1



#gdisk GUID Partition Table codes
#root and boot 8300
#swap 8200
#efi ef00


}

function debootstrap-ubuntu
{

echo “Preparing for chrooting”
echo ""

sudo umount -R -v -q $mounttarget || /bin/true
sudo mkdir -p $mounttarget
sudo mount $targetroot $mounttarget -t bcachefs
sudo mkdir -p $mounttarget/boot
sudo mount $targetboot $mounttarget/boot
sudo mkdir -p $mounttarget/boot/efi
sudo mount $targetefi $mounttarget/boot/efi
sudo swapoff -a  || /bin/true
sudo swapon $targetswap  || /bin/true


echo “Ready for debootstrap”
sudo debootstrap --arch amd64 $distro $mounttarget

echo “Copying the bcachefs-tools and kernel .deb files to the new system“
sudo cp -f ~/build/bcachefs-tools*.deb -t $mounttarget/tmp/
sudo cp -f ~/build/linux*.deb -t $mounttarget/tmp/

}

function chroot-ubuntu
{

echo "Setting up user via chroot"

sudo rm -f /mnt/tmp/chroot.sh
sudo touch /mnt/tmp/chroot.sh
sudo chmod +rwx /mnt/tmp/chroot.sh

sudo mount --bind /dev $mounttarget/dev
sudo mount --bind /dev/pts $mounttarget/dev/pts
sudo mount --bind /proc $mounttarget/proc
sudo mount --bind /sys $mounttarget/sys

cat << CHROOT_CMD | sudo chroot $mounttarget

echo “Chrooting into the new system root“

set -e
username="$username"
mounttarget="$mounttarget"
targetefi="$targetefi"
targetboot="$targetboot"
targetroot="$targetroot"
targetswap="$targetswap"
targetdisk="$targetdisk"
distro="$distro"

echo “Configuring $distro install on $targetdisk”

sudo apt update
echo "Getting Prerequisites"
sudo apt install -y tasksel initramfs-tools locales tzdata
sudo dpkg-reconfigure locales
sudo dpkg-reconfigure tzdata
sudo tasksel install ubuntu-desktop

echo "Adding additional chroot repositories"
sudo apt-add-repository -syn multiverse
sudo apt-add-repository -syn universe
sudo apt-add-repository -syn restricted
echo "Getting new chroot repository information"
sudo apt update

sudo apt install -y grub-efi bash-completion nano

echo "Installing bcachefs-tools.deb on chroot"
echo ""
sudo apt install -y /tmp/bcachefs*.deb || /bin/true

echo "Installing Linux Kernel on chroot"
echo ""
sudo apt install -y /tmp/linux*.deb || /bin/true
sudo apt install -y linux-firmware

echo ""
grep "$targetdisk" /proc/mounts > /etc/fstab
partuuidefi=$(ls -l /dev/disk/by-partuuid/ | grep $(echo $targetefi | sed "s|/dev||g") | awk '{print $9}')
partuuidboot=$(ls -l /dev/disk/by-partuuid/ | grep $(echo $targetboot | sed "s|/dev||g") | awk '{print $9}')
partuuidroot=$(ls -l /dev/disk/by-partuuid/ | grep $(echo $targetroot | sed "s|/dev||g") | awk '{print $9}')
partuuidswap=$(ls -l /dev/disk/by-partuuid/ | grep $(echo $targetswap | sed "s|/dev||g") | awk '{print $9}')

sudo sed -i "s|$targetefi|/dev/disk/by-partuuid/$partuuidefi|g" /etc/fstab
sudo sed -i "s|$targetboot|/dev/disk/by-partuuid/$partuuidboot|g" /etc/fstab
sudo sed -i "s|$targetroot|/dev/disk/by-partuuid/$partuuidroot|g" /etc/fstab
sudo sed -i "s|$targetswap|/dev/disk/by-partuuid/$partuuidswap|g" /etc/fstab

echo "Chroot fstab created"



sudo grub-install --target=x86_64-efi $targetdisk
#sudo grub-install --target=x86_64-efi /boot/efi

echo "Changing rootfstype on chroot /etc/default/grub"
sudo sed -i 's|GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="rootfstype=bcachefs"|g' /etc/default/grub
sudo update-grub

#echo "Changing rootfs on chroot /boot/grub/grub.cfg"
#sed -ri "s#root=$targetroot#root=/dev/disk/by-partuuid/$partuuidroot#" /boot/grub/grub.cfg

sudo update-initramfs -c -k $(uname -r)

echo "Creating user $username at /home/$username with an empty password"
sudo useradd $username -g 100 -G sudo -s /bin/bash -d /home/$username -m || /bin/true
echo "$username:U6aMy0wojraho" | sudo chpasswd -e
sudo passwd -e $username
CHROOT_CMD


sudo umount -R -v $mounttarget
sudo swapoff -a || /bin/true
echo "Installation complete, please reboot into the new system"
sleep 5
}

function mount-bcachefs {
while true; do
		
	echo ""
	sudo lsblk | grep 'disk' | awk '{print NR ") /dev/"$1, $4}' OFS='\t'
	echo ""
	
	read -r -p "Select disk number (1, 2...): " response1
	disk=$(sudo lsblk | grep 'disk' | awk -v var=$response1 'FNR == var {print $1}')
	echo ""
	echo "You have selected: /dev/$disk"
	sudo lsblk | grep "$disk"
	echo ""


read -r -p "Are you sure? $disk [Y/n]: " response2
	case "$response2" in
		[Yy][Ee][Ss]|[Yy]|"") # Yes or Y (case-insensitive).
			break
			;;
		[Nn][Oo]|[Nn])  # No or N or empty.
			echo ""
			;;
      		*) # Anything else is invalid.
			echo "Invalid response"
			echo ""
			;;
    	esac
done

if [[ $disk == *"nvme"* ]]
then
  targetdisk="/dev/$disk"
  targetefi="$targetdisk"p1
  targetboot="$targetdisk"p2
  targetroot="$targetdisk"p3
  targetswap="$targetdisk"p4
else
  targetdisk="/dev/$disk"
  targetefi="$targetdisk"1
  targetboot="$targetdisk"2
  targetroot="$targetdisk"3
  targetswap="$targetdisk"4
fi

sudo umount -R -v -q $mounttarget || /bin/true
sleep 1
sudo mkdir -p $mounttarget || /bin/true
sudo mount $targetroot $mounttarget -t bcachefs || /bin/true
sudo mkdir -p $mounttarget/boot || /bin/true
sudo mount $targetboot $mounttarget/boot || /bin/true
sudo mkdir -p $mounttarget/boot/efi || /bin/true
sudo mount $targetefi $mounttarget/boot/efi || /bin/true
sudo swapoff -a || /bin/true
sudo swapon $targetswap || /bin/true
}

function update-all {
update-dep
update-bcachefs-tools
update-bcachefs
}

function new-install-1 {
update-dep
update-bcachefs-tools
update-bcachefs
}

function new-install-2 {
install-distro
debootstrap-ubuntu
chroot-ubuntu
}

echo "Select what step of the program needs to be executed"
echo ""
echo -e "1:\t Installing prerequisites & download, build, and install bcachefs tools and kernel (requires a reboot after)"
echo ""
echo -e "2:\t Installing Ubuntu onto chroot environment"
echo ""
echo -e "3:\t (skip formating) Installing Ubuntu onto chroot environment"
echo ""
echo -e "4:\t Mounts the partitions (assuming EFI is first, BOOT is second, ROOT is third)"
read -p "Enter number: " response
case $response in

("1")
new-install-1
echo "You now need to reboot, and then re-run the script and choose option 2."
;;

("2")
new-install-2
echo "Login to the new system with username=$username, password={blank, just hit enter}"
sleep 1
;;

("3")
mount-bcachefs
chroot-ubuntu
echo "Login to the new system with username=$username, password={blank, just hit enter}"
sleep 1
;;

("4")
mount-bcachefs
echo "Done. To unmount, run: sudo umount -R -v $mounttarget"
sleep 1
xdg-open $mounttarget
;;

(*)
echo "Exiting..."
exit
;;
esac
