#requires -Version 5.1
<#
.SYNOPSIS
    Flash firmware and monitor serial output.

.DESCRIPTION
    Combines flash and monitor operations: flashes the firmware to the device,
    then automatically starts monitoring the serial port.

.PARAMETER Port
    COM port for the STM32 CDC device (e.g., COM8). Auto-detects if not specified.

.PARAMETER BaudRate
    Baud rate for serial communication (default: 115200).

.PARAMETER Timestamp
    Include timestamps in output.

.PARAMETER LogFile
    Optional log file path to save output.

.PARAMETER FlashMethod
    Flash method: jlink (default), stlink, or dfu.

.EXAMPLE
    .\flash_monitor.ps1
    # Auto-detects COM port, flashes, and monitors

.EXAMPLE
    .\flash_monitor.ps1 -Port COM8
    # Uses COM8, flashes, and monitors

.EXAMPLE
    .\flash_monitor.ps1 -Port COM8 -Timestamp -LogFile test.log
    # Flash and monitor with timestamps and logging
#>

[CmdletBinding()]
param(
    [string]$Port,
    [int]$BaudRate = 115200,
    [switch]$Timestamp,
    [string]$LogFile,
    [ValidateSet("jlink", "stlink", "dfu")]
    [string]$FlashMethod = "jlink"
)

$ErrorActionPreference = "Stop"

# Color definitions
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Cyan = "Cyan"
$Gray = "DarkGray"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "========================================" -ForegroundColor $Cyan
Write-Host "  STM32 Flash + Monitor" -ForegroundColor $Cyan
Write-Host "========================================" -ForegroundColor $Cyan
Write-Host ""

# Step 1: Flash the firmware
Write-Host "Step 1: Flashing firmware..." -ForegroundColor $Yellow
Write-Host "----------------------------------------" -ForegroundColor $Gray

try {
    $FlashArgs = @{ Method = $FlashMethod }
    & "$ScriptDir\flash.ps1" @FlashArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Flash operation failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "ERROR: Flash failed - $_" -ForegroundColor $Red
    exit 1
}

Write-Host ""
Write-Host "Flash completed successfully!" -ForegroundColor $Green
Write-Host ""

# Step 2: Small delay to allow device to reset and enumerate
Write-Host "Waiting for device to enumerate..." -ForegroundColor $Yellow
Start-Sleep -Seconds 2

# Step 3: Auto-detect COM port if not specified
if (-not $Port) {
    Write-Host "Auto-detecting COM port..." -ForegroundColor $Yellow
    
    $comPorts = Get-PnpDevice -Class "Ports" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Status -eq "OK" } |
        ForEach-Object {
            $match = $_.FriendlyName | Select-String -Pattern "\(COM(\d+)\)"
            if ($match) {
                $match.Matches.Groups[1].Value
            }
        }
    
    # Look for STM32 or USB Serial
    $stm32Port = Get-PnpDevice -Class "Ports" -ErrorAction SilentlyContinue | 
        Where-Object { $_.FriendlyName -match "STM32|USB Serial" -and $_.Status -eq "OK" } |
        Select-Object -First 1 |
        ForEach-Object {
            $match = $_.FriendlyName | Select-String -Pattern "\(COM(\d+)\)"
            if ($match) { "COM" + $match.Matches.Groups[1].Value }
        }
    
    if ($stm32Port) {
        $Port = $stm32Port
        Write-Host "Found STM32 device on $Port" -ForegroundColor $Green
    } elseif ($comPorts) {
        $Port = "COM" + ($comPorts | Select-Object -First 1)
        Write-Host "Using available port: $Port" -ForegroundColor $Yellow
    } else {
        Write-Host "ERROR: No COM ports found!" -ForegroundColor $Red
        Write-Host "Please specify port manually with -Port parameter" -ForegroundColor $Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Step 2: Starting monitor on $Port..." -ForegroundColor $Yellow
Write-Host "----------------------------------------" -ForegroundColor $Gray
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor $Gray
Write-Host ""

# Step 4: Start monitoring
$MonitorArgs = @{ Port = $Port; BaudRate = $BaudRate }
if ($Timestamp) { $MonitorArgs['Timestamp'] = $true }
if ($LogFile) { $MonitorArgs['LogFile'] = $LogFile }

try {
    & "$ScriptDir\monitor.ps1" @MonitorArgs
}
catch {
    Write-Host "ERROR: Monitor failed - $_" -ForegroundColor $Red
    exit 1
}
