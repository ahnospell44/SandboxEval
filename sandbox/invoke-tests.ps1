$ErrorActionPreference = "Stop"
$BuildDir   = "C:\Workspace\build"
$ResultsDir = "C:\Workspace\test-results"
$LogFile    = Join-Path $ResultsDir "eval-run.log"
$Sentinel   = Join-Path $ResultsDir "eval.done"
$StartTime  = (Get-Date).AddSeconds(-5)

$mountDeadline = (Get-Date).AddSeconds(15)
while (-not (Test-Path $ResultsDir) -and (Get-Date) -lt $mountDeadline) { Start-Sleep -Milliseconds 250 }

Start-Transcript -Path $LogFile -Force | Out-Null
try {
    Write-Host "========================================================="
    Write-Host " [SANDBOX HARNESS] Initializing Isolated Environment"
    Write-Host "========================================================="
    while (-not (Test-Path $BuildDir) -and (Get-Date) -lt $mountDeadline) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path $BuildDir)) {
        $mounted = if (Test-Path "C:\Workspace") { (Get-ChildItem "C:\Workspace" -Name) -join ", " } else { "C:\Workspace missing" }
        throw "C:\Workspace\build never mounted. Visible under C:\Workspace: [$mounted]"
    }
    Set-Location $BuildDir
    if (Test-Path ".\test-suite.ps1") {
        & .\test-suite.ps1
        $ExitCode = if ($?) { 0 } else { 1 }
    } else {
        throw "No test-suite.ps1 found inside $BuildDir."
    }

    Write-Host "`n========================================================="
    Write-Host " [ALERT VERIFICATION] Inspecting Guest Windows Event Log"
    Write-Host "========================================================="
    $capturedEvents = Get-WinEvent -FilterHashtable @{ LogName = "Application"; StartTime = $StartTime } -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -eq "InternalApp-DebugMonitor" -or $_.Id -eq 9001 }
    if ($capturedEvents) {
        foreach ($evt in $capturedEvents) {
            Write-Host ("[CAPTURED EVENT] Time: {0} | ID: {1} | Level: {2} | Source: {3}" -f $evt.TimeCreated, $evt.Id, $evt.LevelDisplayName, $evt.ProviderName)
            Write-Host ("                 Message: {0}" -f $evt.Message)
        }
    } else {
        Write-Host "[!] No matching Application Event Log alerts detected during run."
    }
    Set-Content -Path $Sentinel -Value $ExitCode -Encoding ASCII
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    Set-Content -Path $Sentinel -Value 1 -Encoding ASCII
} finally {
    Stop-Transcript | Out-Null
}