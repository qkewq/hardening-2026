$ErrorActionPreference = 'Stop'
$LogFile = "$env:SystemDrive\harden-script.log"
Start-Transcript -Path $LogFile -Append | Out-Null

Write-Host "=== Windows Server hardening script started: $(Get-Date) ===" -ForegroundColor Cyan

Write-Host "[1/10] Checking Windows Update module / installing updates..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    } catch {
        Write-Warning "Could not install PSWindowsUpdate module (no internet / no NuGet repo). Skipping automated update install — run Windows Update manually."
    }
}
if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction SilentlyContinue
    Write-Host "Updates installed. A reboot may be required — schedule it separately." -ForegroundColor Yellow
}

Write-Host "[2/10] Configuring Windows Firewall..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow
Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True -LogAllowed False `
    -LogFileName "%systemroot%\system32\LogFiles\Firewall\pfirewall.log" -LogMaxSizeKilobytes 16384

Write-Host "[3/10] Hardening SMB (removing SMBv1, enabling signing)..." -ForegroundColor Yellow
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
Set-SmbClientConfiguration -RequireSecuritySignature $true -Force

Write-Host "[6/10] Configuring audit policy..." -ForegroundColor Yellow
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
auditpol /set /category:"Privilege Use" /success:enable /failure:enable
auditpol /set /category:"System" /success:enable /failure:enable

# ---------------------------------------------------------------------------
# 8. Windows Defender baseline
# ---------------------------------------------------------------------------
Write-Host "[8/10] Configuring Windows Defender..." -ForegroundColor Yellow
try {
    Set-MpPreference -DisableRealtimeMonitoring $false
    Set-MpPreference -MAPSReporting Advanced
    Set-MpPreference -SubmitSamplesConsent SendSafeSamples
    Set-MpPreference -PUAProtection Enabled
    Update-MpSignature -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Windows Defender cmdlets not available (may be using third-party AV) — skipping."
}

Write-Host "[10/10] Enabling PowerShell script block & module logging..." -ForegroundColor Yellow
$pwshLogPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
New-Item -Path $pwshLogPath -Force | Out-Null
Set-ItemProperty -Path $pwshLogPath -Name "EnableScriptBlockLogging" -Value 1 -Force

$pwshModPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
New-Item -Path $pwshModPath -Force | Out-Null
Set-ItemProperty -Path $pwshModPath -Name "EnableModuleLogging" -Value 1 -Force

Write-Host "=== Hardening script complete: $(Get-Date) ===" -ForegroundColor Cyan
Write-Host "Log written to $LogFile"
Write-Host ""
Write-Host "MANUAL FOLLOW-UPS (not automated here):" -ForegroundColor Green
Write-Host "  - Reboot to apply LSA protection (RunAsPPL) and any pending updates"
Write-Host "  - Rename the built-in Administrator account and set a strong unique password"
Write-Host "  - Review firewall rules — allow only the ports/services actually needed"
Write-Host "  - Apply a Microsoft Security Baseline via Group Policy / LGPO for full CIS-style coverage"
Write-Host "  - Enable BitLocker disk encryption if not already in place"
Write-Host "  - Ship logs to a SIEM / central log collector"
Write-Host "  - Set up regular, tested backups"
Write-Host "  - If domain-joined, prefer enforcing these settings via GPO rather than local script"

Stop-Transcript | Out-Null
