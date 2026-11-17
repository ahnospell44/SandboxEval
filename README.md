# VS Code Windows Sandbox Evaluation Template

Isolated build and PowerShell debug evaluation harness using Windows Sandbox.

## Quick Start
1. Place scripts or build targets inside `src/` (entry point: `src/test-suite.ps1` or `app_tests.exe`).
2. Open the repository root in VS Code and press **`Ctrl+Shift+B`**.
3. Inspect captured transcripts and exported JSON/XML telemetry in `test-results/`.

## Architecture
- `sandbox/prepare-host.ps1`: Stages `src/` into `build/` and generates BOM-less `sandbox/eval-build.wsb` dynamically.
- `sandbox/eval-build.template.wsb`: Network-disabled, vGPU-disabled Sandbox profile (`build` Read-Only, `test-results` Read-Write).
- `sandbox/invoke-tests.ps1`: Guest runner under `WDAGUtilityAccount` that executes tests, verifies Windows Event Log alerts, and signals completion via `eval.done`.