# Filestash と使い捨ての SFTP サーバーを、専用のネットワーク・ボリュームで起動する。
# 実験で使った experiment/start.ps1 と同じイメージ（digest固定）と同じ run 引数を使い、
# 接続名・リソース名・ポート・共有するフォルダーを引数で変えられるようにしたもの。
#
#   .\start.ps1                                  既定のPodman接続、http://127.0.0.1:18334
#   .\start.ps1 -Connection my-machine -Port 18400
#   .\start.ps1 -SeedDirectory C:\work\share-me   このフォルダーの中身を共有領域へコピー
[CmdletBinding()]
param(
    [string]$Connection = '',
    [string]$Prefix = 'filestash-demo',
    [int]$Port = 18334,
    [string]$SeedDirectory = (Join-Path $PSScriptRoot 'seed')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$AppImage = 'docker.io/machines/filestash@sha256:db21af2bff93ebb81ad9270a8a564679be4aec87406b093c41c30db0fbf27226'
$SftpImage = 'docker.io/atmoz/sftp@sha256:7e439fabeae536fa254340724c042e11999924d906417dbb5c73602ad518813f'
$AppContainer = $Prefix
$SftpContainer = "$Prefix-sftp"
$Network = "$Prefix-net"
$AppVolume = "$Prefix-app-data"
$SftpVolume = "$Prefix-sftp-data"
$PrivateDirectory = Join-Path $PSScriptRoot 'private'
$PrivatePath = Join-Path $PrivateDirectory 'connections.json'
$Base = @()
if ($Connection) { $Base = @('--connection', $Connection) }

function Invoke-Podman {
    param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
    $output = @(& podman @Base @Arguments 2>&1)
    $script:LastExit = $LASTEXITCODE
    if ($AllowedExitCodes -notcontains $script:LastExit) {
        throw "podman $($Arguments[0]) $($Arguments[1]) failed with exit code $script:LastExit`n$($output -join "`n")"
    }
    return $output
}

function New-Secret {
    $bytes = New-Object byte[] 18
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

# 接続情報は private/connections.json にだけ置く（.gitignore 済み）。なければ乱数で作る。
if (-not (Test-Path -LiteralPath $PrivatePath)) {
    New-Item -ItemType Directory -Force -Path $PrivateDirectory | Out-Null
    [ordered]@{
        filestashAdminPassword = New-Secret
        sftpHost               = $SftpContainer
        sftpPort               = 22
        sftpUsername           = 'qa'
        sftpPassword           = New-Secret
        storageRoot            = '/'
    } | ConvertTo-Json | Set-Content -LiteralPath $PrivatePath -Encoding utf8
    Write-Host "Created $PrivatePath"
}
$Credentials = Get-Content -LiteralPath $PrivatePath -Raw | ConvertFrom-Json

$null = Invoke-Podman @('info', '--format', '{{.Version.Version}}')

if (@(Invoke-Podman @('network', 'ls', '--filter', "name=$Network", '--format', '{{.Name}}')) -notcontains $Network) {
    $null = Invoke-Podman @('network', 'create', $Network)
}
foreach ($volume in @($AppVolume, $SftpVolume)) {
    if (@(Invoke-Podman @('volume', 'ls', '--filter', "name=$volume", '--format', '{{.Name}}')) -notcontains $volume) {
        $null = Invoke-Podman @('volume', 'create', $volume)
    }
}
foreach ($image in @($AppImage, $SftpImage)) {
    $null = Invoke-Podman @('image', 'exists', $image) @(0, 1)
    if ($script:LastExit -eq 1) { Write-Host "Pulling $image"; $null = Invoke-Podman @('pull', $image) }
}

# SFTPサーバー。ポートはホストへ公開せず、専用ネットワークの中だけで Filestash から届く。
$names = @(Invoke-Podman @('ps', '-a', '--filter', "name=$Prefix", '--format', '{{.Names}}'))
if ($names -notcontains $SftpContainer) {
    $userSpec = 'qa:' + [string]$Credentials.sftpPassword + ':1001:100:share'
    $null = Invoke-Podman @('run', '-d', '--name', $SftpContainer, '--restart', 'unless-stopped', '--network', $Network, '--network-alias', $SftpContainer, '-v', "${SftpVolume}:/home/qa/share", $SftpImage, $userSpec)
} elseif ((@(Invoke-Podman @('inspect', '--format', '{{.State.Status}}', $SftpContainer))[0]).ToString().Trim() -ne 'running') {
    $null = Invoke-Podman @('start', $SftpContainer)
}

# 共有領域に、まだ無いファイルだけをコピーする。
if (Test-Path -LiteralPath $SeedDirectory) {
    $root = (Resolve-Path -LiteralPath $SeedDirectory).Path
    $copied = $false
    foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse) {
        $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
        $target = '/home/qa/share/' + $relative
        $null = Invoke-Podman @('exec', $SftpContainer, 'test', '-f', $target) @(0, 1)
        if ($script:LastExit -eq 1) {
            $null = Invoke-Podman @('exec', $SftpContainer, 'mkdir', '-p', ($target.Substring(0, $target.LastIndexOf('/'))))
            $null = Invoke-Podman @('cp', $file.FullName, "${SftpContainer}:$target")
            $copied = $true
        }
    }
    if ($copied) { $null = Invoke-Podman @('exec', '--user', 'root', $SftpContainer, 'chown', '-R', '1001:100', '/home/qa/share') }
}

# Filestash。画面はこのPCの中（127.0.0.1）からだけ開ける。
$names = @(Invoke-Podman @('ps', '-a', '--filter', "name=$Prefix", '--format', '{{.Names}}'))
if ($names -notcontains $AppContainer) {
    $null = Invoke-Podman @('run', '-d', '--name', $AppContainer, '--restart', 'unless-stopped', '--network', $Network, '-p', "127.0.0.1:${Port}:8334/tcp", '-v', "${AppVolume}:/app/data/state/", $AppImage)
} elseif ((@(Invoke-Podman @('inspect', '--format', '{{.State.Status}}', $AppContainer))[0]).ToString().Trim() -ne 'running') {
    $null = Invoke-Podman @('start', $AppContainer)
}

$url = "http://127.0.0.1:$Port"
$status = 0
for ($attempt = 1; $attempt -le 10 -and $status -ne 200; $attempt++) {
    Start-Sleep -Seconds 2
    try { $status = [int](Invoke-WebRequest -Uri "$url/" -UseBasicParsing -TimeoutSec 10).StatusCode } catch { $status = 0 }
}
if ($status -ne 200) { throw "Filestash did not answer HTTP 200 at $url" }

Write-Host "Ready: $url (HTTP 200)"
Write-Host "1. 初回は $url で管理者パスワードを設定する（filestashAdminPassword）"
Write-Host "2. 管理画面のストレージ設定でSFTPを選ぶ"
Write-Host "3. ログイン画面で host=$SftpContainer port=22 user=qa と sftpPassword を入力する"
Write-Host "値は $PrivatePath にある"
