<#
    .SYNOPSIS
        This script sends a Toast Notification to the user. Must run in PowerShell 5.
        Yu must first execute New-ToastApplication to create the Toast application.
        It must be executed in the currently signed in user's session.    

    .DESCRIPTION
        This script sends a Toast Notification to the user. Must run in PowerShell 5.
        You must first execute New-ToastApplication to create the Toast application.
        It uses the configured AppName to find the IconUri in the registry key.

    .PARAMETER ToastTitle
        The title of the Toast Notification.

    .PARAMETER ToastText
        The message of the Toast Notification.

    .PARAMETER ToastGroup
        The group of the Toast Notification. Default is the AppName.

    .PARAMETER ToastTag
        The tag of the Toast Notification. Default is the AppName.

    .PARAMETER ExpirationTime
        The time in minutes when the Toast Notification will expire. Default is 1 minute.

    .PARAMETER AppName
        The name of the Toast application. This will be used to find the IconUri in the
        registry key.

    .INPUTS
        This script does not support piped inputs.

    .OUTPUTS
        This script does not output anything.

    .EXAMPLE
        Examples:
        Show-ToastNotification -ToastTitle "Title" -ToastText "Message" -AppName "My App"
        Show-ToastNotification -ToastTitle "Title" -ToastText "Message" -ToastGroup "Group" -ToastTag "Tag" -AppName "My App" -ExpirationTime 5      

    .LINK
        Github: https://github.com/philixx93/SystemAdminScripts/tree/main
	Forked from spyingwind on Reddit: https://www.reddit.com/r/PowerShell/comments/zsr17a/ps_script_to_use_toast_or_other_notifications_to/

    .NOTES
        This script only runs on PowerShell 5.
#>

[CmdletBinding()]
Param (
    [string]
    [parameter(Mandatory = $True)]
    $ToastTitle,
    [string]
    [parameter(ValueFromPipeline, Mandatory = $True)]
    $ToastText,
    [string]
    $ToastGroup,
    [string]
    $ToastTag,
    [int]
    $ExpirationTime = 1,
    [string]
    [parameter(Mandatory = $True)]
    $AppName
)

if((Get-Host).Version.Major -ne 5) {
    Write-Error "This script requires PowerShell 5."
    return
}

$RegistryPath = "HKLM:\SOFTWARE\Classes\AppUserModelId\Windows.SystemToast.$($AppName -replace '\s+','')"
if (-not (Test-Path -Path $RegistryPath)) {
    Write-Error "Registry Key $RegistryPath not found. Please run New-ToastApplication first."
    return
}

$ImagePath = (Get-ItemProperty -Path $RegistryPath -Name "IconUri").IconUri
if (-not $?) {
    Write-Error "Could not get IconUri from registry. Please run New-ToastApplication first."
    return
} 
if (-not (Test-Path -Path $ImagePath -PathType leaf)) {
    Write-Error "Icon file not found. Please run New-ToastApplication first."
    return
}
if ($ToastGroup.Length -lt 1) {
    $ToastGroup = $AppName
}
if ($ToastTag.Length -lt 1) {
    $ToastTag = $AppName
}

# Import all the needed libraries
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.System.User, Windows.System, ContentType = WindowsRuntime] > $null
[Windows.System.UserType, Windows.System, ContentType = WindowsRuntime] > $null
[Windows.System.UserAuthenticationStatus, Windows.System, ContentType = WindowsRuntime] > $null

# Make sure that we can use the toast manager, also checks if the service is running and responding
try {
    $ToastNotifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Windows.SystemToast.$($AppName -replace '\s+','')")
}
catch {
    Write-Error $_
    Write-Error "Failed to create notification."
    return
}
# Use a template for our toast message
$Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)
$RawXml = [xml] $Template.GetXml()

# Edit the template to our liking, in this case just the Title, Message, and path to an image file
$($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "1" }).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
$($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "2" }).AppendChild($RawXml.CreateTextNode($ToastText)) > $null
if ($NodeImg = $RawXml.SelectSingleNode('//image[@id = ''1'']')) {
    $NodeImg.SetAttribute('src', $ImagePath) > $null
}

# Serialized Xml for later consumption
$SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
$SerializedXml.LoadXml($RawXml.OuterXml)

# Setup how are toast will act, such as expiration time
$Toast = $null
$Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
$Toast.Tag = $ToastTag
$Toast.Group = $ToastGroup
$Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($ExpirationTime)

# Show our message to the user
try {
    $ToastNotifier.Show($Toast)
}
catch {
    Write-Error "Failed to show notification. You can only send notifications to the user from a process running in the user's session."
}