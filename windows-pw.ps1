$ErrorActionPreference = 'Continue'   # keep going even if one account fails
$LogFile = "$env:SystemDrive\lab-password-reset.log"
Start-Transcript -Path $LogFile -Append | Out-Null

$SecurePassword = Read-Host "Enter the new shared password" -AsSecureString

$ExcludedAccounts = @('krbtgt')
$UnlockAndClearMustChange = $true

$users = Get-ADUser -Filter * -Properties SamAccountName, LockedOut, PasswordExpired |
         Where-Object { $ExcludedAccounts -notcontains $_.SamAccountName }

Write-Host "Found $($users.Count) accounts to reset (excluding: $($ExcludedAccounts -join ', '))."

Get-ADUser -Filter * -Properties SamAccountName

$success = @()
$failed  = @()

foreach ($u in $users) {
    try {
        Set-ADAccountPassword -Identity $u.SamAccountName -NewPassword $SecurePassword -Reset

        if ($UnlockAndClearMustChange) {
            Unlock-ADAccount -Identity $u.SamAccountName -ErrorAction SilentlyContinue
            Set-ADUser -Identity $u.SamAccountName -ChangePasswordAtLogon $false -ErrorAction SilentlyContinue
        }

        $success += $u.SamAccountName
        Write-Host "  Reset: $($u.SamAccountName)" -ForegroundColor Green
    } catch {
        $failed += $u.SamAccountName
        Write-Host "  FAILED: $($u.SamAccountName) — $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Done: $(Get-Date) ===" -ForegroundColor Cyan
Write-Host "Succeeded: $($success.Count)"
Write-Host "Failed:    $($failed.Count)"
if ($failed.Count -gt 0) {
    Write-Host "Failed accounts: $($failed -join ', ')" -ForegroundColor Yellow
    Write-Host "(Common causes: password doesn't meet the domain's complexity/length policy, or account is disabled/protected.)"
}
Write-Host "Log written to $LogFile"

Stop-Transcript | Out-Null
