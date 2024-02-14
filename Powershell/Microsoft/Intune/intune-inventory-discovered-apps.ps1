
<#
    .SYNOPSIS
        Lists all discovered apps with versions

    .DESCRIPTION
        Lists all discovered apps with versions. This script will connect to MS Graph 
        and pull all discovered apps from all devices. It will then display the apps 
        in a GUI with a drill-down to show the devices that have the app installed.

    .INPUTS
        None on the CLI. However, you will have to authenticate to MS Graph.

    .OUTPUTS
        Creates a log file in %Temp%

    .LINK
        Github: https://github.com/philixx93/SystemAdminScripts/tree/main
        Forked from https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/intune-inventory-discovered-apps.ps1

    .NOTES
        Tested with PowerShell 7.
        Forked from https://github.com/andrew-s-taylor/public/blob/main/Powershell%20Scripts/Intune/intune-inventory-discovered-apps.ps1
 
    .EXAMPLE
        N/A
#>


$ErrorActionPreference = "Continue"
##Start Logging to %TEMP%\intune.log
Start-Transcript -Path $env:TEMP\intune-$(get-date -format yyyyMMddTHHmmssffff).log

Function Open-PSModule {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)] [string]$Name
    )

    Process {
        if (Get-Module -ListAvailable -Name $Name) {
            Write-Host "Module $Name already installed"
        } 
        else {
            Write-Host "Installing $Name module (current user scope)"
            try {
                Install-Module -Name $Name -Scope CurrentUser -Repository PSGallery -Force 
                Write-Host "Installing $Name module finished"
                # Load the module
                Import-Module $Name
            }
            catch [Exception] {
                throw "Failed to install module $Name"
            }
        }
    }
} 

#Install MS Graph modules if not available
try{
    Open-PSModule -Name Microsoft.Graph.Authentication
    Open-PSModule -Name Microsoft.Graph.DeviceManagement
}
catch [Exception] {
    Write-Error "Failed to install module with error: $($_.message)"
    exit 1
}
  
##Connect to MS Graph
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All, DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All" -NoWelcome

##Grab all devices
$devicesWithApps = @()
$i = 0
Get-MgDeviceManagementManagedDevice -CountVariable n
Get-MgDeviceManagementManagedDevice -Property Id | ForEach-Object { 
    Write-Progress -Activity "Collecting device data" -Status "Collected $i of $n devices" -PercentComplete $(($i / $n) * 100)
    $apps = (Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$($_.id)')?`$expand=detectedApps" -Method GET -OutputType PSObject)
    $devicesWithApps += $apps
    $i++
}
Write-Progress -Activity "Collecting device data" -Completed

##Populate App array
$allApps = Get-MgDeviceManagementDetectedApp -All | Select-Object DeviceCount, DisplayName
# Run while User hasn't canceled or closed the window
while (1) {
    ##Group the apps to get a count, sort and then display in GUI with drill-down
    $selectedApp = $allApps | Sort-Object DeviceCount -Descending | Out-GridView -Title "Discovered Apps" -OutputMode Single
    if ($null -eq $selectedApp) {
        break
    }

    ##Create an array of devicesdetails and app version for later display
    $appslist = @()

    ##Loop through machines looking for the app
    foreach ($device in $devicesWithApps) {
        ##App found, grab the details
        foreach ($app in $device.detectedApps) {
            if ($app.DisplayName -eq $selectedApp.DisplayName) {
                $appslist += New-Object psobject -Property @{
                    "DeviceName"       = $device.deviceName
                    "DeviceID"         = $device.id
                    "LastSyncDateTime" = $device.lastSyncDateTime
                    "OperatingSystem"  = $device.operatingSystem
                    "User"             = $device.emailAddress
                    "AppName"          = $app.DisplayName
                    "AppVersion"       = $app.version
                    "AppID"            = $app.Id
                }
            }
        }
    }
    $appslist | Out-GridView -Title "$($selectedApp.DisplayName)" -Wait    
}
Stop-Transcript