<#
    .SYNOPSIS
        This script downloads a cloud2cloud backup of your Confluence Cloud instance.
        Requires at least Powershell 7.

    .DESCRIPTION
        Using this script you can create and download cloud2cloud backups of your Confluence 
        Cloud Instance. You must provide at least an API Token File, your email address 
        and the domain of your Confluence Cloud instance. Requires at least Powershell 7.
        Return Codes:
        0 = all fine
        1 = Backup creation failed with undefined HTTP status code
        2 = invalid input supplied
        3 = webrequest for download failed
        4 = Backup creation failed
        5 = Backup creation failed with undefined error message
        10 = Backup succeeded but was downgraded to exclude attachments
        401 = InvaliD login credentials"

    .PARAMETER ApiTokenFile
        The file containing the API token for your Confluence Cloud instance. The file should 
        contain only the API token and no other information, blanks or line breaks.

    .PARAMETER email
        Logon email address associated with the API token.

    .PARAMETER DownloadAttachments
        Whether or not to download attachments. Default is true. Note that as of writing 
        this script you can only create a with attachments every 24 hours.

    .PARAMETER OutputDirectory
        The directory where the backup will be saved. Default is the current directory.

    .PARAMETER Domain
        The domain of your Confluence Cloud instance. Do not include the protocol (https://) 
        or the trailing slash. Example: mycompany.atlassian.net you can either provide 
        just mycompany or the whole domain. Note that custom domains are not supported.

    .PARAMETER WaitMinutes
        The maximum timeout in minutes until the backup is downgraded to exclude attach-
        ments. Default is 10 minutes. This does only apply if DownloadAttachments is set
        to true. 0 will disable the timeout and cause the script to fail immediately if
        the first attempt to create the backup fails.

    .PARAMETER DebugEnable
        Enable debug output. Default is false. If debug is enabled the transcript will
        be enabled too.The transcript will be saved in the output directory with the 
        filename confluence-cloud-backup-YYYYMMDD-HH.mm.log.

    .PARAMETER TranscriptEnable
        Enable transcript. Default is false. The transcript will be saved in the output
        directory with the filename confluence-cloud-backup-YYYYMMDD-HH.mm.log.

    .INPUTS
        This script does not support piped inputs.

    .OUTPUTS
        .zip file containing the backup of your Confluence Cloud instance.

    .EXAMPLE
        Examples:
        .\confluence-cloud-backup.ps1 -ApiTokenFile "C:\path\to\api-token.txt" -email "test@example.com" -Domain "mycompany"
        .\confluence-cloud-backup.ps1 -ApiTokenFile "C:\path\to\api-token.txt" -email "test@example.com" -Domain "mycompany" -DownloadAttachments "false" -OutputDirectory "C:\path\to\backup" -WaitMinutes 5 -DebugEnable

    .LINK
        Github: https://github.com/philixx93/SystemAdminScripts/tree/main
        How to create an API token: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
        Forked from the Atlassian Scripts: https://bitbucket.org/atlassianlabs/automatic-cloud-backup/src/master/

    .NOTES
        I developed this script to work with Veeam. If you happen to fin any issues, please
        raise an issue on Github. I will try to fix it as soon as possible. Requires at least 
        Powershell 7.
        The reason for the WaitMinutes is that Atlassian counts 24 hours from the moment the 
        backup was ready. This means that if you schedule this script to run every 24 hours
        it will fail every second day. The timeout is a workaround for this issue, so that it
        only downgrades about once per week (instead of every second day). If you have a 
        better idea, please let me know.
#>
Param(
    [Parameter(Mandatory=$True)]
    [string]$ApiTokenFile,
    [Parameter(Mandatory=$True)]
    [string]$email,
    [ValidateSet('true', 'false')]
    [string]$DownloadAttachments = 'true',
    [string]$OutputDirectory = $(pwd),
    [Parameter(Mandatory=$True)]
    [string]$Domain,
    [int]$WaitMinutes = 10,
    [bool]$DebugEnable = $false,
    [bool]$TranscriptEnable = $false
)

if($DebugEnable -or $TranscriptEnable){
    Start-Transcript -Path $OutputDirectory\confluence-cloud-backup-$(Get-Date -Format "yyyyMMdd-HH.mm").log -Append
}
if($DebugEnable){
    $DebugPreference = "Continue"
    Set-PSDebug -Trace 2
    Write-Debug "Exit codes: 0 = all fine; 1 = Backup creation failed with undefined HTTP status code; 2 = invalid input supplied; 3 = webrequest for download failed; 4 = Backup creation failed; 5 = Backup creation failed with undefined error message; 10 = Backup succeeded but was downgraded to exclude attachments; 401 = Invalid login credentials"
}

function IsValidEmail { 
    param([string]$EmailAddress)

    try {
        $null = [mailaddress]$EmailAddress
        return $true
    }
    catch {
        return $false
    }
}

$exitCode = 0
if($OutputDirectory -NotLike "*\"){
    $OutputDirectory = $OutputDirectory + "\"
}
if(Test-Path $OutputDirectory -PathType Container){
    Write-Debug "Output Directory is present"
}
else{
    Write-Debug "Output Directory is not present, creating directory"
    New-Item -Path $OutputDirectory -ItemType Directory
    if(!(Test-Path $OutputDirectory -PathType Container)){
        Write-Error "Failed to create directory, please check permissions and try again"
        exit 2
    }
}
if($WaitMinutes -lt 0)
{
    Write-Error "WaitMinutes must be 0 or greater"
    exit 2
}
if(!(IsValidEmail $email)){
    Write-Error "Email address is not valid"
    exit 2
}

#check if $ApiTokenFile exists
if(!(Test-Path $ApiTokenFile -PathType Leaf)){
    Write-Error "File is not present, please create file with API token. See how to create an API token: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/"
    exit 2
}
else{
    Write-Debug "API Token File is present"
}
$apiToken = ConvertTo-SecureString $(Get-Content -Path $ApiTokenFile -TotalCount 1) -AsPlainText -Force

if($Domain -NotLike "*.atlassian.net"){
    $Domain = $Domain + ".atlassian.net"
}
if(($DownloadAttachments -ne 'true') -and ($DownloadAttachments -ne 'false')){ # Tells the script whether or not to pull down the attachments as well
    Write-Error "Invalid input for DownloadAttachments: $DownloadAttachments must be true or false"
}

$cloud = 'true' # Tells the script whether to export the backup for Cloud or Server

# Set Atlassian API credentials, headers, and other specifics
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($email):$(ConvertFrom-SecureString -SecureString $apiToken -AsPlainText)"))
$headers = @{
    "Authorization" = "Basic $auth"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

#Set body
$body = @{
          cbAttachments=$DownloadAttachments
          exportToCloud=$cloud
         }
$bodyjson = $body | ConvertTo-Json

# Set Atlassian Cloud backup endpoint
$backupEndpoint = "https://$Domain/wiki/rest/obm/1.0/runbackup"
$backupStatusURL = "https://$Domain/wiki/rest/obm/1.0/getprogress"

# Create a Confluence Cloud backup
Write-host "Creating Confluence backup..."
$count = 0
do {
    try {
        $finished = $true
        $count++
        $backupResponse = Invoke-WebRequest -Method POST -Uri $backupEndpoint -Headers $headers -Body $bodyjson  
        Write-Debug "Backup creation successful. HTTP Status Code: $($backupResponse.StatusCode)"
    }
    catch {
        if($WaitMinutes -eq 0 -or $DownloadAttachments -eq 'false'){
            Write-Error "Backup creation failed"
            exit 4
        }
        if($_ -Like "*must be authenticated*"){
            Write-Error "Authentication Error: $_"
            exit 401
        }
        if($_ -NotLike "*frequency is limited*"){
            Write-Error "Unknown Error: $_"
            exit 5
        }
        $finished = $false
        $timeout = [int](($count / $WaitMinutes) * 100)
        Write-Progress -Activity "Waiting for timeout" -Status "Timeout $timeout% passed" -PercentComplete $timeout
        Write-Debug "Error message: $($_.message)"
        Write-Debug "Backup creation failed, waiting 60 seconds before trying again"
        Start-Sleep -Seconds 60
    }
    if($count -ge $WaitMinutes -and $finished -eq $false){
        $timeout = 100
        Write-Progress -Activity "Waiting for timeout" -Status "Timeout $timeout% passed" -PercentComplete $timeout
        Write-Debug "Timeout reached, trying to create backup without attachments instead"
        try {
            $body = @{
                cbAttachments='false'
                exportToCloud=$cloud
            }
            $bodyjson = $body | ConvertTo-Json
            $backupResponse = Invoke-WebRequest -Method POST -Uri $backupEndpoint -Headers $headers -Body $bodyjson
            $finished = $true
            $exitCode = 10
        }
        catch {
            Write-Error "Backup creation failed" 
            exit 4
        }
    }
} while ($finished -ne $true)
$timeout = 100
Write-Progress -Activity "Waiting for timeout" -Status "Timeout $timeout% passed" -PercentComplete $timeout

$progress = 0
Write-Progress -Activity "Backup in Progress" -Status "$progress% Complete:" -PercentComplete $progress
# Check if backup creation was successful
if ($backupResponse.StatusCode -eq 200) {
    $waitDelay = 10
    # Wait for the backup to be ready
    $backupReady = $false
    while (!$backupReady) {
        Write-Debug "We are waiting $waitDelay seconds to check the status of your backup. Current progress: $progress%"
        Start-Sleep -Seconds $waitDelay
        #Get Backup Session ID
        $backupStatus = Invoke-WebRequest -Method GET -Headers $headers $backupStatusURL
        $statusResponse = $backupStatus
        $statusContent = $statusResponse.Content | ConvertFrom-Json
        $progress = [string]$statusContent.alternativePercentage
        $backupReady = $progress -like "*100%*"
        if($progress -like "*longer*") {
            $progress = 99
        }
        else {
            $progress = $progress.replace("Estimated progress: ","").replace("%","")
        }
        Write-Progress -Activity "Backup in Progress" -Status "$progress% Complete:" -PercentComplete $progress
    }
    Write-Host "Backup is ready to download"

    # Identify file locaiton to download
    $parseResults = $backupStatus.Content | ConvertFrom-Json
    $backupLocation = $parseResults.fileName
    # Download the backup file
    $backupUrl = "https://$Domain/wiki/download/$backupLocation"
    $backupFilename = "confluence-backup-" + $(Get-Date -Format "yyyyMMdd-HH.mm") + ".zip"
    try {
        Invoke-WebRequest -Method Get -Uri $backupUrl -Headers $headers -OutFile $OutputDirectory$backupFilename
    }
    catch {
        Write-Error "Webrequest failed: $_"
        exit 3
    }
    Write-Host "Backup saved as $OutputDirectory$backupFilename"
} else {
    Write-Error "Error: Failed to create Confluence backup. Status code: $($backupResponse.StatusCode)"
    exit 1
} 
Stop-Transcript
exit $exitCode