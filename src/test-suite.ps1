$AlertSource = "InternalApp-DebugMonitor"
$JsonAlertPath = "C:\Workspace\test-results\debug-alerts.json"
Write-Host "[DEMO] Executing script on isolated guest: $env:COMPUTERNAME (User: $env:USERNAME)"
if (-not [System.Diagnostics.EventLog]::SourceExists($AlertSource)) {
    New-EventLog -LogName Application -Source $AlertSource
}
Write-EventLog -LogName Application -Source $AlertSource -EntryType Warning -EventId 9001 -Message "DEBUG ALERT: Threshold exceeded in module AuthValidator (Simulated Failure)."
$alertPayload = [PSCustomObject]@{
    Timestamp   = (Get-Date).ToString("o")
    GuestHost   = $env:COMPUTERNAME
    Severity    = "WARNING"
    EventId     = 9001
    Component   = "AuthValidator"
    AlertDetail = "Simulated anomalous token retry count (5/5) caught during internal debug run."
}
$alertPayload | ConvertTo-Json -Depth 4 | Set-Content -Path $JsonAlertPath -Encoding UTF8
Write-Warning "[ALERT-TRIGGERED] EventId=9001 | AuthValidator threshold alert logged cleanly."