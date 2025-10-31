# `zffmount` on Windows

> Windows version, `WSL` version,  etc here...


## install Debian and cetera on `WSL`

```powershell
# in user PowerShell console
wsl --update

wsl --install Debian
```

```text
Enter new UNIX username: zff

# password for root access (sudo)
New password:
Retype new password:
```

```bash
sudo apt update
sudo apt full-upgrade

sudo apt install gcc pkg-config fuse3 libfuse-dev curl pv ntfs-3g

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

exec bash

rustup update
```


## build and install `zffmount`

```bash
cargo install zffmount

zffmount --help

sudo sh -c "echo user_allow_other > /etc/fuse.conf"
```


## use `zffmount`

> [!NOTE]
> get direct access to the `ZFF` container :
> access through Windows (drive letter) is not acceptable given the poor speed.

```powershell
# in administrator PowerShell console
Get-CimInstance -Query "SELECT * from Win32_DiskDrive"

# update disk number to your case
"select disk 1", "offline disk" | diskpart

# update disk number to your case
wsl --mount \\.\PHYSICALDRIVE1 --bare
```

```bash/WSL
lsblk -o +fstype
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS FSTYPE
# …
# sdd      8:48   0 238.5G  0 disk
# +-sdd1   8:49   0   128G  0 part             ext4
# +-sdd2   8:50   0 110.5G  0 part             ntfs

sudo mkdir -p /mnt/zfftest

sudo mount /dev/sdd1 /mnt/zfftest
```

```bash/WSL
pv -brt /mnt/zff/zfftest.z01 > /dev/null
# 1.62GiB 0:00:05 [ 297MiB/s]
```

```bash/WSL
mkdir -p /tmp/zfftest

zffmount -i /mnt/zff/zfftest.z01 -m /tmp/zfftest

pv -brt /tmp/zfftest/object_1/zff_image.dd > /dev/null
# 8.00GiB 0:00:13 [ 593MiB/s]
```

> [!TIP]
> the contents of the container are now accessible from Windows in `\\WSL$\Debian\tmp\zfftest\`.


## simple read test from Windows

```cmd
:: copy/paste the following three commands
time < nul
copy \\WSL$\Debian\tmp\zfftest\object_1\zff_image.dd /B nul /B
time < nul
:: 11:16:35
:: 1 file(s) copied.
:: 11:17:05
```

> [!NOTE]
> the `NTFS` partition can be used in the same way.
> however, the speed seems to be slower.
