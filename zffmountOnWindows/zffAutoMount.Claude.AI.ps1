<#
.SYNOPSIS
    Automatically mounts a ZFF (.Z01) file using zffmount in WSL.

.DESCRIPTION
    This PowerShell script mounts a ZFF container using zffmount under WSL.
    Contents become accessible via \\WSL$\Debian\mnt\wsl\zff\
    Requires administrator rights and WSL with Debian.

.PARAMETER FilePath
    Full path to the .Z01 file to mount.

.EXAMPLE
    .\zffAutoMount.ps1 "D:\Data\container.Z01"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "File '$_' does not exist."
        }
        if ([System.IO.Path]::GetExtension($_) -ne '.Z01') {
            throw "File must have .Z01 extension"
        }
        return $true
    })]
    [string]$FilePath
)

#Requires -Version 5.1

# Strict configuration
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Constants
$ZFF_MAGIC_BYTES = [byte[]](122, 102, 102, 109)  # "zffm"
$WSL_MOUNT_PATH = '/mnt/wsl/zff'
$WSL_TEMP_PATH = '/tmp/zff'
$NETWORK_PATH = '\\WSL$\Debian\mnt\wsl\zff\'

#region Functions

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if the script is running with administrator privileges.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ZFFMagicBytes {
    <#
    .SYNOPSIS
        Verifies the ZFF file magic signature.
    #>
    param([string]$Path)
    
    try {
        $magicBytes = Get-Content -Path $Path -Encoding Byte -TotalCount 4 -ErrorAction Stop
        $comparison = Compare-Object -ReferenceObject $ZFF_MAGIC_BYTES -DifferenceObject $magicBytes
        return ($null -eq $comparison)
    }
    catch {
        Write-Error "Unable to read file magic bytes: $_"
        return $false
    }
}

function Request-AdminPrivileges {
    <#
    .SYNOPSIS
        Restarts the script with administrator privileges.
    #>
    param([string]$ScriptPath, [string]$Argument)
    
    Write-Warning "Restarting with administrator privileges..."
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', "`"$ScriptPath`""
        "`"$Argument`""
    )
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
    exit 0
}

function Get-DiskInfo {
    <#
    .SYNOPSIS
        Retrieves disk and partition information.
    #>
    param([string]$DriveLetter)
    
    try {
        $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop
        $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
        
        return @{
            DiskNumber = $disk.Number
            PartitionNumber = $partition.PartitionNumber
            IsSystemDisk = ($disk.Number -eq 0)
        }
    }
    catch {
        throw "Unable to retrieve disk information for drive letter '$DriveLetter': $_"
    }
}

function Set-DiskOnlineStatus {
    <#
    .SYNOPSIS
        Changes the online/offline status of a disk.
    #>
    param(
        [int]$DiskNumber,
        [bool]$Online
    )
    
    $action = if ($Online) { "Online" } else { "Offline" }
    $commands = @"
Select Disk $DiskNumber
$action Disk
"@
    
    try {
        $commands | diskpart.exe | Out-Null
        Write-Verbose "Disk $DiskNumber set to $action"
    }
    catch {
        Write-Error "Error setting disk to $action mode: $_"
    }
}

function Mount-WSLDisk {
    <#
    .SYNOPSIS
        Mounts a physical disk in WSL.
    #>
    param([int]$DiskNumber)
    
    try {
        wsl.exe --mount "\\.\PHYSICALDRIVE$DiskNumber" --bare 2>&1 | Out-Null
        Write-Verbose "Disk PHYSICALDRIVE$DiskNumber mounted in WSL"
    }
    catch {
        throw "Unable to mount disk in WSL: $_"
    }
}

function Dismount-WSLDisk {
    <#
    .SYNOPSIS
        Unmounts a physical disk from WSL.
    #>
    param([int]$DiskNumber)
    
    try {
        wsl.exe --unmount "\\.\PHYSICALDRIVE$DiskNumber" 2>&1 | Out-Null
        Write-Verbose "Disk PHYSICALDRIVE$DiskNumber unmounted from WSL"
    }
    catch {
        Write-Warning "Unable to unmount disk from WSL: $_"
    }
}

#endregion

#region Main Script

try {
    # Get full path
    $fileInfo = Get-Item -Path $FilePath -ErrorAction Stop
    $fullPath = $fileInfo.FullName
    
    Write-Information "Processing file: $fullPath"
    
    # Verify magic signature
    Write-Verbose "Verifying ZFF signature..."
    if (-not (Test-ZFFMagicBytes -Path $fullPath)) {
        throw "File does not contain a valid ZFF signature (magic bytes: zffm)"
    }
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Request-AdminPrivileges -ScriptPath $PSCommandPath -Argument $fullPath
        return
    }
    
    # Extract drive letter
    $driveLetter = (Split-Path -Path $fullPath -Qualifier).TrimEnd(':')
    Write-Verbose "Drive letter: $driveLetter"
    
    # Convert Windows path to WSL path
    $wslPath = (Split-Path -Path $fullPath -NoQualifier).Replace('\', '/')
    Write-Verbose "WSL path: $wslPath"
    
    # Get disk information
    $diskInfo = Get-DiskInfo -DriveLetter $driveLetter
    
    if ($diskInfo.IsSystemDisk) {
        throw "Operation denied: cannot manipulate system disk (Disk 0)"
    }
    
    Write-Information "Disk $($diskInfo.DiskNumber), Partition $($diskInfo.PartitionNumber)"
    
    # Set disk offline
    Write-Information "Setting disk offline..."
    Set-DiskOnlineStatus -DiskNumber $diskInfo.DiskNumber -Online $false
    
    # Mount in WSL
    Write-Information "Mounting disk in WSL..."
    Mount-WSLDisk -DiskNumber $diskInfo.DiskNumber
    
    # Prepare WSL directories
    Write-Verbose "Creating mount directories..."
    wsl.exe bash -c "mkdir -p $WSL_TEMP_PATH $WSL_MOUNT_PATH" 2>&1 | Out-Null
    
    # Mount partition (adjust /dev/sdXN according to your configuration)
    # Note: Device name may vary. You may need to adjust this logic.
    $deviceName = "/dev/sde$($diskInfo.PartitionNumber)"
    Write-Verbose "Mounting $deviceName to $WSL_TEMP_PATH"
    wsl.exe sudo mount $deviceName $WSL_TEMP_PATH 2>&1 | Out-Null
    
    # Display information
    Write-Host "`n`n" -NoNewline
    Write-Host " Container accessible at: $NETWORK_PATH " -ForegroundColor Green -BackgroundColor Black
    Write-Host " Press [Ctrl]+[C] to stop sharing...`n`n" -ForegroundColor DarkGray
    
    # Mount ZFF container
    wsl.exe ~/.cargo/bin/zffmount -i "$WSL_TEMP_PATH$wslPath" -m $WSL_MOUNT_PATH
    
}
catch {
    Write-Error "Error: $_"
    exit 1
}
finally {
    # Cleanup
    Write-Information "`nCleaning up..."
    
    # Unmount temporary directory
    try {
        wsl.exe sudo umount $WSL_TEMP_PATH 2>&1 | Out-Null
    }
    catch {
        Write-Warning "Unable to unmount $WSL_TEMP_PATH"
    }
    
    # Unmount WSL disk
    if ($diskInfo.DiskNumber) {
        Dismount-WSLDisk -DiskNumber $diskInfo.DiskNumber
        
        # Set disk back online
        Write-Information "Setting disk back online..."
        Set-DiskOnlineStatus -DiskNumber $diskInfo.DiskNumber -Online $true
    }
    
    Write-Information "Done."
}

#endregion
