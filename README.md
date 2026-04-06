# ClaudeTools

A PowerShell module for managing [Claude Desktop](https://claude.ai/download) configuration, MCP/Connector server logs, and backups.

## The Problem

Claude Desktop stores its configuration file (`claude_desktop_config.json`) in different locations depending on how it was installed:

| Install method | Config path |
|---|---|
| Direct `.exe` installer | `%APPDATA%\Claude\` |
| Microsoft Store / WinGet / MSIX | `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\` |

Finding this file manually — especially after a fresh Windows install — wastes time. ClaudeTools finds it automatically regardless of install method, and provides commands for editing, backing up, restoring, and reading logs.

## Installation

### Option A — Copy to your PowerShell modules folder

```powershell
# Create the module folder
New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\ClaudeTools" -Force

# Copy module files
Copy-Item "ClaudeTools.psm1" "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\ClaudeTools\"
Copy-Item "ClaudeTools.psd1" "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\ClaudeTools\"
```

### Option B — Add to your custom modules folder

If you maintain a personal `MyModules` folder referenced in your PowerShell profile:

```powershell
New-Item -ItemType Directory -Path "C:\path\to\MyModules\ClaudeTools" -Force
Copy-Item "ClaudeTools.psm1" "C:\path\to\MyModules\ClaudeTools\"
Copy-Item "ClaudeTools.psd1" "C:\path\to\MyModules\ClaudeTools\"
```

Then add to your `$PROFILE`:

```powershell
Import-Module ClaudeTools
```

### First run — unblock the module

On a fresh Windows install or if execution policy blocks the module:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Get-ChildItem "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\ClaudeTools" | Unblock-File
Import-Module ClaudeTools
```

## Commands

### `Get-ClaudeConfig`

Finds and displays the full path to `claude_desktop_config.json`.

```powershell
Get-ClaudeConfig
# Claude config found at:
# C:\Users\YourName\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json
```

### `Edit-ClaudeConfig`

Opens `claude_desktop_config.json` in Notepad.

```powershell
Edit-ClaudeConfig
```

Restart Claude Desktop after saving for changes to take effect.

### `Show-ClaudeConfig`

Pretty-prints the config as formatted JSON.

```powershell
Show-ClaudeConfig
```

### `Backup-ClaudeConfig`

Backs up config files. Defaults to `Documents\ClaudeBackup`. Validates the target drive, and offers to create the folder if it doesn't exist.

```powershell
# Default backup location (Documents\ClaudeBackup)
Backup-ClaudeConfig

# Custom path
Backup-ClaudeConfig -Destination "D:\MyBackups\Claude"
```

### `Restore-ClaudeConfig`

Restores config files from a backup. Claude Desktop must be installed and launched at least once before restoring.

```powershell
# Default backup location
Restore-ClaudeConfig

# Custom path
Restore-ClaudeConfig -Source "D:\MyBackups\Claude"
```

### `Get-ClaudeLogs`

Reads Claude Desktop log files. Supports filtering, server-specific views, and live tail mode.

```powershell
# Last 20 lines of main.log (default)
Get-ClaudeLogs

# Last 50 lines of main.log
Get-ClaudeLogs -Last 50

# All MCP/Connector server logs
Get-ClaudeLogs -MCP

# Error lines only across all MCP logs
# Note: use "[error]" with brackets to match the severity tag,
# not just the word "error" anywhere in the log line
Get-ClaudeLogs -MCP -Filter "[error]"

# Specific MCP server log
Get-ClaudeLogs -Server nyxis-dev

# Live tail a specific server
Get-ClaudeLogs -Server nyxis-dev -Follow

# Live tail all MCP server logs (interleaved with [server-name] prefix)
Get-ClaudeLogs -MCP -Follow

# Search all logs for a string
Get-ClaudeLogs -All -Filter "disconnected"
```

#### Log files

| File | Contents |
|---|---|
| `main.log` | Claude Desktop application events, startup, crashes |
| `mcp-server-*.log` | Individual MCP/Connector server connection and tool call logs |
| `mcp.log` | MCP orchestration layer |
| `ssh.log` | SSH tunnel activity |
| `claude.ai-web.log` | Embedded browser activity |

## Backup and restore workflow

The most common use case — preserving your MCP server configuration across a Windows reinstall:

```powershell
# Before reinstalling Windows
Backup-ClaudeConfig -Destination "D:\backup\Claude"

# After reinstalling Windows and Claude Desktop
# (launch Claude Desktop once first to initialize folders)
Restore-ClaudeConfig -Source "D:\backup\Claude"
# Restart Claude Desktop
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Claude Desktop installed and launched at least once

## License

MIT — see [LICENSE](LICENSE)

## Author

[Bharat Suneja](https://exchangepedia.com) — [GitHub](https://github.com/bharatsuneja)
