<#
.SYNOPSIS
    Runs an infinite loop to monitor a website and send Cronitor pings as long
    as the website is online. Optionally pings Cronitor when the website goes
    offline.

.DESCRIPTION
    Designed to be used together with the included Install.ps1 script.

    By default, "fail" messages are never sent to Cronitor, because they tend
    to be false positives. Instead, it's probably a better idea to set up
    Cronitor so that if it doesn't see any "success" messages after 30 minutes
    (for example), only THEN notify users that the website is down.

.PARAMETER Url
    The website URL you want to monitor

.PARAMETER CronitorUrl
    The URL of the Cronitor website to monitor

.PARAMETER FrequencySeconds
    Determines how much time to wait between checks. Default is 300 (5 minutes).

.PARAMETER FailureAction
    When set to "Notify", will send "fail" messages to Cronitor when the
    website is unavailable. When set to "Ignore", doesn't send any messages to
    Cronitor at all. Default is "Ignore".

.EXAMPLE
    Watch-Url.ps1 https://ftp.pathwayservices.com https://cronitor.link/kgyHlg

    Pings the FTP website every 5 minutes, notifying Cronitor with "success" messages as long as it remains online.
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Url,

    [Parameter(Position=1)]
    [string]$CronitorUrl,

    [Parameter(Position=2)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FrequencySeconds = 300, # 5 minutes between each check

    [Parameter(Position=3)]
    [ValidateSet("Notify", "Ignore")]
    [string]$FailureAction = "Ignore"
)

# We're intentionally not using Mandatory=$True in the [Parameter()] attributes
# above. The Mandatory parameter prompts the user for input, which is not as
# desirable when you're creating a background process. Throwing an error is
# better at helping the user figure out what they're doing wrong.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 5.0

if (!$Url) {
    throw "Must specify the Url parameter."
}

if (!$CronitorUrl) {
    throw "Must specify the CronitorUrl parameter."
}

function notifyCronitor([switch]$fail) {

    $fullComputerName = $env:COMPUTERNAME
    if ((Test-Path "Env:\USERDNSDOMAIN") -and $env:USERDNSDOMAIN) {
        $fullComputerName += ".$env:USERDNSDOMAIN"
    }

    if ($fail) {
        $fullUrl = $CronitorUrl + "/fail"
        $message = "Failed to ping $Url from $env:USERNAME@$fullComputerName."
    }
    else {
        $fullUrl = $CronitorUrl + "/complete"
        $message = "Successfully pinged $Url from $env:USERNAME@$fullComputerName."
    }

    if ($message) {
        $escapedMessage = [Uri]::EscapeDataString($message)
        $fullUrl = $fullUrl + "?msg=$escapedMessage"
    }

    try {
        Invoke-WebRequest -Uri $fullUrl -UseBasicParsing | Out-Null
    }
    catch {

    # If we have a communication error with Cronitor, we will swallow those
    # errors. For two reasons:
    #
    # 1. Cronitor will notify us if we never successfully communicate with the
    #    server. So communication errors will be detected and handled
    #    eventually, if not today.
    # 2. It's highly unlikely the user of this cmdlet cares about Cronitor
    #    errors. They just want to be emailed when their scripts stop working.
    #    They don't want to account for Cronitor errors in their scripts.

        Write-Verbose $_.ToString()
    }
}

while ($true) {

    $success = $false
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url | Out-Null
        $success = $true
    } catch {
        Write-Host "$(Get-Date): Ping FAILURE: $_"
        if ($FailureAction -eq "Notify") {
            notifyCronitor -fail
        }
    }

    if ($success) {
        notifyCronitor
        Write-Host "$(Get-Date): Successfully pinged $Url."
    }

    Start-Sleep -Seconds $FrequencySeconds
}
