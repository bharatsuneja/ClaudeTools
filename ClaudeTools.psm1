# ClaudeTools.psm1
# PowerShell module for managing Claude Desktop configuration and logs
# https://github.com/bharatsuneja/ClaudeTools
# MIT License — see LICENSE file
# Version 1.2.0

# ─────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────

function Find-ClaudeConfigPath {
    <#
    .SYNOPSIS
        Private helper. Locates claude_desktop_config.json regardless of install method.
    .NOTES
        Claude Desktop stores config in different locations depending on install method:
        - .exe installer  -> $env:APPDATA\Claude\
        - Store/WinGet    -> $env:LOCALAPPDATA\Packages\Claude_*\LocalCache\Roaming\Claude\
        - MSIX enterprise -> same Packages path as Store
    #>
    # Standard .exe installer path
    $standardPath = "$env:APPDATA\Claude\claude_desktop_config.json"
    if (Test-Path $standardPath) { return $standardPath }

    # Store / MSIX / WinGet install — config is inside the app package sandbox
    $packagePath = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Recurse `
        -ErrorAction SilentlyContinue `
        -Filter "claude_desktop_config.json" | Select-Object -First 1

    if ($packagePath) { return $packagePath.FullName }

    return $null
}

function Find-ClaudeLogsPath {
    <#
    .SYNOPSIS
        Private helper. Returns the Claude Desktop logs directory path.
    #>
    $configPath = Find-ClaudeConfigPath
    if (-not $configPath) { return $null }
    return Join-Path (Split-Path $configPath -Parent) "logs"
}

function Get-DefaultBackupPath {
    <#
    .SYNOPSIS
        Private helper. Returns the default backup path in the user's Documents folder.
    #>
    return Join-Path $env:USERPROFILE "Documents\ClaudeBackup"
}

function Test-BackupPath {
    <#
    .SYNOPSIS
        Private helper. Validates a backup destination path.
    .DESCRIPTION
        Checks that the drive letter exists and is accessible.
        If the folder does not exist, prompts the user to create it.
    .OUTPUTS
        Returns the validated path string, or $null if validation failed.
    #>
    param([string]$Path)

    # Check drive is valid and accessible
    $drive = Split-Path -Path $Path -Qualifier -ErrorAction SilentlyContinue
    if ($drive -and -not (Test-Path $drive)) {
        Write-Host "Drive '$drive' is not available or does not exist." -ForegroundColor Red
        Write-Host "Please specify a valid path on an available drive." -ForegroundColor Yellow
        return $null
    }

    # Check if folder exists — offer to create if not
    if (-not (Test-Path $Path)) {
        Write-Host "Folder not found: $Path" -ForegroundColor Yellow
        $create = Read-Host "Would you like to create it? (Y/N)"
        if ($create -imatch "^y") {
            try {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
                Write-Host "Created: $Path" -ForegroundColor Green
            } catch {
                Write-Host "Failed to create folder: $_" -ForegroundColor Red
                return $null
            }
        } else {
            Write-Host "Backup cancelled." -ForegroundColor Yellow
            return $null
        }
    }

    return $Path
}

# ─────────────────────────────────────────────
# CONFIG FUNCTIONS
# ─────────────────────────────────────────────

function Get-ClaudeConfig {
    <#
    .SYNOPSIS
        Finds and displays the path to claude_desktop_config.json.

    .DESCRIPTION
        Claude Desktop stores its config in different locations depending on
        the install method (.exe, Store, WinGet, MSIX enterprise). This command
        finds the config file regardless of where Claude Desktop was installed.

    .OUTPUTS
        Returns the full path string if found, otherwise $null.

    .EXAMPLE
        Get-ClaudeConfig
        Displays the config file path.

    .EXAMPLE
        $path = Get-ClaudeConfig
        notepad $path
        Capture the path and open it manually.
    #>
    $path = Find-ClaudeConfigPath
    if ($path) {
        Write-Host "Claude config found at:" -ForegroundColor Cyan
        Write-Host $path -ForegroundColor Green
        return $path
    } else {
        Write-Host "claude_desktop_config.json not found." -ForegroundColor Red
        Write-Host "Is Claude Desktop installed and has it been launched at least once?" -ForegroundColor Yellow
        return $null
    }
}

function Edit-ClaudeConfig {
    <#
    .SYNOPSIS
        Opens claude_desktop_config.json in Notepad.

    .DESCRIPTION
        Locates claude_desktop_config.json regardless of install method and
        opens it in Notepad for editing. After saving changes, restart
        Claude Desktop for them to take effect.

    .EXAMPLE
        Edit-ClaudeConfig
    #>
    $path = Find-ClaudeConfigPath
    if ($path) {
        Write-Host "Opening: $path" -ForegroundColor Cyan
        notepad $path
    } else {
        Write-Host "claude_desktop_config.json not found." -ForegroundColor Red
    }
}

