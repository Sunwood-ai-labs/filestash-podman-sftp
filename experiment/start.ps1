[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Connection = 'helix-foundry-experiment'
$Network = 'filestash-demo-net'
$AppVolume = 'filestash-demo-app-data'
$SftpVolume = 'filestash-demo-sftp-data'
$AppContainer = 'filestash-demo'
$SftpContainer = 'filestash-sftp'
$AppImage = 'docker.io/machines/filestash@sha256:db21af2bff93ebb81ad9270a8a564679be4aec87406b093c41c30db0fbf27226'
$SftpImage = 'docker.io/atmoz/sftp@sha256:7e439fabeae536fa254340724c042e11999924d906417dbb5c73602ad518813f'
$LogDirectory = Join-Path $PSScriptRoot 'logs'
$EvidenceDirectory = Join-Path $PSScriptRoot 'evidence'
$PrivatePath = Join-Path $PSScriptRoot 'private\connections.json'
$SeedDirectory = Join-Path $PSScriptRoot 'seed-data\日本語サンプル'
New-Item -ItemType Directory -Force -Path $LogDirectory,$EvidenceDirectory | Out-Null
$RunLog = Join-Path $LogDirectory ('start-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$script:LastPodmanExitCode = 0

function Write-RunLog([string]$Text) {
    Add-Content -Path $RunLog -Encoding utf8 -Value $Text
}

function Invoke-PodmanStep {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [Parameter(Mandatory=$true)][string]$DisplayCommand,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0)
    )
    Write-Host $Label
    Write-RunLog "COMMAND: $DisplayCommand"
    $output = @(& podman --connection $Connection @Arguments 2>&1)
    $script:LastPodmanExitCode = $LASTEXITCODE
    foreach ($line in $output) { Write-RunLog ([string]$line) }
    Write-RunLog "EXIT_CODE: $script:LastPodmanExitCode"
    if ($AllowedExitCodes -notcontains $script:LastPodmanExitCode) {
        throw "Podman step '$Label' failed with exit code $script:LastPodmanExitCode. See $RunLog"
    }
    return $output
}

function Ensure-Image([string]$Reference) {
    $null = Invoke-PodmanStep 'Check pinned image' "podman --connection $Connection image exists $Reference" @('image','exists',$Reference) @(0,1)
    if ($script:LastPodmanExitCode -eq 1) {
        $null = Invoke-PodmanStep 'Pull pinned image' "podman --connection $Connection pull $Reference" @('pull',$Reference)
    }
}

if (-not (Test-Path -LiteralPath $PrivatePath)) { throw "Private connection file is missing: $PrivatePath" }
if (-not (Test-Path -LiteralPath (Join-Path $SeedDirectory '説明.txt')) -or -not (Test-Path -LiteralPath (Join-Path $SeedDirectory 'サンプル画像.png'))) { throw "Seed files are missing: $SeedDirectory" }
$Credentials = Get-Content -LiteralPath $PrivatePath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$Credentials.sftpPassword) -or [string]::IsNullOrWhiteSpace([string]$Credentials.filestashAdminPassword)) { throw "Private connection file is missing required credentials: $PrivatePath" }

