# 手元のフォルダーと、SFTPサーバー上の共有領域のファイルを SHA-256 で比べる。
# 画面から上げ下げしたファイルの中身が1バイトも変わっていないかを確かめるのに使う。読み取りだけを行う。
#
#   .\compare-hashes.ps1 -LocalDirectory .\seed
#   .\compare-hashes.ps1 -LocalDirectory C:\work\share-me -RemoteDirectory /home/qa/share/project
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LocalDirectory,
    [string]$RemoteDirectory = '/home/qa/share',
    [string]$Connection = '',
    [string]$Container = 'filestash-demo-sftp'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Base = @()
if ($Connection) { $Base = @('--connection', $Connection) }
$root = (Resolve-Path -LiteralPath $LocalDirectory).Path

$results = foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse) {
    $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $local = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $output = @(& podman @Base exec $Container sha256sum "$RemoteDirectory/$relative" 2>$null)
    $remote = ''
    if ($LASTEXITCODE -eq 0 -and $output.Count -gt 0) { $remote = ([string]$output[0]).TrimStart('\').Split(' ')[0].ToLowerInvariant() }
    [pscustomobject]@{
        RelativePath = $relative
        Bytes        = $file.Length
        Result       = if (-not $remote) { 'missing' } elseif ($remote -eq $local) { 'match' } else { 'DIFFERENT' }
        LocalSHA256  = $local
        ServerSHA256 = $remote
    }
}

$results | Format-Table RelativePath, Bytes, Result -AutoSize
$matched = @($results | Where-Object Result -eq 'match').Count
Write-Host "$matched / $(@($results).Count) files match"
if ($matched -ne @($results).Count) { exit 1 }