function Show-ClaudeConfig {
    <#
    .SYNOPSIS
        Prints the contents of claude_desktop_config.json to the console.

    .DESCRIPTION
        Reads and pretty-prints the Claude Desktop configuration as formatted JSON.
        Useful for quickly inspecting MCP server/Connector definitions and
        preferences without opening an editor.

    .EXAMPLE
        Show-ClaudeConfig
    #>
    $path = Find-ClaudeConfigPath
    if ($path) {
        Write-Host "Contents of: $path" -ForegroundColor Cyan
        Write-Host "----------------------------------------"
        Get-Content $path | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } else {
        Write-Host "claude_desktop_config.json not found." -ForegroundColor Red
    }
}

function Backup-ClaudeConfig {
    <#
    .SYNOPSIS
        Backs up Claude Desktop config files to a specified folder.

    .DESCRIPTION
        Backs up claude_desktop_config.json, config.json, and
        extensions-installations.json to the destination folder.

        If no destination is specified, backs up to Documents\ClaudeBackup.
        Validates that the target drive is available. If the destination folder
        does not exist, you will be prompted to create it.

    .PARAMETER Destination
        Target backup folder path. Defaults to Documents\ClaudeBackup.
        The drive must be present and accessible. If the folder does not
        exist you will be asked whether to create it.

    .EXAMPLE
        Backup-ClaudeConfig
        Backs up to Documents\ClaudeBackup (default).

    .EXAMPLE
        Backup-ClaudeConfig -Destination "D:\MyBackups\Claude"
        Backs up to a custom path on D:\.

    .EXAMPLE
        Backup-ClaudeConfig -Destination "C:\ClaudeBackup"
        Backs up to a custom path. If the folder does not exist,
        you will be prompted to create it.
    #>
    param(
        [string]$Destination = (Get-DefaultBackupPath)
    )

    $configPath = Find-ClaudeConfigPath
    if (-not $configPath) {
        Write-Host "claude_desktop_config.json not found." -ForegroundColor Red
        return
    }

    $validatedPath = Test-BackupPath -Path $Destination
    if (-not $validatedPath) { return }

    $sourceDir = Split-Path $configPath -Parent
    $filesToBackup = @(
        "claude_desktop_config.json",
        "config.json",
        "extensions-installations.json"
    )

    $count = 0
    foreach ($file in $filesToBackup) {
        $src = Join-Path $sourceDir $file
        if (Test-Path $src) {
            Copy-Item $src $validatedPath -Force
            Write-Host "  Backed up: $file" -ForegroundColor Green
            $count++
        }
    }

    Write-Host "`n$count file(s) backed up to: $validatedPath" -ForegroundColor Cyan
}

function Restore-ClaudeConfig {
    <#
    .SYNOPSIS
        Restores Claude Desktop config files from a backup folder.

    .DESCRIPTION
        Restores claude_desktop_config.json, config.json, and
        extensions-installations.json from a backup folder.

        Claude Desktop must be installed and launched at least once before
        restoring, so that the target config folder exists. Restart Claude
        Desktop after restoring for changes to take effect.

    .PARAMETER Source
        Source backup folder path. Defaults to Documents\ClaudeBackup.

    .EXAMPLE
        Restore-ClaudeConfig
        Restores from Documents\ClaudeBackup (default).

    .EXAMPLE
        Restore-ClaudeConfig -Source "D:\MyBackups\Claude"
        Restores from a custom backup path.
    #>
    param(
        [string]$Source = (Get-DefaultBackupPath)
    )

    if (-not (Test-Path $Source)) {
        Write-Host "Backup folder not found: $Source" -ForegroundColor Red
        return
    }

    $configPath = Find-ClaudeConfigPath
    if (-not $configPath) {
        Write-Host "Claude Desktop config folder not found." -ForegroundColor Red
        Write-Host "Make sure Claude Desktop is installed and has been launched at least once." -ForegroundColor Yellow
        return
    }

    $destDir = Split-Path $configPath -Parent
    $filesToRestore = @(
        "claude_desktop_config.json",
        "config.json",
        "extensions-installations.json"
    )

    $count = 0
    foreach ($file in $filesToRestore) {
        $src = Join-Path $Source $file
        if (Test-Path $src) {
            Copy-Item $src $destDir -Force
            Write-Host "  Restored: $file" -ForegroundColor Green
            $count++
        }
    }

    Write-Host "`n$count file(s) restored to: $destDir" -ForegroundColor Cyan
    Write-Host "Restart Claude Desktop to apply changes." -ForegroundColor Yellow
}

