# VS Code Windows Sandbox Evaluation Template

Automated, isolated build and PowerShell debug evaluation harness powered by **Windows Sandbox** and **Visual Studio Code**. Source code and compiler toolchains stay on the host, staged artifacts mount into a disposable Hyper-V micro-VM as **Read-Only**, and execution transcripts, Windows Event Log captures, and structured JSON telemetry stream back into VS Code automatically.

---

## 1. One-Time Developer Workstation Setup (Automated)

Requirements: **Windows 10/11 Pro, Enterprise, or Education** with hardware virtualization enabled in BIOS/UEFI, **Git**, and **Visual Studio Code**.

Clone this repository once and run the elevated bootstrap script to enable `Containers-DisposableClientVM`, verify unpackaged PowerShell 7 (`pwsh.exe`), install VS Code `.wsb` / PowerShell extensions, and register the `New-SandboxEval` CLI helper in `$PROFILE.CurrentUserAllHosts`:

```powershell
# Run from an Administrator PowerShell prompt:
git clone [https://github.com/ahnospell44/SandboxEval.git](https://github.com/ahnospell44/SandboxEval.git) D:\Development\SandboxEval
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Development\SandboxEval\sandbox\bootstrap-dev.ps1 -InstallProfileHelper
```

> **Important:** If the bootstrap script enables Windows Sandbox for the first time, **reboot Windows once** before running your first evaluation so `CmService` synthesizes the base OS container layer.

---

## 2. Spinning Up a New Evaluation Workspace

Choose any of the three automated scaffolding workflows depending on whether you want a local ephemeral folder or a tracked GitHub repository:

### Option A: Single-Command Local Ephemeral Eval (`New-SandboxEval`)
After running `bootstrap-dev.ps1 -InstallProfileHelper` (and opening a new terminal), scaffold an isolated workspace from anywhere:

```powershell
# Clones template, strips template .git, initializes clean repo, renders .wsb, and opens VS Code:
New-SandboxEval -Name "audit-login-script"

# Optional: immediately boot the Sandbox run without waiting to press Ctrl+Shift+B:
New-SandboxEval -Name "audit-login-script" -RunNow
```

### Option B: Tracked GitHub Repository via GitHub CLI (`gh`)
Instantiates a fresh private GitHub repository from this template, clones it locally, and opens VS Code:

```powershell
gh repo create my-feature-eval --template ahnospell44/SandboxEval --private --clone
code .\my-feature-eval
```

