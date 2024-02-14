<#
    .SYNOPSIS
        Create random data files of a specified size and number of files.

    .DESCRIPTION
        This script creates random data files of a specified size and number of files. 
        The files are created in the specified folder. The script also logs the time 
        it took to create each file and the total time it took to create all files.

    .PARAMETER Output
        The folder where the files will be created. If the folder does not exist, 
        the script will exit with an error. The default value is the current folder.

    .PARAMETER NumberOfFiles
        The number of files to create. The default value is 1.

    .PARAMETER Filename
        The base name of the files to create. The default value is "rnd-data".

    .PARAMETER Fileextension
        The extension of the files to create. The default value is "bin".

    .PARAMETER Filesize
        The size of the files to create in MiB. The default value is 100. The minimum 
        value is 1 and the maximum value is 1000.

    .INPUTS
        Nothing.

    .OUTPUTS
        Files with random content in the specified directory.

    .EXAMPLE
        .\rnd-data.ps1 -Output "C:\Temp" -NumberOfFiles 10 -Filesize 50
        Creates 10 files with random data of 50 MiB each in the C:\Temp folder.     

    .LINK
        Github Repo: https://github.com/philixx93/SystemAdminScripts

    .NOTES
        This script was developed and tested with Powershell 7. The maximum 
        size of 1000 MiB is more or less arbitrary, but tested. If you feel 
        like needing bigger files, just change and test it.
#>
Param(
    [string]$Output = $(pwd),
    [int]$NumberOfFiles = 1,
    [string]$Filename = "rnd-data",
    [string]$Fileextension = "bin",
    [int]$Filesize = 100
)
if($Filesize -lt 1 -or $Filesize -gt 1000){
    Write-Error "Filesize must be between 1 and 1000"
    exit 2
}

if(!(Test-Path $Output -PathType Container)){
    Write-Error "Folder not present."
    exit 2
}
else{
    Write-Debug "API Token File is present"
}

# Specify the size of the file in bytes
$Filesize = 1024 * 1024 * $Filesize # Filesize MiB

# Create a byte array with random data
$randomData = New-Object Byte[] $Filesize
$random = New-Object Random
$random.NextBytes($randomData)

if($Output -NotLike "*\"){
    $Output = $Output + "\"
}
$logFile = $Output + "$Filename-$(Get-Date -Format "yyyyMMdd-HH.mm").log"
Write-Debug "Writing $NumberOfFiles files of $($Filesize / (1024 * 1024)) MiB to $Output, totalling $($NumberOfFiles * $Filesize / (1024 * 1024)) MiB"
Write-Debug "Log file: $logFile"
# Write the random data to the file
$stopwatchAll = [Diagnostics.Stopwatch]::StartNew()
foreach($i in 1..$NumberOfFiles)
{
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $filePath = $Output + "$Filename-$i.$Fileextension"
    Write-Debug "Creating file $filePath"
    [System.IO.File]::WriteAllBytes($filePath, $randomData)
    $stopwatch.stop()
    "File $i created in $($stopwatch.Elapsed) seconds" | Out-File -FilePath $logFile -Append
}
$stopwatchAll.stop()
"Total time: $($stopwatchAll.Elapsed) seconds" | Out-File -FilePath $logFile -Append