## Detection script for Intune Remediation Scripts.

$AgentPath = "C:\Program Files\Tenable\Nessus Agent\nessuscli.exe"

# This is the default endpoint in the Tenable Cloud.
# Change this if you are running onprem.
$SensorEndpoint = "sensor.cloud.tenable.com:443"

# Options for the Nessus Agent
# See available options at: https://docs.tenable.com/nessus-agent/Content/SettingsAdvanced.htm
# Options here reflect the default values
$Options = @{
    agent_update_channel            = "ga"
    update_hostname                 = "no"
    plugin_load_performance_mode    = "high"
    scan_performance_mode           = "high"
    ssl_mode                        = "tls_1_2"
}

if (-not (Test-Path $AgentPath -PathType Leaf)) {
    "nessuscli.exe not found."
    exit 1
}
$Status = & $AgentPath agent status
if ($Status[1] -notlike "*$SensorEndpoint*") {
    "Nessus Agent seems to be not linked."
    exit 1
}
foreach ($key in $Options.Keys) {
    $Setting = $Setting = & $AgentPath fix --get $key
    $Setting
    if ($Setting -notlike "*$($Options[$key])*") {
        "Key $key is not set to $($Options[$key])"
        exit 1
    } 
}
exit 0