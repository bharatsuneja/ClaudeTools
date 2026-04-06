#
# Module manifest for ClaudeTools
# https://github.com/bharatsuneja/ClaudeTools
#

@{
    ModuleVersion     = '1.2.0'
    GUID              = 'a3f7c2e1-4b89-4d12-9f3a-e2c1d8b45f67'
    Author            = 'Bharat Suneja / Vertiqle'
    CompanyName       = 'Bharat Suneja'
    Copyright         = '(c) Bharat Suneja. MIT License.'
    Description       = 'PowerShell tools for managing Claude Desktop configuration, MCP server logs, and backups.'
    PowerShellVersion = '5.1'
    RootModule        = 'ClaudeTools.psm1'

    FunctionsToExport = @(
        'Get-ClaudeConfig',
        'Edit-ClaudeConfig',
        'Show-ClaudeConfig',
        'Backup-ClaudeConfig',
        'Restore-ClaudeConfig',
        'Get-ClaudeLogs'
    )

    PrivateData = @{
        PSData = @{
            Tags       = @('Claude', 'Anthropic', 'ClaudeDesktop', 'MCP', 'Config', 'Backup', 'Logs')
            ProjectUri = 'https://github.com/bharatsuneja/ClaudeTools'
            LicenseUri = 'https://github.com/bharatsuneja/ClaudeTools/blob/main/LICENSE'
        }
    }
}
