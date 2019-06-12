<#
.SYNOPSIS
    Install a background service that monitors a website and pings Cronitor as
    long as the website is online.

.PARAMETER ServiceName
    The name of the service you want to install. Make it a helpful name, such
    as "FtpMonitor" or something like that.

.PARAMETER UrlToMonitor
    The URL of the website you want to monitor

.PARAMETER CronitorUrl
    The URL of the Cronitor monitor to send "success" pings to when the website
    is online.

.EXAMPLE
    Install.ps1

    Go through the prompts to set up the new monitor service. You will need to start the service yourself.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string]$ServiceName,

    [Parameter(Mandatory=$True)]
    [string]$UrlToMonitor,

    [Parameter(Mandatory=$True)]
    [string]$CronitorUrl
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 4.0

if (!(Get-Command nssm.exe -ErrorAction SilentlyContinue)) {
    throw "nssm.exe command not found. Download nssm (https://nssm.cc/download) and add the exe directory to the PATH environment variable."
}

$scriptPath = Join-Path $PSScriptRoot "Watch-Url.ps1"
$logDir = Join-Path $PSScriptRoot $ServiceName
$logFile = Join-Path $logDir "log.txt"

function Invoke-Nssm {
    nssm.exe $args
    if ($LASTEXITCODE -ne 0) {
        throw "nssm exited with code $LASTEXITCODE"
    }
}

if (!(Test-Path $logDir)) {
    New-Item -Type Directory $logDir | Out-Null
}

$serviceCreds = Get-Credential -Message "Enter credentials under which the service should run, or press cancel to run as LOCALSYSTEM (not recommended)."

Invoke-Nssm install $ServiceName "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

try {

    Invoke-Nssm set $ServiceName AppParameters "-NoProfile -ExecutionPolicy RemoteSigned ""$scriptPath"" -Url ""$UrlToMonitor"" -CronitorUrl ""$CronitorUrl"""
    Invoke-Nssm set $ServiceName AppDirectory C:\Windows\System32\WindowsPowerShell\v1.0
    Invoke-Nssm set $ServiceName AppExit "Default" "Exit"
    Invoke-Nssm set $ServiceName AppExit "1" "Exit"
    Invoke-Nssm set $ServiceName AppStdout $logFile
    Invoke-Nssm set $ServiceName AppStdoutCreationDisposition 2
    Invoke-Nssm set $ServiceName AppStderr $logFile
    Invoke-Nssm set $ServiceName AppStderrCreationDisposition 2
    Invoke-Nssm set $ServiceName AppRotateFiles 1
    Invoke-Nssm set $ServiceName AppRotateOnline 1
    Invoke-Nssm set $ServiceName AppRotateBytes 524288
    Invoke-Nssm set $ServiceName Description "An NSSM-hosted service running $scriptPath"
    Invoke-Nssm set $ServiceName DisplayName $ServiceName
    Invoke-Nssm set $ServiceName Start SERVICE_DELAYED_AUTO_START
    Invoke-Nssm set $ServiceName Type SERVICE_WIN32_OWN_PROCESS
    
    if ($serviceCreds) {
        # This is the simplest way to get the plain-text password that I'm aware of:
        $serviceCreds = New-Object System.Net.NetworkCredential `
            -ArgumentList $serviceCreds.UserName, $serviceCreds.Password
    
        $plaintextPassword = $serviceCreds.Password
        Invoke-Nssm set $ServiceName ObjectName $serviceCreds.UserName $plaintextPassword
    }

} catch {
    # Some error has occurred. Let's remove the half-configured service so the
    # user can re-run the install script more easily.

    try {
        Invoke-Nssm remove $ServiceName confirm | Out-Null
    } catch {
        Write-Warning "Unable to remove the half-configured service. Resolve the problem, then run ""nssm remove $ServiceName confirm"" before re-running the install script."
    }

    throw
}
