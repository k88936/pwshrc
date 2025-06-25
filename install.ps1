# 获取当前脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$profilePath = $PROFILE

# 初始化命令内容
$initCommand = ". `"$scriptDir\.pwshrc.ps1`""

# 如果 profile 不存在，则创建它
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force
}

# 检查是否已经存在该行
$lines = Get-Content -Path $profilePath
if ($lines -contains $initCommand) {
    Write-Host "ℹ️ 已经存在，未重复添加。"
} else {
    Add-Content -Path $profilePath -Value $initCommand
    Write-Host "✅ Scoop 初始化已添加到 PowerShell 配置文件。"
}