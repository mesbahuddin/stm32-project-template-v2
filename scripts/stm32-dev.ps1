#!/usr/bin/env pwsh
<#
.SYNOPSIS
    STM32 Firmware Development Tool - Master script with menu interface

.DESCRIPTION
    Provides a menu-driven interface for all STM32 development tasks:
    - Configure build settings
    - Compile firmware
    - Flash to device
    - Monitor serial output
    - Clean build artifacts

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
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Load current config if exists
    $configFile = Join-Path $scriptDir "build_config.ps1"
    if (Test-Path $configFile) {
        . $configFile
        Write-Host "Current Config:" -ForegroundColor Yellow
        Write-Host "  Build: $BUILD_TYPE" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "Status: Not configured" -ForegroundColor Yellow
        Write-Host "Run option 1 to configure" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "  1. Configure    - Set build options (Debug/Release)" -ForegroundColor White
    Write-Host "  2. Build        - Compile firmware" -ForegroundColor White
    Write-Host "  3. Flash        - Program device (J-Link)" -ForegroundColor White
    Write-Host "  4. Flash+Monitor - Flash and view serial output" -ForegroundColor White
    Write-Host "  5. Clean        - Remove build files" -ForegroundColor White
    Write-Host "  6. All (B+F)    - Build and Flash" -ForegroundColor White
    Write-Host "  7. All (B+F+M)  - Build, Flash, and Monitor" -ForegroundColor White
    Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
}

function Invoke-Command-Safe {
    param([string]$Script, [hashtable]$Arguments = @{})
    
    $scriptPath = Join-Path $scriptDir $Script
    if (-not (Test-Path $scriptPath)) {
        Write-Host "ERROR: Script not found: $Script" -ForegroundColor Red
        return $false
    }
    
    & $scriptPath @Arguments
    return $?
}

# Main menu loop
if ($Command) {
    # Direct command execution
    switch ($Command) {
        "config" { Invoke-Command-Safe "config.ps1" }
        "build" { Invoke-Command-Safe "build.ps1" }
        "flash" { Invoke-Command-Safe "flash.ps1" }
        "flash_monitor" { Invoke-Command-Safe "flash_monitor.ps1" }
        "clean" { Invoke-Command-Safe "clean.ps1" }
        "all" { 
            if (Invoke-Command-Safe "build.ps1") {
                Invoke-Command-Safe "flash.ps1"
            }
        }
    }
    exit
}

# Interactive menu
while ($true) {
    Show-Menu
    
    $choice = Read-Host "Enter choice"
    
    switch ($choice) {
        "1" { 
            Clear-Host
            Write-Host "=== Configuration ===" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Select Build Type:" -ForegroundColor Yellow
            Write-Host "  D = Debug (with symbols, no optimization)" -ForegroundColor White
            Write-Host "  R = Release (optimized)" -ForegroundColor White
            Write-Host ""
            $type = Read-Host "Type (D/R, default: D)"
            $buildType = if ($type -eq "R") { "Release" } else { "Debug" }
            
            Invoke-Command-Safe "config.ps1" -Arguments @{ BuildType = $buildType }
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "2" { 
            Invoke-Command-Safe "build.ps1"
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "3" { 
            Write-Host ""
            Write-Host "Select flash interface:" -ForegroundColor Yellow
            Write-Host "  1. J-Link (default)" -ForegroundColor White
            Write-Host "  2. ST-Link" -ForegroundColor White
            Write-Host "  3. DFU" -ForegroundColor White
            Write-Host ""
            $interfaceChoice = Read-Host "Choice (1/2/3)"
            $interface = switch ($interfaceChoice) {
                "1" { "JLink" }
                "2" { "STLink" }
                "3" { "DFU" }
                default { "JLink" }
            }
            Invoke-Command-Safe "flash.ps1" -Arguments @{ Interface = $interface }
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "4" { 
            Invoke-Command-Safe "flash_monitor.ps1"
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "5" { 
            Write-Host ""
            $full = Read-Host "Clean configuration too? (y/N)"
            if ($full -eq "y" -or $full -eq "Y") {
                Invoke-Command-Safe "clean.ps1" -Arguments @{ All = $true }
            } else {
                Invoke-Command-Safe "clean.ps1"
            }
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "6" { 
            # Build + Flash
            if (Invoke-Command-Safe "build.ps1") {
                Write-Host ""
                Read-Host "Build complete. Press Enter to flash"
                Invoke-Command-Safe "flash.ps1"
            }
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "7" { 
            # Build + Flash + Monitor
            if (Invoke-Command-Safe "build.ps1") {
                Write-Host ""
                Read-Host "Build complete. Press Enter to flash"
                if (Invoke-Command-Safe "flash.ps1") {
                    Write-Host ""
                    Read-Host "Flash complete. Press Enter to monitor"
                    Invoke-Command-Safe "flash_monitor.ps1"
                }
            }
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
        
        "Q" { exit }
        "q" { exit }
        default { 
            Write-Host "Invalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
