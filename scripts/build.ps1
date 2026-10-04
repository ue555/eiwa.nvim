param([string]$Version = 'dev')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $targetOS = (go env GOOS).Trim()
    $targetArch = (go env GOARCH).Trim()
    $suffix = if ($targetOS -eq 'windows') { '.exe' } else { '' }
    New-Item -ItemType Directory -Path 'bin' -Force | Out-Null
    $outputPath = Join-Path 'bin' "eiwa-agent-$targetOS-$targetArch$suffix"
    go build -trimpath -ldflags "-s -w -X main.version=$Version" -o $outputPath ./cmd/eiwa-agent
    if ($LASTEXITCODE -ne 0) { throw 'Go build failed.' }
    Copy-Item -LiteralPath $outputPath -Destination (Join-Path 'bin' "eiwa-agent$suffix") -Force
    Write-Output "Built $outputPath"
} finally { Pop-Location }
