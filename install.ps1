# Get current script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$profilePath = $PROFILE

# Initialization command content
$initCommand = ". `"$scriptDir\.pwshrc.ps1`""

# If profile doesn't exist, create it
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force
}

# Check if this line already exists
$lines = Get-Content -Path $profilePath
if ($lines -contains $initCommand) {
    Write-Host "Already exists, not adding duplicate."
}
else {
    Add-Content -Path $profilePath -Value $initCommand
    Write-Host "pwshrc initialization added to PowerShell profile."
}