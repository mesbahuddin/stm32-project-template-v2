#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure build settings for STM32 firmware

.DESCRIPTION
    Sets up build configuration and creates a build_config.ps1 file that other scripts source

.PARAMETER BuildType
    Build type: Debug or Release

.PARAMETER Defines
    Additional compiler defines (comma-separated, no spaces)

.EXAMPLE
    .\config.ps1 -BuildType Debug
    Configure for debug build

.EXAMPLE
    .\config.ps1 -BuildType Release -Defines "USE_HAL_DRIVER,STM32L496xx"
    Configure for release build with defines
#>

param(
    [ValidateSet("Debug", "Release")]
    [string]$BuildType = "Debug",
    
    [string]$Defines = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFile = Join-Path $scriptDir "build_config.ps1"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  STM32 Build Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Create configuration
$config = @"
# STM32 Build Configuration
# Generated: $(Get-Date)
# Do not edit manually - run config.ps1 instead

`$global:BUILD_TYPE = "$BuildType"
`$global:PROJECT_DIR = "$projectDir"
`$global:BUILD_DIR = "`$PROJECT_DIR\build\`$BUILD_TYPE"
`$global:DEFINES = "$Defines"

Write-Host "Loaded configuration: Build Type `$BUILD_TYPE" -ForegroundColor Green
"@

# Save configuration
$config | Out-File -FilePath $configFile -Encoding UTF8

Write-Host "Configuration saved to: $configFile" -ForegroundColor Green
Write-Host ""
Write-Host "Settings:" -ForegroundColor Yellow
Write-Host "  Build Type: $BuildType" -ForegroundColor White
Write-Host "  Defines: $Defines" -ForegroundColor White
Write-Host "  Project Directory: $projectDir" -ForegroundColor Gray
Write-Host ""

# Next steps
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. Run .\build.ps1 to compile" -ForegroundColor White
Write-Host "  2. Run .\flash.ps1 to program device" -ForegroundColor White
Write-Host "  3. Run .\monitor.ps1 to view serial output" -ForegroundColor White
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
