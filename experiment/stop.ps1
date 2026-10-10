[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Medium')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Connection = 'helix-foundry-experiment'
$Targets = @('filestash-demo','filestash-sftp')
$LogDirectory = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
$RunLog = Join-Path $LogDirectory ('stop-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
function Invoke-StopStep([string]$Display,[string[]]$Arguments) {
    Add-Content -Path $RunLog -Encoding utf8 -Value "COMMAND: $Display"
    $output = @(& podman --connection $Connection @Arguments 2>&1)
    $code = $LASTEXITCODE
    foreach ($line in $output) { Add-Content -Path $RunLog -Encoding utf8 -Value ([string]$line) }
    Add-Content -Path $RunLog -Encoding utf8 -Value "EXIT_CODE: $code"
    if ($code -ne 0) { throw "Podman stop failed with exit code $code. See $RunLog" }
}
$running = @(& podman --connection $Connection ps --format '{{.Names}}' 2>&1)
$probeCode = $LASTEXITCODE
if ($probeCode -ne 0) { throw "Named Podman connection is unavailable. Start only helix-foundry-experiment, then retry." }
$ownedRunning = @($running | Where-Object { $_ -in $Targets })
foreach ($container in $Targets) {
    if ($container -in $ownedRunning) {
        if ($PSCmdlet.ShouldProcess($container,'Stop dedicated Filestash container')) { Invoke-StopStep "podman --connection $Connection stop $container" @('stop',$container) }
    }
    else { Add-Content -Path $RunLog -Encoding utf8 -Value "SKIP: $container is not running" }
}
if ($WhatIfPreference) { Write-Host "WhatIf: no containers changed. Targets: $($ownedRunning -join ', ')" }
else { Write-Host "Stopped only: $($ownedRunning -join ', ')" }
Write-Host "Run log: $RunLog"
