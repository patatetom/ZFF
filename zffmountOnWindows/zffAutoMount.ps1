

# this PowerShell script attempts to automatically open the ZFF (.Z01) file
# passed to it as a parameter, using zffmount at WSL.
# if successful, the contents of the container are then accessible from
# explorer at \\WSL$\Debian\mnt\wsl\zff\.
# this script is expected to be located at the root of the user
# profile (%UserProfile%).


# exit on error
$ErrorActionPreference = 'Stop'
# get filename full path
$Filename = (Get-ChildItem $Args[0]).FullName
# check extension
$Extension = (Get-ChildItem $Args[0]).Extension
if ($Extension.ToUpper() -ne ".Z01") {0/0}
# check magic header (zffm)
$Magic = Get-Content "$Filename" -Encoding Byte -TotalCount 4
if ((Compare-Object $magic ([byte]122,102,102,109)).length) {0/0}
# check admin rights
If (-NOT
(
[Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
) {
Start-Process -FilePath PowerShell -Verb RunAs -ArgumentList "-File","$PSCommandPath","$FileName"
Exit -1
}
# get drive letter from filename path
$Letter = (Split-Path "$Filename" -Qualifier)[0]
$Filename = (Split-Path "$Filename" -NoQualifier).Replace("\", "/")
# get disk and partition numbers
$Disk = (Get-Partition -DriveLetter "$Letter" | Get-Disk).Number
$Partition = (Get-Partition -DriveLetter "$Letter").PartitionNumber
# exit if system disk (0)
if (-NOT $Disk) {0/0}
# turn selected disk offline
"Select Disk $Disk", "Offline Disk" | diskpart | Out-Null
# mount selected disk in WSL
WSL --mount \\.\PHYSICALDRIVE$Disk --bare | Out-Null
# run zffmount
WSL mkdir -p /tmp/zff/ /mnt/wsl/zff/ | Out-Null
WSL mount /dev/sde$Partition /tmp/zff/ | Out-Null
Write-Host `n`n`n' Container is accessible at \\WSL$\Debian\mnt\wsl\zff\' -ForegroundColor DarkGreen
Write-Host ' Press [Ctrl]-[C] to stop sharing...'`n`n`n -ForegroundColor DarkGray
WSL ~/.cargo/bin/zffmount -i "/tmp/zff/$Filename" -m /mnt/wsl/zff/ | Out-Null
WSL umount /tmp/zff/ | Out-Null
# unmount selected disk from WSL
WSL --unmount \\.\PHYSICALDRIVE$Disk
# turn selected disk online
"Select Disk $Disk", "Online Disk" | diskpart | Out-Null
# uncomment next line to debug
#$Host.UI.RawUI.ReadKey()




