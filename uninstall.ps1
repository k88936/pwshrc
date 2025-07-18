$profilePath = $PROFILE

# Construct the line to delete (consistent with install.ps1)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$initCommand = ". `"$scriptDir\.pwshrc.ps1`""

# If configuration file exists
if (Test-Path $profilePath) {
    # Read all lines and filter out the target line
    $lines = Get-Content -Path $profilePath | Where-Object { $_ -ne $initCommand }

    # Write back to file
    Set-Content -Path $profilePath -Value $lines

    Write-Host "Scoop initialization removed from PowerShell profile."
}
else {
    Write-Host "PowerShell profile does not exist."
}