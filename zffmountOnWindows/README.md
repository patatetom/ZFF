# `zffmount` on Windows

> [!NOTE]
> on Windows 11 `10.0.26100.6899`, `WSL` `2.6.1.0` and kernel `6.6.87.2-1`.<br />
> unlike `zffacquire`, and due to the use of `FUSE`, `zffmount` cannot be ported directly to Windows.


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
# in WSL console
sudo apt update
sudo apt full-upgrade

sudo apt install gcc pkg-config fuse3 libfuse-dev curl pv ntfs-3g

sudo sh -c "echo user_allow_other > /etc/fuse.conf"
sudo sh -c "echo zff ALL=(ALL) NOPASSWD: /bin/mount > /etc/sudoers.d/zff"
sudo sh -c "echo zff ALL=(ALL) NOPASSWD: /bin/umount >> /etc/sudoers.d/zff"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

exec bash

rustup update
```


## build and install `zffmount`

```bash
cargo install zffmount

zffmount --help
```


## use `zffmount`

> [!NOTE]
> with « direct » access to the `ZFF` container.<br :>
> the drive must be released from Windows before it can be used « directly » under `WSL`.<br />
> access through Windows (mounted drive letter in `/mnt/e/`) is not acceptable given the poor speed.

```powershell
# in administrator PowerShell console
Get-CimInstance -Query "SELECT * from Win32_DiskDrive"

"select disk 1", "offline disk" | diskpart

wsl --mount \\.\PHYSICALDRIVE1 --bare
```

```bash
# in WSL console
lsblk -o +fstype
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS FSTYPE
# sdd      8:48   0 238.5G  0 disk
# +-sdd1   8:49   0   128G  0 part             ext4
# +-sdd2   8:50   0 110.5G  0 part             ntfs

mkdir -p /tmp/zff/

mount /dev/sdd1 /tmp/zff/
```

```bash
pv -brt /tmp/zff/zfftest.z01 > /dev/null
# 1.62GiB 0:00:05 [ 297MiB/s]
```

```bash
sudo mkdir -p /zff/

zffmount -i /tmp/zff/zfftest.z01 -m /zff/

pv -brt /zff/object_1/zff_image.dd > /dev/null
# 8.00GiB 0:00:13 [ 593MiB/s]
```

> [!TIP]
> the contents of the container are now accessible from Windows in `\\WSL$\Debian\zff\`.<br />
> you can now use your favorite investigation tools on the raw disk/partition image ;-)


## simple read test from Windows

```cmd
:: copy/paste the next three commands in a user Cmd console
time < nul
copy \\WSL$\Debian\zff\object_1\zff_image.dd /B nul /B
time < nul
:: 11:16:35
:: 1 file(s) copied.
:: 11:17:05

certutil -hashFile \\WSL$\Debian\zff\object_1\zff_image.dd SHA1
957101f373f6f888becc44a4ea6266b7e6e8aca2
```

> [!NOTE]
> the `NTFS` partition (`/dev/sdd2`) can also be used in the same way (`ntfs-3g`).
> however, the speed seems to be slower.


## Explorer integration

if your `ZFF` container is located on a Windows partition (`NTFS`, `exFAT`, `FAT`, `UDF`), opening it directly from Explorer can be automated :

- download and check the PowerShell script [`zffAutoMount.ps1`](https://github.com/patatetom/ZFF/blob/main/zffmountOnWindows/zffAutoMount.ps1)
- save it to the root of your profile (`%UserProfile%`)
- download and check the Registry file [`zffAutoMount.reg`](https://github.com/patatetom/ZFF/blob/main/zffmountOnWindows/zffAutoMount.reg)
- save it and run it to define the `.Z01` file extension.

once this is done, double-clicking on a `ZFF` container should automatically make its contents available in Windows at `\\WSL$\Debian\mnt\wsl\zff\`.
