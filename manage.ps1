param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Action
)

# 获取当前脚本所在目录
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# 构造 profile.ps1 的完整路径
$profileScriptPath = Join-Path -Path $scriptDir -ChildPath ".pwshrc.ps1"

# 构造要添加/删除的行内容
$lineToManage = ". `"$profileScriptPath`""

# 获取用户 PowerShell 配置文件路径
$profilePath = $PROFILE

Write-Host "🔧 使用 Profile 路径: $profilePath"
Write-Host "📁 使用脚本路径: $scriptDir"

if ($Action -eq "Install") {
    Write-Host "📦 正在安装..."

    # 确保 Profile 文件存在
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force
    }

    # 检查是否已存在该行
    if (-not (Get-Content $profilePath -Raw).Contains($lineToManage)) {
        Add-Content -Path $profilePath -Value $lineToManage
        Write-Host "✅ 已成功将 profile.ps1 添加到你的 PowerShell 配置文件。"
    } else {
        Write-Host "ℹ️  profile.ps1 已存在于 PowerShell 配置文件中。无需重复添加。"
    }

} elseif ($Action -eq "Uninstall") {
    Write-Host "🧼 正在卸载..."

    if (-not (Test-Path $profilePath)) {
        Write-Host "❌ PowerShell 配置文件不存在。跳过卸载。"
        return
    }

    # 使用正则匹配并过滤掉要删除的行
    $escapedLine = [regex]::Escape($lineToManage)
    $lines = Get-Content $profilePath | Where-Object { $_ -notmatch $escapedLine }

    Set-Content -Path $profilePath -Value $lines
    Write-Host "🗑️ 已从 PowerShell 配置文件中移除指定行。"
}