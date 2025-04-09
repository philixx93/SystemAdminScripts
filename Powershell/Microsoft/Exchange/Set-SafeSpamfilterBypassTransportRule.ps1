<# 
    .SYNOPSIS
    This script helps you creating safer transport rules in Exchange Online.

    .DESCRIPTION
    This script implements a transport rule that bypasses the spam filter
    for a specific email address or domain. It follows the best practice for transport rules
    as described by Microsoft here:
    https://learn.microsoft.com/en-us/defender-office-365/create-safe-sender-lists-in-office-365#use-mail-flow-rules
    If you are unsure about the best practice, you can use the -Confirm switch to get a prompt
    before creating the rule.
    This script requires at least PowerShell 5 and ExchangeOnlineManagement module version 3.0.0 or higher.

    .PARAMETER MailAddress
    The email addresses to bypass the spam filter for. Either MailAddress or MailDomain must be provided.

    .PARAMETER MailDomain
    The domains to bypass the spam filter for. Either MailAddress or MailDomain must be provided.

    .PARAMETER RuleName
    The name of the transport rule. If not provided, the rule name will be generated from the MailAddress or MailDomain.

    .PARAMETER MatchSenderAddressInMessage
    The location in the message where the sender address is matched. Default is 'Header'.

    .PARAMETER CustomHeaderText
    The text to add to the custom header. If you don't provide it a default is generated.

    .PARAMETER CustomHeader
    The name of the custom header. Default is 'X-ETR'.

    .PARAMETER SetCustomHeader
    Flag to set a custom header in the email.

    .PARAMETER DmarcCheck
    Flag to enable DMARC check.

    .PARAMETER SpfCheck
    Flag to enable SPF check.

    .PARAMETER StopRuleProcessing
    Flag to stop rule processing after this rule.

    .PARAMETER Confirm
    Flag to confirm before creating the rule in case the configuration deviates from the best practice.

    .PARAMETER WhatIf
    Flag to simulate the creation of the rule.

    .PARAMETER Verbose
    Flag to output the arguments to the console.

    .PARAMETER RuleEnabled
    Flag to enable the rule right after creation.

    .PARAMETER Priority
    The priority of the rule. Default is none, therfore it will be placed last.

    .EXAMPLE
    Unless you have reasons to deviate from the best practice, I recommend to use at least these Switches:
    -DmarcCheck -SpfCheck -SetCustomHeader

    This will bypass the spam filter for the domain, follow Microsofts best practice, set the priority to 1 and enable the rule.
    Set-SafeSpamfilterBypassTransportRule -MailDomain "example.com" -DmarcCheck -SpfCheck -SetCustomHeader -RuleEnabled -Priority 1
    Or for multiple domains:
    Set-SafeSpamfilterBypassTransportRule -MailDomain ("example.com","test.com") -DmarcCheck -SpfCheck -SetCustomHeader -RuleEnabled -Priority 1

    This will bypass the spam filter for the mail address and follow Microsofts best practice.
    Set-SafeSpamfilterBypassTransportRule -MailAddress "admin@example.com" -DmarcCheck -SpfCheck -SetCustomHeader
    Or multiple mail addresses:
    Set-SafeSpamfilterBypassTransportRule -MailAddress ("admin@example.com","test@test.com") -DmarcCheck -SpfCheck -SetCustomHeader

    .LINK
    Github: https://github.com/philixx93/SystemAdminScripts/tree/main
