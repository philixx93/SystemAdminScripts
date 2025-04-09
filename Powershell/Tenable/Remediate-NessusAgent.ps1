## Remediation Script for Intune Remediation Scripts.
## This Script is untested with OnPrem Installations.

$LinkingKey = "0123456789abcde" # Replace with your actual linking key
$Group = "defaultGroup" # Replace with your actual group name
$AgentPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"
$AgentHost = "sensor.cloud.tenable.com" # Default endpoint for Tenable Vulnerability Management
$AgentPort = 443 # Default port for Tenable Vulnerability Management
$ComputerName = "$env:COMPUTERNAME.$env:userdnsdomain"

# Options for the Nessus Agent
# See available options at: https://docs.tenable.com/nessus-agent/Content/SettingsAdvanced.htm
# Options here reflect the default values. You can modify them as needed.
# Please make sure that the options align with your detection script.
$Options = @{
    agent_update_channel            = "ga"
    update_hostname                 = "no"
    plugin_load_performance_mode    = "high"
    scan_performance_mode           = "high"
    ssl_mode                        = "tls_1_2"
}
Function Assert-NessusAgentRunningAndLinked {
    Process {
        if (Assert-NessusAgentLinked -ne 0) {
            return 1
        }
        $Status = & $AgentPath agent status
        if ($Status[0] -notlike "*Running: Yes*") {
            "Nessus Agent seems to be not running."
            return 1
        }
        if ($Status[2] -notlike "*Connected to $($AgentHost):$($AgentPort)*") {
            "Nessus Agent seems to be disconnected."
        }
        return 0
    }
}
Function Assert-NessusAgentInstalled {
    Process {
        if (-not (Test-Path $AgentPath -PathType Leaf)) {
            "nessuscli.exe not found."
            return 1
        }
    }
}
Function Assert-NessusAgentLinked {
    Process {
        if (Assert-NessusAgentInstalled -ne 0) {
            return 1
        }
        $Status = & $AgentPath agent status
        if ($Status[1] -notlike "*$($AgentHost):$($AgentPort)*") {
            "Nessus Agent seems to be not linked."
            return 1
        }
        return 0
    }
}

if (Assert-NessusAgentInstalled -ne 0) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://sensor.cloud.tenable.com/install/agent/installer/ms-install-script.ps1" -OutFile "./ms-install-script.ps1"; & "./ms-install-script.ps1" -key $LinkingKey -type "agent" -name "$ComputerName" -groups $Group; Remove-Item -Path "./ms-install-script.ps1"
    Start-Sleep -Seconds 60
    if (Assert-NessusAgentRunningAndLinked -ne 0) {
        "Installation Failed"
        exit 1
    }
    "Installation succeeded"
    Start-Sleep -Seconds 60
}

if (Assert-NessusAgentLinked -ne 0) {
    & $AgentPath agent link --key=$LinkingKey --groups=$Group --name="$ComputerName" --host $AgentHost --port $AgentPort
    Start-Sleep -Seconds 60
    if (Assert-NessusAgentRunningAndLinked -ne 0) {
        "Linking Failed"
        exit 1
    }
    "Linking succeeded"
}

foreach ($key in $Options.Keys) {
    $Setting = $Setting = & $AgentPath fix --get $key
    $Setting
    if ($Setting -notlike "*$($Options[$key])*") {
        "Key $key is not set to $($Options[$key])"
        "Setting $key to $($Options[$key])"
        $Result = & $AgentPath fix --set "$($key)=$($Options[$key])"
        if ($Result[0] -notlike "*Successfully set*") {
            "Failed setting key $key to $($Options[$key])"
            $Result
            exit 1
        }
        $Result[0]
    } 
    else {
        "Key $key is set to $($Options[$key])"
    }
}
"All good"
exit 0