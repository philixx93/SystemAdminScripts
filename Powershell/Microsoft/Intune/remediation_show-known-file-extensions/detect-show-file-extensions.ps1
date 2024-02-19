try {
    if((Get-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -ErrorAction Stop).HideFileExt -eq 0) {
        Write-Host "Setting already in place."
    }
    else {
        Write-Host "Setting not in place"
        exit 1
    }
}
catch {
    Write-Error -Message "Could not read regsitry value" -Category OperationStopped
    exit 1
}
exit 0