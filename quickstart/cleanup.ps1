# start.ps1 が作ったコンテナ・ネットワーク・ボリュームだけを削除する。
# ボリュームを消すと、Filestash の設定と共有領域のファイルも消える。
#   .\cleanup.ps1 -WhatIf   削除する対象を表示するだけ
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Connection = '',
    [string]$Prefix = 'filestash-demo'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Base = @()
if ($Connection) { $Base = @('--connection', $Connection) }

function Remove-Resource([string]$Kind, [string]$Name, [string[]]$ListArguments, [string[]]$RemoveArguments) {
    $existing = @(& podman @Base @ListArguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $Kind $Name" }
    if ($Name -notin $existing) { Write-Host "Not found: $Kind $Name"; return }
    if ($PSCmdlet.ShouldProcess($Name, "Remove $Kind")) {
        $null = & podman @Base @RemoveArguments 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Failed to remove $Kind $Name" }
        Write-Host "Removed: $Kind $Name"
    }
}

foreach ($container in @($Prefix, "$Prefix-sftp")) {
    Remove-Resource 'container' $container @('ps', '-a', '--filter', "name=$container", '--format', '{{.Names}}') @('rm', '-f', $container)
}
Remove-Resource 'network' "$Prefix-net" @('network', 'ls', '--filter', "name=$Prefix-net", '--format', '{{.Name}}') @('network', 'rm', "$Prefix-net")
foreach ($volume in @("$Prefix-app-data", "$Prefix-sftp-data")) {
    Remove-Resource 'volume' $volume @('volume', 'ls', '--filter', "name=$volume", '--format', '{{.Name}}') @('volume', 'rm', $volume)
}
Write-Host 'private\connections.json は残してある。'
