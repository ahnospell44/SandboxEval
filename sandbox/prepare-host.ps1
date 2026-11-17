param([string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path)
$ErrorActionPreference = "Stop"
$utf8NoBom  = [System.Text.UTF8Encoding]::new($false)
$BuildDir   = Join-Path $WorkspaceRoot "build"
$ResultsDir = Join-Path $WorkspaceRoot "test-results"
$SrcDir     = Join-Path $WorkspaceRoot "src"
$Template   = Join-Path $WorkspaceRoot "sandbox\eval-build.template.wsb"
$OutWsb     = Join-Path $WorkspaceRoot "sandbox\eval-build.wsb"

New-Item -ItemType Directory -Force -Path $BuildDir, $ResultsDir, $SrcDir | Out-Null
Remove-Item -Path "$ResultsDir\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$BuildDir\*"   -Recurse -Force -ErrorAction SilentlyContinue

if (Get-ChildItem -Path $SrcDir -ErrorAction SilentlyContinue) {
    Copy-Item -Path "$SrcDir\*" -Destination $BuildDir -Recurse -Force
}

$renderedXml = (Get-Content -Path $Template -Raw).Replace("{{WORKSPACE_ROOT}}", $WorkspaceRoot)
[System.IO.File]::WriteAllText($OutWsb, $renderedXml, $utf8NoBom)
Write-Host "[+] Staged build artifacts and generated $OutWsb for $WorkspaceRoot"