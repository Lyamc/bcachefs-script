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
