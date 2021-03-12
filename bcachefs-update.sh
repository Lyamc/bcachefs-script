#!/bin/bash

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
wget https://github.com/nathanchance/bug-files/raw/7442f4c76efc096b02cb750b8c553de93fdcf409/cbl-1254/thunk_64.o -o arch/x86/entry/thunk_64.o
cd ..

echo "Installing Linux Kernel"

sudo dpkg -i linux*.deb
sudo apt -f install -y
}

update-dep
update-bcachefs-tools
update-bcachefs
