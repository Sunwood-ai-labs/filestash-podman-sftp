# start.ps1 が作った2つのコンテナだけを止める。データ（ボリューム）は残る。
#   .\stop.ps1 -WhatIf   止める対象を表示するだけ
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$Connection = '',
    [string]$Prefix = 'filestash-demo'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Base = @()
if ($Connection) { $Base = @('--connection', $Connection) }
$Targets = @($Prefix, "$Prefix-sftp")

$running = @(& podman @Base ps --format '{{.Names}}' 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Podman connection is unavailable.' }
foreach ($container in $Targets) {
    if ($container -in $running) {
        if ($PSCmdlet.ShouldProcess($container, 'Stop container')) {
            $null = & podman @Base stop $container 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Failed to stop $container" }
            Write-Host "Stopped: $container"
        }
    } else { Write-Host "Not running: $container" }
}
