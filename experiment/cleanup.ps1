[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Connection = 'helix-foundry-experiment'
$Containers = @('filestash-demo','filestash-sftp')
$Network = 'filestash-demo-net'
$Volumes = @('filestash-demo-app-data','filestash-demo-sftp-data')
$LogDirectory = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
$RunLog = Join-Path $LogDirectory ('cleanup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
function Invoke-CleanupStep([string]$Display,[string[]]$Arguments) {
    Add-Content -Path $RunLog -Encoding utf8 -Value "COMMAND: $Display"
    $output = @(& podman --connection $Connection @Arguments 2>&1)
    $code = $LASTEXITCODE
    foreach ($line in $output) { Add-Content -Path $RunLog -Encoding utf8 -Value ([string]$line) }
    Add-Content -Path $RunLog -Encoding utf8 -Value "EXIT_CODE: $code"
    if ($code -ne 0) { throw "Podman cleanup failed with exit code $code. See $RunLog" }
}
$machineStateRaw = @(& podman machine list --format json 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Podman machine state; cleanup stopped.' }
$machine = @($machineStateRaw | ConvertFrom-Json) | Where-Object { $_.Name -eq $Connection } | Select-Object -First 1
if (-not $machine -or -not $machine.Running) { throw "The named machine '$Connection' is stopped. Cleanup did not start or change any machine." }
$running = @(& podman --connection $Connection ps --format '{{.Names}}' 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Named Podman connection is unavailable; cleanup stopped.' }
foreach ($container in $Containers) {
    if ($container -in $running) {
        if ($PSCmdlet.ShouldProcess($container,'Remove dedicated Filestash container')) {
            Invoke-CleanupStep "podman --connection $Connection rm -f $container" @('rm','-f',$container)
        }
    } else {
        $allContainers = @(& podman --connection $Connection ps -a --filter "name=$container" --format '{{.Names}}' 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $container" }
        if ($container -in $allContainers -and $PSCmdlet.ShouldProcess($container,'Remove dedicated Filestash container')) {
            Invoke-CleanupStep "podman --connection $Connection rm -f $container" @('rm','-f',$container)
        } else { Add-Content -Path $RunLog -Encoding utf8 -Value "SKIP: $container does not exist" }
    }
}
$networkNames = @(& podman --connection $Connection network ls --filter "name=$Network" --format '{{.Name}}' 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the dedicated network.' }
if ($Network -in $networkNames -and $PSCmdlet.ShouldProcess($Network,'Remove dedicated Filestash network')) {
    Invoke-CleanupStep "podman --connection $Connection network rm $Network" @('network','rm',$Network)
} else { Add-Content -Path $RunLog -Encoding utf8 -Value "SKIP: $Network does not exist" }
foreach ($volume in $Volumes) {
    $volumeNames = @(& podman --connection $Connection volume ls --filter "name=$volume" --format '{{.Name}}' 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $volume" }
    if ($volume -in $volumeNames -and $PSCmdlet.ShouldProcess($volume,'Delete dedicated Filestash data volume')) {
        Invoke-CleanupStep "podman --connection $Connection volume rm $volume" @('volume','rm',$volume)
    } else { Add-Content -Path $RunLog -Encoding utf8 -Value "SKIP: $volume does not exist" }
}
if ($WhatIfPreference) { Write-Host 'WhatIf: no containers, network or volumes were changed.' }
else { Write-Host 'Removed only the Filestash demo containers, network and volumes.' }
Write-Host "Run log: $RunLog"
Write-Host 'The local private file, logs and evidence were left intact.'