#>
#Requires -Version 5
Param(
    [string[]]$MailAddress,
    [string[]]$MailDomain,
    [string]$RuleName,
    [ValidateSet('Header', 'Envelope', 'HeaderOrEnvelope')]
    [string]$MatchSenderAddressInMessage = 'Header',
    [string]$CustomHeaderText,
    [string]$CustomHeader = 'X-ETR',
    [switch]$SetCustomHeader,
    [switch]$DmarcCheck,
    [switch]$SpfCheck,
    [switch]$StopRuleProcessing,
    [switch]$Confirm,
    [switch]$WhatIf,
    [switch]$Verbose,
    [switch]$RuleEnabled,
    [int]$Priority = -1
)
if ((Get-InstalledModule -Name ExchangeOnlineManagement).Version -lt "3.0.0") {
    Write-Error "Please install the ExchangeOnlineManagement module version 3.0.0 or higher."
    Write-Error "Find the module here: https://www.powershellgallery.com/packages/ExchangeOnlineManagement"
    Write-Error "Install it with: Install-Module -Name ExchangeOnlineManagement -MinimumVersion 3.0.0"
    exit 1
}
$BestPracticeMet = $true
$CustomHeaderPresent = $false
$RuleNamePresent = $false
if ($CustomHeaderText.Length -gt 0) {
    $CustomHeaderPresent = $true
}
if ($RuleName.Length -gt 0) {
    $RuleNamePresent = $true
    if($MailAddress.Length -gt 1 -or $MailDomain.Length -gt 1) {
        Write-Error "RuleName is set, but multiple Mail Addresses or Domains are provided. The RuleName must be unique. Please call the script on each item with a custom RuleName or leave RuleName unset."
        exit 1
    }
}
if ((($($MailAddress.Length) -lt 1) -and ($($MailDomain.Length) -lt 1)) -or (($($MailAddress.Length) -gt 0) -and ($($MailDomain.Length) -gt 0))) {
    Write-Error "Please provide either a mail address or a mail domain."
    exit 1
}
if ((Get-ConnectionInformation).State -notlike '*Connected*') {
    Connect-ExchangeOnline
    $ConnectionState = Get-ConnectionInformation
    if ($ConnectionState.State -notlike '*Connected*') {
        Write-Error "Failed to connect to Exchange Online. Exiting."
        Write-Error "This can be due to an earlier session in the same shell. Please restart the shell or run Disconnect-ExchangeOnline"
        Write-Error "Connection State: $($ConnectionState | Select-Object *)"
        exit 1
    }
}
if ($MatchSenderAddressInMessage -ne 'Header') {
    $BestPracticeMet = $false
    Write-Warning "MatchSenderAddressInMessage is not set to 'header', this might enable Spoofing of the Mail Address."
}
if (-not $SetCustomHeader) {
    $BestPracticeMet = $false
    Write-Warning "The flagging the Mail with a custom header is disabled. This will make it hard for you to debug any errors in rule processing later on."
}
if (-not $DmarcCheck) {
    $BestPracticeMet = $false
    Write-Warning "DMARC Check is disabled, this might enable Spoofing of the Mail Address."
}
if (-not $SpfCheck) {
    $BestPracticeMet = $false
    Write-Warning "SPF Check is disabled, this might enable Spoofing of the Mail Address."
}
if ($Confirm -and (-not $BestPracticeMet)) {
    Read-Host "The best practice for transport rules is not met. Do you want to continue anyway? (Ctrl+C to cancel)"
}
$Arguments = @{}
$Arguments.Add('SenderAddressLocation', $MatchSenderAddressInMessage)
$Arguments.Add('StopRuleProcessing', $StopRuleProcessing)
$Arguments.Add('SetSCL', -1)
if ($DmarcCheck) {
    $Arguments.Add('HeaderContainsMessageHeader', 'Authentication-Results')
    $Arguments.Add('HeaderContainsWords', ("dmarc=pass", "dmarc=bestguesspass"))
}
if ($SpfCheck) {
    $Arguments.Add('HeaderMatchesMessageHeader', 'Received-SPF')
    $Arguments.Add('HeaderMatchesPatterns', 'Pass')
}
if ($RuleEnabled) {
    $Arguments.Add('Enabled', $true)
}
else {
    $Arguments.Add('Enabled', $false)
}
if ($WhatIf) {
    $Arguments.Add('WhatIf', $true)
}
if ($Priority -ge 0) {
    $Arguments.Add('Priority', $Priority)
}
if ($MailAddress.Length -gt 0) {
    $Size = $MailAddress.Length
}
else {
    $Size = $MailDomain.Length
}
for ($i = 0; $i -lt $Size; $i++) {
    if ($MailAddress.Length -gt 0) {
        $Arguments['From'] = $MailAddress[$i]
        $Name = $MailAddress[$i]
    }
    elseif ($MailDomain.Length -gt 0) {
        $Arguments['SenderDomainIs'] = $MailDomain[$i]
        $Name = $MailDomain[$i]
    }
    if (-not $CustomHeaderPresent) {
        $CustomHeaderText = "Bypass spam filtering for authenticated sender $Name"
    }
    if ($SetCustomHeader) {
        $Arguments['SetHeaderName'] = $CustomHeader
        $Arguments['SetHeaderValue'] = $CustomHeaderText
    }
    if (-not $RuleNamePresent) {
        $RuleName = "$Name bypass Spam Filter"
    }
    $Arguments['Name'] = $RuleName
    if ($Verbose) {
        $Arguments | Out-String | Write-Host
    }
    $Result = New-TransportRule @Arguments
    if ($? -eq $true -and $($Result.IsRuleConfigurationSupported) -eq $true) {
        Write-Host "Transport rule '$($Result.Name)' with Priority $($Result.Priority) created successfully." 
    }
    elseif (-not $WhatIf) {
        Write-Error "Failed to create transport rule."
        exit 1
    }
}
exit 0<# 
    .SYNOPSIS
    This script helps you creating safer transport rules in Exchange Online.

    .DESCRIPTION
    This script implements a transport rule that bypasses the spam filter
    for a specific email address or domain. It follows the best practice for transport rules
    as described by Microsoft here:
    https://learn.microsoft.com/en-us/defender-office-365/create-safe-sender-lists-in-office-365#use-mail-flow-rules
    If you are unsure about the best practice, you can use the -Confirm switch to get a prompt
    before creating the rule.
    This script requires at least PowerShell 5 and ExchangeOnlineManagement module version 3.0.0 or higher.

    .PARAMETER MailAddress
    The email addresses to bypass the spam filter for. Either MailAddress or MailDomain must be provided.

    .PARAMETER MailDomain
    The domains to bypass the spam filter for. Either MailAddress or MailDomain must be provided.

    .PARAMETER RuleName
    The name of the transport rule. If not provided, the rule name will be generated from the MailAddress or MailDomain.

    .PARAMETER MatchSenderAddressInMessage
    The location in the message where the sender address is matched. Default is 'Header'.

    .PARAMETER CustomHeaderText
    The text to add to the custom header. If you don't provide it a default is generated.

    .PARAMETER CustomHeader
    The name of the custom header. Default is 'X-ETR'.

    .PARAMETER SetCustomHeader
    Flag to set a custom header in the email.

    .PARAMETER DmarcCheck
    Flag to enable DMARC check.

    .PARAMETER SpfCheck
    Flag to enable SPF check.

    .PARAMETER StopRuleProcessing
    Flag to stop rule processing after this rule.

    .PARAMETER Confirm
    Flag to confirm before creating the rule in case the configuration deviates from the best practice.

    .PARAMETER WhatIf
    Flag to simulate the creation of the rule.

    .PARAMETER Verbose
    Flag to output the arguments to the console.

    .PARAMETER RuleEnabled
    Flag to enable the rule right after creation.

    .PARAMETER Priority
    The priority of the rule. Default is none, therfore it will be placed last.

    .EXAMPLE
    Unless you have reasons to deviate from the best practice, I recommend to use at least these Switches:
    -DmarcCheck -SpfCheck -SetCustomHeader

    This will bypass the spam filter for the domain, follow Microsofts best practice, set the priority to 1 and enable the rule.
    Set-SafeSpamfilterBypassTransportRule -MailDomain "example.com" -DmarcCheck -SpfCheck -SetCustomHeader -RuleEnabled -Priority 1
    Or for multiple domains:
    Set-SafeSpamfilterBypassTransportRule -MailDomain ("example.com","test.com") -DmarcCheck -SpfCheck -SetCustomHeader -RuleEnabled -Priority 1

    This will bypass the spam filter for the mail address and follow Microsofts best practice.
    Set-SafeSpamfilterBypassTransportRule -MailAddress "admin@example.com" -DmarcCheck -SpfCheck -SetCustomHeader
    Or multiple mail addresses:
    Set-SafeSpamfilterBypassTransportRule -MailAddress ("admin@example.com","test@test.com") -DmarcCheck -SpfCheck -SetCustomHeader

    .LINK
    Github: https://github.com/philixx93/SystemAdminScripts/tree/main
