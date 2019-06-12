WebsiteMonitor
==============

Create an always-on Windows service that monitors a website's uptime.

This repository also serves as a template. If you can write a PowerShell script, you can use this repository as a template to get that script running as a Windows service.

Requirements
------------

* [NSSM][1] to manage the Windows service
* A [Cronitor][2] account, which will send downtime alerts to users

Setup
-----

1. If you haven't already, [download NSSM][1] and adjust your PATH environment variable to include the NSSM install directory.
2. Set up a new [Cronitor][2] monitor and note the generated URL.
3. Run [Install.ps1][3] and follow the prompts.
4. Start the new service by running `services.msc` or the `Start-Service` cmdlet.

If you wish to change the monitoring logic, you can do so by adjusting the logic in [Watch-Url.ps1][4].

[1]: https://nssm.cc/download
[2]: https://cronitor.io/
[3]: ./Install.ps1
[4]: ./Watch-Url.ps1
