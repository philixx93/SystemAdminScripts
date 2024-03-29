<#
    .SYNOPSIS
        This script creates a new Toast application for Windows 10/11 Toast Notifications.
        Must run as Administrator.

    .DESCRIPTION
        This script creates a new Toast application for Windows 10/11 Toast Notifications. 
        It will create a registry key with the DisplayName and IconUri for the Toast 
        application. The IconUri can be a Base64 string or a path to an image file. If 
        the image file does not exist, it will be created from the Base64 string. If 
        you use the Confirm switch, the script will also ask for confirmation before 
        overwriting existing files or registry keys. Must run as Administrator.

    .PARAMETER ImagePath
        This either the path to an image file or the path where the image file will be 
        saved. If you provide a Base64 string, the image file will be created from the
        Base64 string. This is used as the IconUri in the registry key. Make sure that
        is is not in a temporary folder and all users have access to it.

    .PARAMETER Base64String
        A Base64 string of the image file. If you provide a Base64 string, the image file
        will be created from the Base64 string. If you provide a Base64 string and an 
        image file, the image file will be overwritten with the Base64 string. Please make 
        sure that the Base64 string matches the filetype of the image file.

    .PARAMETER AppName
        The name of the Toast application. This will be used as the DisplayName in the 
        registry key. If you use spaces in the AppName, they will be replaced by '.'
        in the registry path.

    .PARAMETER Confirm
        If this switch is present, the script will ask for confirmation before overwriting
        existing files or registry keys.
    
    .PARAMETER ShowInSettings
        If this switch is present, the registry key will be created with the ShowInSettings
        value set to 1. This will show the application in the Windows Settings.

    .INPUTS
        This script does not support piped inputs.

    .OUTPUTS
        This script does not output anything.

    .EXAMPLE
        Examples:
        New-ToastApplication -ImagePath "C:\Path\to\my\app\MyIcon.png" -AppName "My App"
        New-ToastApplication -ImagePath "C:\Path\to\my\app\MyIcon.png" -Base64String "ExampleString==" -AppName "My App" -Confirm
        New-ToastApplication -ImagePath "C:\Path\to\my\app\MyIcon.png" -Base64String "ExampleString==" -AppName "My App" -ShowInSettings

    .LINK
        Github: https://github.com/philixx93/SystemAdminScripts/tree/main
	Forked from spyingwind on Reddit: https://www.reddit.com/r/PowerShell/comments/zsr17a/ps_script_to_use_toast_or_other_notifications_to/

    .NOTES
        This script should be compatible with PowerShell 5 and 7. However, it is recommended
        to use PS 5 since Show-ToastNotifications will only run in PowerShell 5.

#>

#Requires -RunAsAdministrator
#Requires -Version 5

[CmdletBinding()]
Param (
    [string]
    [parameter(Mandatory = $True)]
    $ImagePath,
    [string]
    $Base64String,
    [string]
    [parameter(Mandatory = $True)]
    $AppName,
    [switch]
    $Confirm,
    [switch]
    $ShowInSettings
)

$RegistryPath = "HKLM:\SOFTWARE\Classes\AppUserModelId\Windows.SystemToast.$($AppName -replace '\s+','')"

if ( (-not (Test-Path -Path $ImagePath -PathType Leaf)) -and ($Base64String.Length -lt 1) ) {
    Write-Error "You must either provide a Base64 string or an image file."
    return
}
if ((Test-Path -Path $ImagePath -PathType Leaf) -and ($Confirm.IsPresent) -and ($Base64String.Length -gt 0)) {
    Write-Host "Image file already exists and a Base64 String was provided. Do you want to overwrite it? (Y/N)"
    $Answer = Read-Host
    if ($Answer -ne "Y") {
        return
    }
}
if ( (Test-Path -Path $RegistryPath) -and ($Confirm.IsPresent) ) {
    Write-Host "The Registry entries seem to already exist. Do you want to overwrite them? (Y/N)"
    $Answer = Read-Host
    if ($Answer -ne "Y") {
        return
    }
}
if ($Base64String.Length -gt 0) {
    $bytes = [Convert]::FromBase64String($Base64String)
    [IO.File]::WriteAllBytes($ImagePath, $bytes)
}
if ( -not (Test-Path -Path $RegistryPath) ) {
    New-Item -Path $RegistryPath | Out-Null
} 
Set-ItemProperty -Path $RegistryPath -Name "DisplayName" -Value "$AppName"
Set-ItemProperty -Path $RegistryPath -Name "IconUri" -Value "$ImagePath"
if ($ShowInSettings.IsPresent) {
    Set-ItemProperty -Path $RegistryPath -Name "ShowInSettings" -Type DWord -Value 1
}
else {
    Set-ItemProperty -Path $RegistryPath -Name "ShowInSettings" -Type DWord -Value 0
}