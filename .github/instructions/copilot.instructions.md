---
applyTo: '**/*.ps1'
---

## 🧠 PowerShell AI Instructions & Best Practices

These are project-wide coding standards and architectural guidelines for all AI-generated PowerShell scripts and modules. Apply consistently across all files.

---

### ✅ General Principles

- **Always write cross-platform** code (Windows, macOS, Linux).  
  Never assume `C:\` paths, `cmd.exe`, `reg.exe`, or Windows-only tools unless explicitly checking for OS and wrapping alternatives.

- **Avoid clashing with reserved system variables or automatic variables.**  
  Do **not** define or override:
  - `$IsWindows`, `$IsLinux`, `$IsMacOS`, `$PROFILE`, `$PSVersionTable`, etc.  
  Instead, use alternative names like `$IsWindowsOs`, `$IsUnixLike`, etc.

- **All scripts must include comments** that:
  - Explain intent of logic blocks
  - Describe inputs and outputs for functions
  - Clarify use of external commands or dependencies

- Keep **functions under 40 lines** unless strictly necessary. Break logic into smaller reusable components.

- **Avoid inline execution of logic-heavy code** in the main script body. Use a modular approach:
  ```
  ├── src/
  │   ├── core/
  │   │   └── system.ps1
  │   ├── ui/
  │   │   └── banner.ps1
  │   └── main.ps1
  ```

- **Use parameter blocks** with proper validation for any function that accepts input:
  ```powershell
  param (
      [Parameter(Mandatory)]
      [string]$Path
  )
  ```

---

### ⚙️ Cross-Platform Coding

- Use `$IsWindowsOs`, `$IsLinuxOs`, `$IsMacOs` for OS checks:
  ```powershell
  $IsWindowsOs = $PSVersionTable.Platform -eq 'Win32NT'
  ```

- Prefer `Join-Path`, `Split-Path`, `Resolve-Path` over hardcoded slashes.

- For file operations, use native PowerShell cmdlets instead of platform-specific tools.

- When needing platform-specific logic, wrap it:
  ```powershell
  if ($IsWindowsOs) {
      # Windows-only logic
  } elseif ($IsLinuxOs) {
      # Linux alternative
  }
  ```

---

### 🧼 Code Style & Safety

- Use **PascalCase** for functions and **camelCase** for variables.

- Validate all inputs and fail fast with clear messages:
  ```powershell
  if (-not (Test-Path $inputPath)) {
      throw "Path '$inputPath' does not exist."
  }
  ```

- Use `Write-Host` or `Write-Output` consistently, and only when necessary. Prefer structured logging where applicable.

- Avoid aliases like `ls`, `gc`, `ni`, etc. Use full cmdlet names: `Get-ChildItem`, `Get-Content`, `New-Item`.

---

### 📦 Structure & Maintainability

- All functions should be in separate `.ps1` files grouped by concern: `file.ps1`, `network.ps1`, `os.ps1`, etc.

- Main scripts (`main.ps1`, `entry.ps1`) should only:
  - Load dependencies
  - Orchestrate high-level flow
  - Handle top-level errors

- Reusable logic must live in `src/` or `lib/`.

- Avoid monolithic `.ps1` files with hundreds of lines. Split by topic, purpose, and scope.

---

### 🧪 Quality and Error Handling

- Every critical command should have error handling:
  ```powershell
  try {
      Start-Process "something.exe" -ErrorAction Stop
  } catch {
      Write-Error "Failed to start process: $_"
  }
  ```

- Prefer `$ErrorActionPreference = 'Stop'` at the top of the script unless exceptions are expected.

- Always provide fallback logic when calling external tools or using optional features.

---

### 📚 Comments & Documentation

- Begin every script and function with a comment block like:
  ```powershell
  <#
      .SYNOPSIS
      Does X thing for Y purpose.

      .DESCRIPTION
      More detailed description here.

      .PARAMETER Path
      Path to the file to process.

      .OUTPUTS
      Returns success status as boolean.
  #>
  ```

- Use inline comments for tricky logic, edge cases, or intentional workarounds.

---

### 🔒 Security & Safety

- Never execute raw user input without sanitization.
- Avoid unnecessary use of `Invoke-Expression`.
- Clearly mark **risky** operations with warnings or confirmation prompts.

---

### 🧩 Extras

- Prefer script-wide feature flags for toggling behavior:
  ```powershell
  $EnableVerboseLogs = $true
  ```

- Consistently use `$PSScriptRoot` for relative imports.

- All external commands (e.g., `curl`, `git`, `ffmpeg`) must be:
  - Checked for availability
  - Wrapped in abstraction functions
  - Used with cross-platform args where possible

---

By following these rules, AI-generated PowerShell code will be more maintainable, readable, secure, and portable across platforms.

```powershell
# Example: Cross-platform hello script
$IsWindowsOs = $PSVersionTable.Platform -eq 'Win32NT'

function Show-Greeting {
    param ([string]$Name)

    Write-Host "Hello, $Name!"

    if ($IsWindowsOs) {
        Write-Host "You're on Windows"
    } else {
        Write-Host "You're on a Unix-like OS"
    }
}
```