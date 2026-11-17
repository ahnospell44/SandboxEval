$ErrorActionPreference = "Stop"
$ResultsDir = "C:\Workspace\test-results"
$LogFile    = Join-Path $ResultsDir "eval-run.log"
$Sentinel   = Join-Path $ResultsDir "eval.done"
Start-Transcript -Path $LogFile -Force
try {
    Write-Host "[*] Initializing Sandbox Evaluation Environment..."
    Set-Location "C:\Workspace\build"
    if (Test-Path ".\app_tests.exe") {
        & .\app_tests.exe --gtest_output="xml:$ResultsDir\unit-results.xml"
        $ExitCode = $LASTEXITCODE
    } elseif (Test-Path ".\test-suite.ps1") {
        & .\test-suite.ps1
        $ExitCode = if ($?) { 0 } else { 1 }
    } else {
        throw "No target binary or test suite found in C:\Workspace\build."
    }
    Set-Content -Path $Sentinel -Value $ExitCode -Encoding ASCII
    Write-Host "[+] Evaluation completed with exit code: $ExitCode"
} catch {
    Write-Error $_
    Set-Content -Path $Sentinel -Value 1 -Encoding ASCII
} finally {
    Stop-Transcript
}