### Option C: Global VS Code Command Palette Task (No Terminal Required)
Open **Command Palette (`Ctrl+Shift+P`)** -> **`Tasks: Open User Tasks`** and add this global task once so it remains available inside VS Code regardless of which workspace is open:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "New Sandbox Evaluation Workspace",
      "type": "shell",
      "options": { "shell": { "executable": "pwsh.exe", "args": ["-NoProfile", "-Command"] } },
      "command": "$t = Join-Path 'D:\\Development' '${input:evalName}'; git clone --depth 1 [https://github.com/ahnospell44/SandboxEval.git](https://github.com/ahnospell44/SandboxEval.git) $t; Remove-Item \"$t\\.git\" -Recurse -Force; git -C $t init -b main \vert{} Out-Null; code -n$t",
      "problemMatcher": []
    }
  ],
  "inputs": [
    {
      "id": "evalName",
      "type": "promptString",
      "description": "Folder name for the new Sandbox evaluation (created under D:\\Development)"
    }
  ]
}
```

---

## 3. Running Evaluations (`Ctrl+Shift+B` & Headless CLI)

### Standard VS Code Workflow
1. Place your target script (`src/test-suite.ps1`) or compiled binary (`app_tests.exe`) inside **`src/`**.
2. Press **`Ctrl+Shift+B`** in VS Code.
3. Automated pipeline sequence:
   - **Task 1 (`sandbox/prepare-host.ps1`)** cleans prior `build/` and `test-results/` artifacts, copies `src/*` into `build/`, and renders `sandbox/eval-build.wsb` (BOM-less UTF-8) stamped with your local folder path.
   - **Task 2** closes any lingering Sandbox instance, launches `eval-build.wsb` with networking and clipboard redirection disabled, waits for guest completion (`test-results/eval.done`), outputs `test-results/eval-run.log` into the VS Code terminal, tears down the Sandbox VM, and exits with the guest status code (`0` = Pass, non-zero = Fail).

### Headless / Scripted CLI Execution (Outside VS Code)
Trigger the full lifecycle directly from PowerShell or local automation scripts:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\sandbox\prepare-host.ps1
Stop-Process -Name WindowsSandboxClient,WindowsSandbox -Force -ErrorAction SilentlyContinue
Start-Process .\sandbox\eval-build.wsb
while (-not (Test-Path .\test-results\eval.done)) { Start-Sleep -Seconds 2 }
Get-Content .\test-results\eval-run.log
$exitCode = [int](Get-Content .\test-results\eval.done -Raw).Trim()
Stop-Process -Name WindowsSandboxClient,WindowsSandbox -Force -ErrorAction SilentlyContinue
exit $exitCode
```

---

## 4. Customizing Build Targets & Alert Assertions

### Compiling Binaries on the Host (`sandbox/prepare-host.ps1`)
Windows Sandbox boots a clean Windows image containing Windows PowerShell 5.1 (`powershell.exe`) without `.NET SDKs`, `MSVC` runtimes, or `Python` pre-installed. Compile self-contained artifacts on the host inside `sandbox/prepare-host.ps1`:

- **.NET / C#:**
  ```powershell
  dotnet publish "$SrcDir" -c Release -r win-x64 --self-contained true -o "$BuildDir"
  ```
- **Rust (Static MSVC CRT):**
  ```powershell
  $env:RUSTFLAGS = "-C target-feature=+crt-static"
  cargo build --release --manifest-path "$SrcDir\Cargo.toml"
  Copy-Item "$SrcDir\target\release\app_tests.exe" "$BuildDir\" -Force
  ```
- **Offline Portable Runtimes (Python / PowerShell 7):** Extract portable `.zip` distributions into a host `tools/` folder, add a `<MappedFolder>` entry with `<ReadOnly>true</ReadOnly>` in `sandbox/eval-build.template.wsb`, and invoke `C:\Workspace\tools\...` from `invoke-tests.ps1` while keeping `<Networking>Disable</Networking>`.

### Enforcing Pass/Fail Gates on Windows Event Log Alerts (`sandbox/invoke-tests.ps1`)
By default, `invoke-tests.ps1` queries the guest Application Event Log for provider `InternalApp-DebugMonitor` or Event ID `9001` and writes structured telemetry to `test-results/debug-alerts.json`. To fail the VS Code build task when an expected alert does **not** fire, update the check in `sandbox/invoke-tests.ps1`:

```powershell
if (-not $capturedEvents) {
    Write-Host "[FAIL] Expected Event ID 9001 did not fire."
    $ExitCode = 1
}
```

### Verify Host Isolation After Any Run
Confirm that elevated guest registry and Event Log writes did not persist on the host workstation:

```powershell
Get-Content .\test-results\debug-alerts.json
[System.Diagnostics.EventLog]::SourceExists("InternalApp-DebugMonitor") # Expected: False
```

---

## 5. Repository Layout & Isolation Boundaries

| Path | Tracked in Git | Sandbox Access | Purpose |
| :--- | :--- | :--- | :--- |
| `.vscode/tasks.json` | Yes | Host Only | Binds `Ctrl+Shift+B` to Host Stage -> Sandbox Run -> Teardown |
| `sandbox/bootstrap-dev.ps1` | Yes | Host Only | One-time elevated host feature, `pwsh`, and `$PROFILE` setup |
| `sandbox/prepare-host.ps1` | Yes | Host Only | Stages `src/` to `build/` and renders BOM-less `eval-build.wsb` |
| `sandbox/eval-build.template.wsb` | Yes | Host Only | Parameterized `{{WORKSPACE_ROOT}}` Sandbox hardware/isolation spec |
| `sandbox/eval-build.wsb` | **Ignored** | Host Only | Machine-specific `.wsb` generated dynamically at build time |
| `sandbox/invoke-tests.ps1` | Yes | **Read-Only** | Guest entrypoint (`WDAGUtilityAccount`), Event Log verifier & transcript writer |
| `src/` | Yes | Not Mounted | Developer source code / scripts (isolated from guest VM) |
| `build/` | **Ignored** | **Read-Only** | Staged artifacts mounted at `C:\Workspace\build` |
| `test-results/` | **Ignored** | **Read-Write** | Writable guest output folder (`eval-run.log`, `debug-alerts.json`, `eval.done`) |

---

## 6. Troubleshooting Quick Reference

- **`Get-WindowsOptionalFeature: Class not registered` (`0x80040154`):** Typically caused by running packaged Microsoft Store (`WindowsApps`) PowerShell 7. Enable via `dism.exe /Online /Enable-Feature /FeatureName:Containers-DisposableClientVM /All` or run `sandbox/bootstrap-dev.ps1` to install unpackaged `Microsoft.PowerShell` via WinGet.
- **`Windows Sandbox failed to initialize (0x80070002)`:** Usually indicates a pending host reboot after enabling `Containers-DisposableClientVM`, or launching `eval-build.wsb` before `prepare-host.ps1` created `build/` and `test-results/`. Press `Ctrl+Shift+B` so Task 1 creates all mapped directories first.
- **`Data at the root level is invalid. Line 1, position 1`:** `WindowsSandboxClient.exe` rejects `.wsb` files saved with a UTF-8 BOM (`0xEF 0xBB 0xBF`). Let `prepare-host.ps1` generate `eval-build.wsb` (`UTF8Encoding($false)`) and keep `"files.encoding": "utf8"` in `.vscode/settings.json`.
- **Single-Instance Limit:** Windows client hosts only permit **one** active `WindowsSandbox.exe` instance at a time; Task 2 terminates any lingering instance before starting a fresh evaluation.