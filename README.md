# bcachefs-script
Installs Ubuntu to a new disk using bcachefs as the root partition

It assumes the following:
1) You're in Ubuntu and connected to internet
2) You have space for the kernel downloads and time for the compile
3) You want to use an entire disk and boot using UEFI
4) You want to use the defaults for format options

```
wget https://raw.githubusercontent.com/Lyamc/bcachefs-script/main/bcachefs-script.sh; chmod +x bcachefs-script.sh; ./bcachefs-script.sh
```

How to Use:
1) Run it, choose "1", pray that the script works on whatever version of OS you have.
2) Reboot
3) Run it again, choose "2", pray some more
4) Reboot into the newly installed OS.


Feel free to give me feedback, I don't know what I'm doing, I just keep doing things till they work. In the future I'll probably add a prompt for adding the formatting options.

# bcachefs-update
Installs dependencies, builds and installs bcachefs-tools + kernel from latest git.

Note: This script assumes that you're running Ubuntu

```
wget https://raw.githubusercontent.com/Lyamc/bcachefs-script/main/bcachefs-update.sh; chmod +x bcachefs-update.sh; ./bcachefs-update.sh
```

# Install on Alpine

Assuming you've already set up networking, the user, and sudo...

```
# Linux Kernel build dependencies
sudo apk add alpine-sdk linux-headers bash flex bison bc kmod cpio elfutils-dev ncurses-dev openssl-dev perl

# Bcachefs Tools build dependencies
sudo apk add build-base cargo clang17-dev coreutils libaio-dev libsodium-dev llvm17-dev eudev-dev util-linux-dev keyutils-dev lz4-dev userspace-rcu-dev zstd-dev pkgconf zlib
```

```
# Build and Install Kernel
git clone https://github.com/koverstreet/bcachefs
cd bcachefs

make olddefconfig

scripts/config --disable CONFIG_DEBUG_INFO
scripts/config --enable CONFIG_BCACHEFS_FS
scripts/config --enable CONFIG_BCACHEFS_QUOTA
scripts/config --enable BCACHEFS_ERASURE_CODING
scripts/config --enable CONFIG_BCACHEFS_POSIX_ACL
scripts/config --disable CONFIG_BCACHEFS_DEBUG
scripts/config --disable CONFIG_BCACHEFS_TESTS
scripts/config --disable BCACHEFS_LOCK_TIME_STATS
scripts/config --disable BCACHEFS_NO_LATENCY_ACCT
scripts/config --enable BCACHEFS_SIX_OPTIMISTIC_SPIN
scripts/config --enable BCACHEFS_PATH_TRACEPOINTS
scripts/config --enable CONFIG_CRYPTO_CRC32C_INTEL
# Enable ext4 filesystem support
scripts/config --enable EXT3_FS
scripts/config --enable CONFIG_EXT4_FS

# Enable btrfs filesystem support
scripts/config --enable CONFIG_BTRFS_FS

# Enable xfs filesystem support
scripts/config --enable CONFIG_XFS_FS

make olddefconfig

make
make modules
sudo make install

sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-bcachefs
sudo cp -v System.map /boot/System.map-bcachefs
sudo cp -v .config /boot/config-bcachefs

kernelversion=$(sudo make modules_install | awk '/SYMLINK/ {print $2}' | awk -F'/' '{print $4}')

cd ../
sudo mkinitfs -C lz4 -o /boot/initramfs-bcachefs $kernelversion
sudo update-extlinux
# Confirm with cat /boot/extlinux.conf
```

```
# Build and Install Tools
git clone https://github.com/koverstreet/bcachefs-tools
cd bcachefs-tools
make
sudo make install
```