# Start the named machine only when it is explicitly reported stopped.
Write-RunLog 'COMMAND: podman machine list --format json (read-only; record only helix-foundry-experiment)'
$machineRaw = @(& podman machine list --format json 2>&1)
$machineExit = $LASTEXITCODE
Write-RunLog "MACHINE_LIST_EXIT_CODE: $machineExit"
if ($machineExit -ne 0) { throw "Unable to inspect Podman machine state. See $RunLog" }
$machines = @($machineRaw | ConvertFrom-Json)
$machine = $machines | Where-Object { $_.Name -eq $Connection } | Select-Object -First 1
if (-not $machine) { throw "Podman machine '$Connection' was not found. No other machine will be substituted." }
Write-RunLog "NAMED_MACHINE_STATE: Running=$($machine.Running); Port=$($machine.Port)"
if (-not $machine.Running) {
    Write-RunLog "COMMAND: podman machine start $Connection"
    $machineStart = @(& podman machine start $Connection 2>&1)
    $machineStartExit = $LASTEXITCODE
    foreach ($line in $machineStart) { Write-RunLog ([string]$line) }
    Write-RunLog "MACHINE_START_EXIT_CODE: $machineStartExit"
    if ($machineStartExit -ne 0) { throw "Unable to start the named Podman machine. See $RunLog" }
}
$connected = $false
for ($attempt = 1; $attempt -le 8; $attempt++) {
    Write-RunLog "COMMAND: podman --connection $Connection info --format '{{.Version.Version}}' (attempt $attempt)"
    $probe = @(& podman --connection $Connection info --format '{{.Version.Version}}' 2>&1)
    $probeExit = $LASTEXITCODE
    foreach ($line in $probe) { Write-RunLog ([string]$line) }
    Write-RunLog "INFO_EXIT_CODE: $probeExit"
    if ($probeExit -eq 0) { $connected = $true; break }
    if ($attempt -lt 8) { Start-Sleep -Seconds 3 }
}
if (-not $connected) { throw "The named Podman connection is still unavailable. See $RunLog" }

foreach ($resource in @(@{Kind='network';Name=$Network},@{Kind='volume';Name=$AppVolume},@{Kind='volume';Name=$SftpVolume})) {
    if ($resource.Kind -eq 'network') {
        $items = @(Invoke-PodmanStep 'Inspect dedicated network list' "podman --connection $Connection network ls --filter name=$($resource.Name)" @('network','ls','--filter',"name=$($resource.Name)",'--format','{{.Name}}'))
    } else {
        $items = @(Invoke-PodmanStep 'Inspect dedicated volume list' "podman --connection $Connection volume ls --filter name=$($resource.Name)" @('volume','ls','--filter',"name=$($resource.Name)",'--format','{{.Name}}'))
    }
    if ($items -notcontains $resource.Name) {
        if ($resource.Kind -eq 'network') { $null = Invoke-PodmanStep 'Create dedicated network' "podman --connection $Connection network create $($resource.Name)" @('network','create',$resource.Name) }
        else { $null = Invoke-PodmanStep 'Create dedicated volume' "podman --connection $Connection volume create $($resource.Name)" @('volume','create',$resource.Name) }
    }
}

Ensure-Image $AppImage
Ensure-Image $SftpImage
$containerNames = @(Invoke-PodmanStep 'Inspect Filestash container names' "podman --connection $Connection ps -a --filter name=filestash" @('ps','-a','--filter','name=filestash','--format','{{.Names}}'))
if ($containerNames -notcontains $SftpContainer) {
    $sftpUserSpec = 'qa:' + [string]$Credentials.sftpPassword + ':1001:100:share'
    $null = Invoke-PodmanStep 'Create disposable SFTP container' "podman --connection $Connection run -d --name $SftpContainer --restart unless-stopped --network $Network --network-alias filestash-sftp -v ${SftpVolume}:/home/qa/share $SftpImage <private-user-config>" @('run','-d','--name',$SftpContainer,'--restart','unless-stopped','--network',$Network,'--network-alias','filestash-sftp','-v',"${SftpVolume}:/home/qa/share",$SftpImage,$sftpUserSpec)
} else {
    $sftpStatus = @(Invoke-PodmanStep 'Read SFTP container state' "podman --connection $Connection inspect --format '{{.State.Status}}' $SftpContainer" @('inspect','--format','{{.State.Status}}',$SftpContainer))
    if (($sftpStatus | Select-Object -First 1).ToString().Trim() -ne 'running') { $null = Invoke-PodmanStep 'Start SFTP container' "podman --connection $Connection start $SftpContainer" @('start',$SftpContainer) }
}
$sampleRemoteDirectory = '/home/qa/share/日本語サンプル'
$sampleDirectoryPresent = @(Invoke-PodmanStep 'Check sample directory' "podman --connection $Connection exec $SftpContainer test -d <sample-directory>" @('exec',$SftpContainer,'test','-d',$sampleRemoteDirectory) @(0,1))
if ($script:LastPodmanExitCode -eq 1) { $null = Invoke-PodmanStep 'Create sample directory' "podman --connection $Connection exec $SftpContainer mkdir -p <sample-directory>" @('exec',$SftpContainer,'mkdir','-p',$sampleRemoteDirectory) }
$copiedSeed = $false
foreach ($seedFile in Get-ChildItem -LiteralPath $SeedDirectory -File) {
    $targetFile = $sampleRemoteDirectory + '/' + $seedFile.Name
    $present = @(Invoke-PodmanStep 'Check sample file' "podman --connection $Connection exec $SftpContainer test -f <sample-file>" @('exec',$SftpContainer,'test','-f',$targetFile) @(0,1))
    if ($script:LastPodmanExitCode -eq 1) {
        $null = Invoke-PodmanStep 'Copy initial sample file' "podman --connection $Connection cp <local-seed> ${SftpContainer}:<sample-file>" @('cp',$seedFile.FullName,"${SftpContainer}:$targetFile")
        $copiedSeed = $true
    }
}
if ($copiedSeed) { $null = Invoke-PodmanStep 'Set sample ownership' "podman --connection $Connection exec --user root $SftpContainer chown -R 1001:100 /home/qa/share" @('exec','--user','root',$SftpContainer,'chown','-R','1001:100','/home/qa/share') }

