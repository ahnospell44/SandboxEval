#Requires -RunAsAdministrator
param(
    [string]$TemplateRepoUrl = "https://github.com/ahnospell44/SandboxEval.git",
    [string]$DefaultDevRoot  = "D:\Development",
    [switch]$InstallProfileHelper
)
$ErrorActionPreference = "Stop"

Write-Host "[1/4] Checking Windows Sandbox feature..." -ForegroundColor Cyan
$featureInfo = dism.exe /Online /Get-FeatureInfo /FeatureName:Containers-DisposableClientVM
if ($featureInfo -notmatch "State\s*:\s*Enabled") {
    Write-Host "      Enabling Containers-DisposableClientVM via DISM..." -ForegroundColor Yellow
    dism.exe /Online /Enable-Feature /FeatureName:Containers-DisposableClientVM /All /NoRestart
    $RebootNeeded = $true
} else {
    Write-Host "      Windows Sandbox is already enabled." -ForegroundColor Green
}

Write-Host "[2/4] Verifying PowerShell 7 (pwsh.exe)..." -ForegroundColor Cyan
if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
    Write-Host "      Installing unpackaged PowerShell 7 via WinGet..." -ForegroundColor Yellow
    winget install --id Microsoft.PowerShell --source winget --exact --silent --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "      pwsh.exe detected." -ForegroundColor Green
}

Write-Host "[3/4] Installing recommended VS Code extensions..." -ForegroundColor Cyan
if (Get-Command code -ErrorAction SilentlyContinue) {
    code --install-extension ms-vscode.powershell --force | Out-Null
    code --install-extension fflaten.windowssandbox-configuration --force | Out-Null
    Write-Host "      VS Code extensions verified." -ForegroundColor Green
} else {
    Write-Warning "VS Code CLI (code) not found on PATH. Skipping extension auto-install."
}

Write-Host "[4/4] Checking PowerShell profile helper..." -ForegroundColor Cyan
if ($InstallProfileHelper) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    $currentProfile = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($currentProfile -notmatch "function New-SandboxEval") {
        $helperBlock = @(
            ""
            "# VS Code Windows Sandbox Evaluation Scaffolder"
            "function New-SandboxEval {"
            "    param("
            "        [Parameter(Mandatory)][string]`$Name,"
            "        [string]`$BasePath = `"$DefaultDevRoot`","
            "        [string]`$TemplateUrl = `"$TemplateRepoUrl`","
            "        [switch]`$RunNow"
            "    )"
            "    `$Target = Join-Path `$BasePath `$Name"
            "    if (Test-Path `$Target) { throw `"Target folder already exists: `$Target`" }"
            "    git clone --depth 1 `$TemplateUrl `$Target"
            "    Remove-Item -Path (Join-Path `$Target `".git`") -Recurse -Force"
            "    git -C `$Target init -b main | Out-Null"
            "    pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path `$Target `"sandbox\prepare-host.ps1`")"
            "    code `$Target"
            "    if (`$RunNow) { Start-Process (Join-Path `$Target `"sandbox\eval-build.wsb`") }"
            "}"
        ) -join "`r`n"
        Add-Content -Path $profilePath -Value $helperBlock -Encoding UTF8
        Write-Host "      Added New-SandboxEval helper to $profilePath" -ForegroundColor Green
    } else {
        Write-Host "      New-SandboxEval already present in $profilePath" -ForegroundColor Green
    }
}

if ($RebootNeeded) {
    Write-Warning "Host reboot is required before launching Windows Sandbox for the first time."
} else {
    Write-Host "[+] Host onboarding complete. Open workspace in VS Code and press Ctrl+Shift+B." -ForegroundColor Green
}