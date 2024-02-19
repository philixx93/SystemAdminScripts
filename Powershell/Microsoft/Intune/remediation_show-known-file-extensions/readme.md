# Show known file extensions using Intune
This remediation enables you to to check and set the registry key responsible for hiding know file extensions. The key is 0 for hide or 1 for show.

**As always: test it before you roll it out! I am not liable to any damage done by these scripts.**
## Set up in Intune
- Open the Intune Admin Center
- Go to **Devices** -> **Remediations**
- Click **+ Create script package**
- Give it a Name and a Description, then click **Next**
- Select **detect-show-file-extensions.ps1** as **Detection script file**
- Select **set-show-file-extensions.ps1** as **Remediation script file**
- Set **Run this script using the logged-on credentials** to **Yes**
- Click **Next**
- Click **Next**
- Choose **Assignments**
- Click **Next**
- Click **Create**
