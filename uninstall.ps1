$profilePath = $PROFILE

# 构造要删除的那行内容（与 install.ps1 中一致）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$initCommand = ". `"$scriptDir\.pwshrc.ps1`""

# 如果配置文件存在
if (Test-Path $profilePath) {
    # 读取所有行并过滤掉目标行
    $lines = Get-Content -Path $profilePath | Where-Object { $_ -ne $initCommand }

    # 写回文件
    Set-Content -Path $profilePath -Value $lines

    Write-Host "✅ Scoop 初始化已从 PowerShell 配置文件中移除。"
} else {
    Write-Host "⚠️ PowerShell 配置文件不存在。"
}