$containerNames = @(Invoke-PodmanStep 'Inspect Filestash container names' "podman --connection $Connection ps -a --filter name=filestash" @('ps','-a','--filter','name=filestash','--format','{{.Names}}'))
if ($containerNames -notcontains $AppContainer) {
    $null = Invoke-PodmanStep 'Create Filestash container on loopback only' "podman --connection $Connection run -d --name $AppContainer --restart unless-stopped --network $Network -p 127.0.0.1:18334:8334/tcp -v ${AppVolume}:/app/data/state/ $AppImage" @('run','-d','--name',$AppContainer,'--restart','unless-stopped','--network',$Network,'-p','127.0.0.1:18334:8334/tcp','-v',"${AppVolume}:/app/data/state/",$AppImage)
} else {
    $appStatus = @(Invoke-PodmanStep 'Read Filestash container state' "podman --connection $Connection inspect --format '{{.State.Status}}' $AppContainer" @('inspect','--format','{{.State.Status}}',$AppContainer))
    if (($appStatus | Select-Object -First 1).ToString().Trim() -ne 'running') { $null = Invoke-PodmanStep 'Start Filestash container' "podman --connection $Connection start $AppContainer" @('start',$AppContainer) }
}

Start-Sleep -Seconds 3
$httpEvidence = Join-Path $EvidenceDirectory 'http-check-latest.txt'
try {
    $response = Invoke-WebRequest -Uri 'http://127.0.0.1:18334/' -UseBasicParsing -TimeoutSec 15
    $statusCode = [int]$response.StatusCode
    $title = [regex]::Match($response.Content,'<title[^>]*>(.*?)</title>','IgnoreCase,Singleline').Groups[1].Value
    @("COMMAND: Invoke-WebRequest http://127.0.0.1:18334/ -TimeoutSec 15","STATUS_CODE: $statusCode","TITLE: $title","RESULT: HTTP_RESPONSE_RECEIVED") | Set-Content -Path $httpEvidence -Encoding utf8
    Write-RunLog "HTTP_STATUS_CODE: $statusCode; TITLE: $title"
    if ($statusCode -ne 200) { throw "Expected HTTP 200, received $statusCode" }
} catch {
    @('COMMAND: Invoke-WebRequest http://127.0.0.1:18334/ -TimeoutSec 15','RESULT: HTTP_REQUEST_FAILED',"ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message)") | Set-Content -Path $httpEvidence -Encoding utf8
    Write-RunLog "HTTP_ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
    throw
}
Write-Host "Ready: http://127.0.0.1:18334"
Write-Host "Connection details: $PrivatePath"
Write-Host "Run log: $RunLog"
