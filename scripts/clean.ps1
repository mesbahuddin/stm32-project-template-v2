#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clean build artifacts

.DESCRIPTION
    Removes build directory and temporary files

.PARAMETER All
    Also remove configuration file (full clean)

.EXAMPLE
    .\clean.ps1
    Clean build directory only

.EXAMPLE
    .\clean.ps1 -All
    Full clean including configuration
#>

param(
    [switch]$All
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  STM32 Clean" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Load config if it exists to get build dir
$configFile = Join-Path $scriptDir "build_config.ps1"
if (Test-Path $configFile) {
    . $configFile
    $buildDir = $BUILD_DIR
} else {
    # Default build directories
    $buildDirs = @(
        (Join-Path $projectDir "build"),
        (Join-Path $projectDir "build\Debug"),
        (Join-Path $projectDir "build\Release"),
        (Join-Path $projectDir "cmake-build-debug"),
        (Join-Path $projectDir "cmake-build-release"),
        (Join-Path $projectDir "Debug"),
        (Join-Path $projectDir "Release")
    )
}

# Find and remove build directories
$cleaned = 0
$dirsToCheck = if ($buildDir) { @($buildDir) } else { $buildDirs }

foreach ($dir in $dirsToCheck) {
    if (Test-Path $dir) {
        Write-Host "Removing: $dir" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $dir
        $cleaned++
    }
}

if ($cleaned -eq 0) {
    Write-Host "No build directories found." -ForegroundColor Gray
} else {
    Write-Host "Removed $cleaned build directorie(s)." -ForegroundColor Green
}

Write-Host ""

# Clean configuration if requested
if ($All) {
    if (Test-Path $configFile) {
        Write-Host "Removing configuration: $configFile" -ForegroundColor Yellow
        Remove-Item -Force $configFile
        Write-Host "Configuration removed." -ForegroundColor Green
    } else {
        Write-Host "No configuration file found." -ForegroundColor Gray
    }
    Write-Host ""
}

# Summary
Write-Host "Clean complete!" -ForegroundColor Green
Write-Host ""

if (-not $All) {
    Write-Host "Tip: Use -All to also remove configuration file" -ForegroundColor Gray
    Write-Host "  .\clean.ps1 -All" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "To reconfigure:" -ForegroundColor Cyan
Write-Host "  .\config.ps1 -BuildType Debug" -ForegroundColor White
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
