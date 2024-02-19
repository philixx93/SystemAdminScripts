try {
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0 -ErrorAction Stop
}
catch {
    Write-Error -Message "Could not write regsitry value" -Category OperationStopped
    exit 1
}
exit 0