#>
#Requires -Version 5
Param(
    [string[]]$MailAddress,
    [string[]]$MailDomain,
    [string]$RuleName,
    [ValidateSet('Header', 'Envelope', 'HeaderOrEnvelope')]
    [string]$MatchSenderAddressInMessage = 'Header',
    [string]$CustomHeaderText,
    [string]$CustomHeader = 'X-ETR',
    [switch]$SetCustomHeader,
    [switch]$DmarcCheck,
    [switch]$SpfCheck,
    [switch]$StopRuleProcessing,
    [switch]$Confirm,
    [switch]$WhatIf,
    [switch]$Verbose,
    [switch]$RuleEnabled,
    [int]$Priority = -1
)
if ((Get-InstalledModule -Name ExchangeOnlineManagement).Version -lt "3.0.0") {
    Write-Error "Please install the ExchangeOnlineManagement module version 3.0.0 or higher."
    Write-Error "Find the module here: https://www.powershellgallery.com/packages/ExchangeOnlineManagement"
    Write-Error "Install it with: Install-Module -Name ExchangeOnlineManagement -MinimumVersion 3.0.0"
    exit 1
}
$BestPracticeMet = $true
$CustomHeaderPresent = $false
$RuleNamePresent = $false
if ($CustomHeaderText.Length -gt 0) {
    $CustomHeaderPresent = $true
}
if ($RuleName.Length -gt 0) {
    $RuleNamePresent = $true
    if($MailAddress.Length -gt 1 -or $MailDomain.Length -gt 1) {
        Write-Error "RuleName is set, but multiple Mail Addresses or Domains are provided. The RuleName must be unique. Please call the script on each item with a custom RuleName or leave RuleName unset."
        exit 1
    }
}
if ((($($MailAddress.Length) -lt 1) -and ($($MailDomain.Length) -lt 1)) -or (($($MailAddress.Length) -gt 0) -and ($($MailDomain.Length) -gt 0))) {
    Write-Error "Please provide either a mail address or a mail domain."
    exit 1
}
if ((Get-ConnectionInformation).State -notlike '*Connected*') {
    Connect-ExchangeOnline
    $ConnectionState = Get-ConnectionInformation
    if ($ConnectionState.State -notlike '*Connected*') {
        Write-Error "Failed to connect to Exchange Online. Exiting."
        Write-Error "This can be due to an earlier session in the same shell. Please restart the shell or run Disconnect-ExchangeOnline"
        Write-Error "Connection State: $($ConnectionState | Select-Object *)"
        exit 1
    }
}
if ($MatchSenderAddressInMessage -ne 'Header') {
    $BestPracticeMet = $false
    Write-Warning "MatchSenderAddressInMessage is not set to 'header', this might enable Spoofing of the Mail Address."
}
if (-not $SetCustomHeader) {
    $BestPracticeMet = $false
    Write-Warning "The flagging the Mail with a custom header is disabled. This will make it hard for you to debug any errors in rule processing later on."
}
if (-not $DmarcCheck) {
    $BestPracticeMet = $false
    Write-Warning "DMARC Check is disabled, this might enable Spoofing of the Mail Address."
}
if (-not $SpfCheck) {
    $BestPracticeMet = $false
    Write-Warning "SPF Check is disabled, this might enable Spoofing of the Mail Address."
}
if ($Confirm -and (-not $BestPracticeMet)) {
    Read-Host "The best practice for transport rules is not met. Do you want to continue anyway? (Ctrl+C to cancel)"
}
$Arguments = @{}
$Arguments.Add('SenderAddressLocation', $MatchSenderAddressInMessage)
$Arguments.Add('StopRuleProcessing', $StopRuleProcessing)
$Arguments.Add('SetSCL', -1)
if ($DmarcCheck) {
    $Arguments.Add('HeaderContainsMessageHeader', 'Authentication-Results')
    $Arguments.Add('HeaderContainsWords', ("dmarc=pass", "dmarc=bestguesspass"))
}
if ($SpfCheck) {
    $Arguments.Add('HeaderMatchesMessageHeader', 'Received-SPF')
    $Arguments.Add('HeaderMatchesPatterns', 'Pass')
}
if ($RuleEnabled) {
    $Arguments.Add('Enabled', $true)
}
else {
    $Arguments.Add('Enabled', $false)
}
if ($WhatIf) {
    $Arguments.Add('WhatIf', $true)
}
if ($Priority -ge 0) {
    $Arguments.Add('Priority', $Priority)
}
if ($MailAddress.Length -gt 0) {
    $Size = $MailAddress.Length
}
else {
    $Size = $MailDomain.Length
}
for ($i = 0; $i -lt $Size; $i++) {
    if ($MailAddress.Length -gt 0) {
        $Arguments['From'] = $MailAddress[$i]
        $Name = $MailAddress[$i]
    }
    elseif ($MailDomain.Length -gt 0) {
        $Arguments['SenderDomainIs'] = $MailDomain[$i]
        $Name = $MailDomain[$i]
    }
    if (-not $CustomHeaderPresent) {
        $CustomHeaderText = "Bypass spam filtering for authenticated sender $Name"
    }
    if ($SetCustomHeader) {
        $Arguments['SetHeaderName'] = $CustomHeader
        $Arguments['SetHeaderValue'] = $CustomHeaderText
    }
    if (-not $RuleNamePresent) {
        $RuleName = "$Name bypass Spam Filter"
    }
    $Arguments['Name'] = $RuleName
    if ($Verbose) {
        $Arguments | Out-String | Write-Host
    }
    $Result = New-TransportRule @Arguments
    if ($? -eq $true -and $($Result.IsRuleConfigurationSupported) -eq $true) {
        Write-Host "Transport rule '$($Result.Name)' with Priority $($Result.Priority) created successfully." 
    }
    elseif (-not $WhatIf) {
        Write-Error "Failed to create transport rule."
        exit 1
    }
}
exit 0
