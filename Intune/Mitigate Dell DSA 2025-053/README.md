# Intune Remediation for Dell DSA 2025-053
I put together a quick remedy for this issue with Intune. Credits for my sources are in the scripts.

## How to use it

- Get the MSI installer of the fixed Control Vault release
  - Download the new version from https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=TWF65
  - Run the file and extract it
  - Go to the new extracted folder and get the CVHCI64.exe file
  - Run that file and get it to the install screen but don't actually run the install
  - Go to your %temp% user directory and search for the CVHCI64.msi file
- Host the file somewhere, where your clients can access it. (I used a Storage Account in Azure, but use whatever you have at hand.)
- Put the download link in ``$downloadLink`` in line 8 in the remediation script.
  - If you host it on a network share, you might need to change line 13, too.
- As default the script forces a reboot at 7PM.
  - To change the time, change the ``$RebootTime`` in Line 10.
  - To skip the reboot, change the ``$forceReboot`` to ``$false`` in line 11.
- Create a Remediation in [Intune](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesWindowsMenu/~/powershell)
- Under Settings choose the detection and remediation script. Set ``Run this script using the logged-on credentials`` to ``No``.
- Choose the assignment. The Script should skip Non-Dell and Non-Latitude and Precision devices. So you can choose ``All devices`` if you want.
- Save and wait for magic 💫 to happen.

## Disclaimer
As always, check scripts from the internet before you deploy them in your environment. Test before you deploy. You are responsible for the changes you make. I provide these scripts with best intentions, but I do not guarantee flawless operation or coverage of all edge-cases, that might appear on your infrastructure.
