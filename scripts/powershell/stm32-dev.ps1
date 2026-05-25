#!/usr/bin/env pwsh
<#
.SYNOPSIS
    STM32 Firmware Development Tool - Master script with menu interface

.DESCRIPTION
    Provides a menu-driven interface for all STM32 development tasks:
    - Configure build settings and flash interface
    - Compile firmware
    - Flash to device
    - Monitor serial output
    - Clean build artifacts

    The flash interface (J-Link, ST-Link, DFU) is stored in build_config.ps1
    and reused by all scripts until changed.

.EXAMPLE
    .\stm32-dev.ps1
    Launch interactive menu

.EXAMPLE
    .\stm32-dev.ps1 -Command build
    Run specific command directly
#>

param(
    [ValidateSet("", "config", "build", "flash", "flash_monitor", "clean", "all")]
    [string]$Command = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "    STM32 Development Tool" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan; Write-Host ""

    $configFile = Join-Path $scriptDir "build_config.ps1"
    if (Test-Path $configFile) {
        . $configFile
        Write-Host "Current Config:" -ForegroundColor Yellow
        Write-Host "  Build:    $BUILD_TYPE" -ForegroundColor White
        $c = if ($FLASH_INTERFACE -eq "JLink") { "Green" } elseif ($FLASH_INTERFACE -eq "STLink") { "Cyan" } else { "Yellow" }
        Write-Host "  Flashing: $FLASH_INTERFACE" -ForegroundColor $c; Write-Host ""
    } else {
        Write-Host "Status: Not configured" -ForegroundColor Yellow
        Write-Host "Run option 1 to configure" -ForegroundColor Gray; Write-Host ""
    }

    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "  1. Configure       - Set build type and flash interface" -ForegroundColor White
    Write-Host "  2. Build           - Compile firmware" -ForegroundColor White
    Write-Host "  3. Flash           - Program device (uses configured interface)" -ForegroundColor White
    Write-Host "  4. Flash+Monitor   - Flash and view serial output" -ForegroundColor White
    Write-Host "  5. Clean           - Remove build files" -ForegroundColor White
    Write-Host "  6. All (B+F)       - Build and Flash" -ForegroundColor White
    Write-Host "  7. All (B+F+M)     - Build, Flash, and Monitor" -ForegroundColor White; Write-Host ""
    Write-Host "  I. Change Interface - Switch flash interface (J-Link/ST-Link/DFU)" -ForegroundColor White; Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor Gray; Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
}

function Invoke-Command-Safe {
    param([string]$Script, [hashtable]$Arguments = @{})
    $scriptPath = Join-Path $scriptDir $Script
    if (-not (Test-Path $scriptPath)) { Write-Host "ERROR: Script not found: $Script" -ForegroundColor Red; return $false }
    & $scriptPath @Arguments
    return $?
}

function Set-FlashInterface {
    Clear-Host
    Write-Host "=== Flash Interface Configuration ===" -ForegroundColor Cyan; Write-Host ""
    $configFile = Join-Path $scriptDir "build_config.ps1"
    $currentInterface = "JLink"; $currentBuildType = "Debug"
    if (Test-Path $configFile) { . $configFile; $currentInterface = $FLASH_INTERFACE; $currentBuildType = $BUILD_TYPE }
    Write-Host "Current interface: $currentInterface" -ForegroundColor Yellow; Write-Host ""
    Write-Host "Select interface:" -ForegroundColor Green
    Write-Host "  1. J-Link  (Segger, high-speed SWD)" -ForegroundColor White
    Write-Host "  2. ST-Link (ST-Link/VCP via STM32CubeProgrammer)" -ForegroundColor White
    Write-Host "  3. DFU     (USB Device Firmware Update)" -ForegroundColor White; Write-Host ""
    $choice = Read-Host "Choice (1/2/3)"
    $interface = switch ($choice) { "1" { "JLink" } "2" { "STLink" } "3" { "DFU" } default { $currentInterface } }
    if ($interface -ne $currentInterface) {
        Invoke-Command-Safe "config.ps1" -Arguments @{ BuildType = $currentBuildType; FlashInterface = $interface }
        Write-Host ""; Write-Host "Interface changed to $interface" -ForegroundColor Green
    } else { Write-Host ""; Write-Host "Interface unchanged ($interface)" -ForegroundColor Gray }
    Write-Host ""; Read-Host "Press Enter to continue"
}