# ─────────────────────────────────────────────
# LOG FUNCTIONS
# ─────────────────────────────────────────────

function Get-ClaudeLogs {
    <#
    .SYNOPSIS
        Reads Claude Desktop log files with flexible filtering and tail support.

    .DESCRIPTION
        By default shows the last 20 lines of main.log — the Claude Desktop
        application log. Use -MCP to view all MCP/Connector server logs,
        -Server for a specific server, or -All for every log file.

        Supports -Filter for grep-style line filtering and -Follow for live
        tail mode. In follow mode, multiple files are interleaved and each
        line is prefixed with [server-name] to identify its source.
        Press Ctrl+C to exit cleanly.

        Log files available in Claude Desktop:
          main.log              - Claude Desktop application events
          mcp-server-*.log      - Individual MCP/Connector server logs
          mcp.log               - MCP orchestration layer
          ssh.log               - SSH tunnel activity
          claude.ai-web.log     - Embedded browser activity

        Tip: Use -Filter "[error]" (with square brackets) to match only
        lines tagged with [error] severity, avoiding false positives from
        log message content that contains the word "error".

    .PARAMETER Last
        Number of lines to show per file. Default: 20

    .PARAMETER Server
        Show logs for a specific MCP server (partial name match supported).
        Example: -Server nyxis-dev  matches mcp-server-nyxis-dev.log

    .PARAMETER MCP
        Show the last N lines of all mcp-server-*.log files.

    .PARAMETER All
        Show the last N lines of every log file.

    .PARAMETER Filter
        Show only lines containing this string (case-insensitive).
        Recommended: -Filter "[error]" for error-level entries only.

    .PARAMETER Follow
        Live tail mode — streams new lines as they are written.
        Multiple files are prefixed with [server-name].
        Press Ctrl+C to stop cleanly.

    .EXAMPLE
        Get-ClaudeLogs
        Show last 20 lines of main.log.

    .EXAMPLE
        Get-ClaudeLogs -Last 50
        Show last 50 lines of main.log.

    .EXAMPLE
        Get-ClaudeLogs -MCP
        Show last 20 lines of all MCP server logs.

    .EXAMPLE
        Get-ClaudeLogs -MCP -Filter "[error]"
        Show only error-tagged lines across all MCP server logs.

    .EXAMPLE
        Get-ClaudeLogs -Server nyxis-dev
        Show last 20 lines of the nyxis-dev MCP server log.

    .EXAMPLE
        Get-ClaudeLogs -Server nyxis-dev -Follow
        Live tail the nyxis-dev server log.

    .EXAMPLE
        Get-ClaudeLogs -MCP -Follow
        Live tail all MCP server logs with [server-name] prefixes.

    .EXAMPLE
        Get-ClaudeLogs -All -Filter "disconnected"
        Search all logs for lines containing "disconnected".
    #>
    param(
        [int]$Last = 20,
        [string]$Server = "",
        [switch]$MCP,
        [switch]$All,
        [string]$Filter = "",
        [switch]$Follow
    )

    $logsDir = Find-ClaudeLogsPath
    if (-not $logsDir -or -not (Test-Path $logsDir)) {
        Write-Host "Claude Desktop logs folder not found." -ForegroundColor Red
        Write-Host "Is Claude Desktop installed and has it been launched at least once?" -ForegroundColor Yellow
        return
    }

    # ── Resolve which files to read ────────────────────────────────────────
    $logFiles = @()

    if ($Server -ne "") {
        # Exact match first, then partial
        $found = Get-ChildItem $logsDir -Filter "mcp-server-$Server.log" -ErrorAction SilentlyContinue
        if (-not $found) {
            $found = Get-ChildItem $logsDir | Where-Object { $_.Name -like "*$Server*" }
        }
        if (-not $found) {
            Write-Host "No log file found matching: $Server" -ForegroundColor Red
            Write-Host "`nAvailable log files:" -ForegroundColor Yellow
            Get-ChildItem $logsDir -Filter "*.log" | Select-Object -ExpandProperty Name |
                ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            return
        }
        $logFiles = @($found)

    } elseif ($MCP) {
        $logFiles = @(Get-ChildItem $logsDir -Filter "mcp-server-*.log" |
            Sort-Object LastWriteTime -Descending)
        if ($logFiles.Count -eq 0) {
            Write-Host "No MCP server log files found." -ForegroundColor Yellow
            return
        }

    } elseif ($All) {
        $logFiles = @(Get-ChildItem $logsDir -Filter "*.log" |
            Sort-Object LastWriteTime -Descending)

    } else {
        $mainLog = Join-Path $logsDir "main.log"
        if (-not (Test-Path $mainLog)) {
            Write-Host "main.log not found. Use -MCP or -All to see other logs." -ForegroundColor Yellow
            return
        }
        $logFiles = @(Get-Item $mainLog)
    }

    # ── Helper: filter lines ───────────────────────────────────────────────
    function Select-FilteredLines {
        param([string[]]$Lines, [string]$FilterStr)
        if ($FilterStr -eq "") { return $Lines }
        return $Lines | Where-Object { $_ -imatch [regex]::Escape($FilterStr) }
    }

    # ── Helper: colorize by severity tag ──────────────────────────────────
    function Write-LogLine {
        param([string]$Line, [string]$Prefix = "")
        $output = if ($Prefix) { "[$Prefix] $Line" } else { $Line }
        if     ($Line -imatch "\[error\]") { Write-Host $output -ForegroundColor Red }
        elseif ($Line -imatch "\[warn\]")  { Write-Host $output -ForegroundColor Yellow }
        elseif ($Line -imatch "\[info\]")  { Write-Host $output -ForegroundColor Gray }
        else                               { Write-Host $output }
    }

    # ── Follow / tail mode ─────────────────────────────────────────────────
    if ($Follow) {
        $isSingle = ($logFiles.Count -eq 1)
        Write-Host "Following $($logFiles.Count) log file(s). Press Ctrl+C to stop.`n" -ForegroundColor Cyan

        # Capture current file sizes as starting positions
        $positions = @{}
        foreach ($f in $logFiles) { $positions[$f.FullName] = $f.Length }

        # Show tail of existing content first
        foreach ($f in $logFiles) {
            $prefix = if ($isSingle) { "" } else { $f.BaseName -replace "^mcp-server-", "" }
            $lines = Get-Content $f.FullName -Tail $Last -ErrorAction SilentlyContinue
            $filtered = Select-FilteredLines $lines $Filter
            foreach ($line in $filtered) { Write-LogLine $line $prefix }
        }

        try {
            while ($true) {
                Start-Sleep -Milliseconds 500
                foreach ($f in $logFiles) {
                    $prefix = if ($isSingle) { "" } else { $f.BaseName -replace "^mcp-server-", "" }
                    $currentSize = (Get-Item $f.FullName -ErrorAction SilentlyContinue).Length
                    if ($null -eq $currentSize) { continue }

                    if ($currentSize -gt $positions[$f.FullName]) {
                        $stream = [System.IO.File]::Open(
                            $f.FullName,
                            [System.IO.FileMode]::Open,
                            [System.IO.FileAccess]::Read,
                            [System.IO.FileShare]::ReadWrite)
                        $stream.Seek($positions[$f.FullName], [System.IO.SeekOrigin]::Begin) | Out-Null
                        $reader = New-Object System.IO.StreamReader($stream)
                        while (-not $reader.EndOfStream) {
                            $line = $reader.ReadLine()
                            $filtered = Select-FilteredLines @($line) $Filter
                            foreach ($l in $filtered) { Write-LogLine $l $prefix }
                        }
                        $positions[$f.FullName] = $stream.Position
                        $reader.Close()
                        $stream.Close()
                    }
                }
            }
        } finally {
            Write-Host "`nStopped following logs." -ForegroundColor Yellow
        }
        return
    }

    # ── Static read mode ───────────────────────────────────────────────────
    $isSingle = ($logFiles.Count -eq 1)

    foreach ($f in $logFiles) {
        if (-not $isSingle) {
            Write-Host "`n=== $($f.Name) ===" -ForegroundColor Cyan
        }

        $lines = Get-Content $f.FullName -Tail $Last -ErrorAction SilentlyContinue
        $filtered = Select-FilteredLines $lines $Filter

        if ($filtered.Count -eq 0 -and $Filter -ne "") {
            Write-Host "  (no matches for '$Filter')" -ForegroundColor DarkGray
        } else {
            foreach ($line in $filtered) { Write-LogLine $line }
        }
    }
}

# ─────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Get-ClaudeConfig',
    'Edit-ClaudeConfig',
    'Show-ClaudeConfig',
    'Backup-ClaudeConfig',
    'Restore-ClaudeConfig',
    'Get-ClaudeLogs'
)