# Direct command execution
if ($Command) {
    switch ($Command) {
        "config" { Invoke-Command-Safe "config.ps1" }
        "build" { Invoke-Command-Safe "build.ps1" }
        "flash" { Invoke-Command-Safe "flash.ps1" }
        "flash_monitor" { Invoke-Command-Safe "flash_monitor.ps1" }
        "clean" { Invoke-Command-Safe "clean.ps1" }
        "all" { if (Invoke-Command-Safe "build.ps1") { Invoke-Command-Safe "flash.ps1" } }
    }
    exit
}

# Interactive menu
while ($true) {
    Show-Menu
    $choice = Read-Host "Enter choice"
    switch ($choice) {
        "1" {
            Clear-Host; Write-Host "=== Configuration ===" -ForegroundColor Cyan; Write-Host ""
            Write-Host "Select Build Type:" -ForegroundColor Yellow
            Write-Host "  D = Debug (with symbols)" -ForegroundColor White
            Write-Host "  R = Release (optimized, LTO)" -ForegroundColor White
            Write-Host "  M = MinSizeRel (size-optimized, LTO)" -ForegroundColor White; Write-Host ""
            $type = Read-Host "Type (D/R/M, default: D)"
            $buildType = switch ($type) { "R" { "Release" } "M" { "MinSizeRel" } default { "Debug" } }
            $configFile = Join-Path $scriptDir "build_config.ps1"
            $currentInterface = "JLink"
            if (Test-Path $configFile) { . $configFile; $currentInterface = $FLASH_INTERFACE }
            Invoke-Command-Safe "config.ps1" -Arguments @{ BuildType = $buildType; FlashInterface = $currentInterface }
            Write-Host ""; Read-Host "Press Enter to continue"
        }
        "2" { Invoke-Command-Safe "build.ps1"; Write-Host ""; Read-Host "Press Enter to continue" }
        "3" { Invoke-Command-Safe "flash.ps1"; Write-Host ""; Read-Host "Press Enter to continue" }
        "4" { Invoke-Command-Safe "flash_monitor.ps1"; Write-Host ""; Read-Host "Press Enter to continue" }
        "5" {
            Write-Host ""; $full = Read-Host "Clean configuration too? (y/N)"
            if ($full -eq "y" -or $full -eq "Y") { Invoke-Command-Safe "clean.ps1" -Arguments @{ All = $true } }
            else { Invoke-Command-Safe "clean.ps1" }
            Write-Host ""; Read-Host "Press Enter to continue"
        }
        "6" {
            if (Invoke-Command-Safe "build.ps1") {
                Write-Host ""; Read-Host "Build complete. Press Enter to flash"
                Invoke-Command-Safe "flash.ps1"
            }
            Write-Host ""; Read-Host "Press Enter to continue"
        }
        "7" {
            if (Invoke-Command-Safe "build.ps1") {
                Write-Host ""; Read-Host "Build complete. Press Enter to flash"
                Invoke-Command-Safe "flash.ps1"
                Write-Host ""; Read-Host "Flash complete. Press Enter to monitor"
                Invoke-Command-Safe "flash_monitor.ps1"
            }
            Write-Host ""; Read-Host "Press Enter to continue"
        }
        "I" { Set-FlashInterface }; "i" { Set-FlashInterface }
        "Q" { exit }; "q" { exit }
        default { Write-Host "Invalid choice" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
