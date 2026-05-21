#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor serial output from the STM32 device

.DESCRIPTION
    Connects to the STM32 virtual COM port and displays serial output
    Automatically detects the correct COM port by VID/PID

.PARAMETER Port
    COM port to use (auto-detect if not specified)

.PARAMETER BaudRate
    Baud rate (default: 115200)

.PARAMETER LogFile
    Log output to file

.PARAMETER Timestamp
    Add timestamps to output

.EXAMPLE
    .\monitor.ps1
    Auto-detect port and monitor

.EXAMPLE
    .\monitor.ps1 -Port COM3
    Monitor specific COM port

.EXAMPLE
    .\monitor.ps1 -LogFile output.log -Timestamp
    Monitor with logging and timestamps
#>

param(
    [string]$Port = "",
    [int]$BaudRate = 115200,
    [string]$LogFile = "",
    [switch]$Timestamp
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "STM32 Serial Monitor" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Auto-detect COM port if not specified
if (-not $Port) {
    Write-Host "Auto-detecting COM port..." -ForegroundColor Yellow
    
    # Get all COM ports
    $comPorts = Get-PnpDevice -Class Ports | Where-Object { $_.Name -like "*COM*" }
    
    # Look for STM32 Virtual COM Port
    $stm32Port = $comPorts | Where-Object { 
        $_.Name -like "*STM32*" -or 
        $_.Name -like "*Virtual COM*" -or
        $_.Name -like "*USB Serial*"
    } | Select-Object -First 1
    
    if ($stm32Port) {
        # Extract COM port number from name
        if ($stm32Port.Name -match "(COM\d+)") {
            $Port = $matches[1]
            Write-Host "Found: $($stm32Port.Name)" -ForegroundColor Green
        }
    }
    
    # If still not found, try WMI query for USB devices
    if (-not $Port) {
        try {
            $usbDevices = Get-WmiObject -Query "SELECT * FROM Win32_SerialPort" -ErrorAction SilentlyContinue
            $stm32Device = $usbDevices | Where-Object { 
                $_.Name -like "*STM32*" -or 
                $_.PNPDeviceID -like "*0483*"  # STMicroelectronics VID
            } | Select-Object -First 1
            
            if ($stm32Device) {
                $Port = $stm32Device.DeviceID
                Write-Host "Found: $($stm32Device.Name) on $Port" -ForegroundColor Green
            }
        }
        catch {
            # WMI not available, continue
        }
    }
    
    # List available ports if still not found
    if (-not $Port) {
        Write-Host "Could not auto-detect STM32 COM port." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available COM ports:" -ForegroundColor Cyan
        
        $availablePorts = [System.IO.Ports.SerialPort]::GetPortNames()
        foreach ($p in $availablePorts) {
            Write-Host "  - $p" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Please specify port manually:" -ForegroundColor Yellow
        Write-Host "  .\monitor.ps1 -Port COM3" -ForegroundColor White
        Write-Host ""
        
        # Try to get user input
        $userPort = Read-Host "Enter COM port (e.g., COM3) or press Enter to exit"
        if ($userPort) {
            $Port = $userPort
        } else {
            exit 1
        }
    }
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "  Baud Rate: $BaudRate" -ForegroundColor White
if ($LogFile) {
    Write-Host "  Log File: $LogFile" -ForegroundColor White
}
if ($Timestamp) {
    Write-Host "  Timestamps: Enabled" -ForegroundColor White
}
Write-Host ""

# Validate port
$availablePorts = [System.IO.Ports.SerialPort]::GetPortNames()
if ($Port -notin $availablePorts) {
    Write-Host "ERROR: Port $Port is not available!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available ports: $([string]::Join(', ', $availablePorts))" -ForegroundColor Yellow
    exit 1
}

# Open serial port
try {
    $serial = New-Object System.IO.Ports.SerialPort($Port, $BaudRate, "None", 8, "One")
    $serial.ReadTimeout = 1000
    $serial.WriteTimeout = 1000
    $serial.Open()
    
    Write-Host "Connected to $Port" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Gray
    Write-Host "--- START OF OUTPUT ---" -ForegroundColor DarkGray
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to open $Port" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Open log file if requested
$logStream = $null
if ($LogFile) {
    try {
        $logStream = [System.IO.StreamWriter]::new($LogFile, $true)
        $logStream.WriteLine("--- Log started: $(Get-Date) ---")
        $logStream.WriteLine("Port: $Port, Baud: $BaudRate")
        $logStream.WriteLine("")
    }
    catch {
        Write-Host "WARNING: Could not open log file: $_" -ForegroundColor Yellow
        $logStream = $null
    }
}

# Setup Ctrl+C handler
$running = $true
$ctrlCHandler = $null

try {
    $ctrlCHandler = {
        $script:running = $false
    }
    [Console]::CancelKeyPress.AddHandler($ctrlCHandler)
}
catch {
    # Console may not support CancelKeyPress in some environments
    Write-Host "Note: Ctrl+C handler not available in this environment" -ForegroundColor DarkGray
}

# Read loop
try {
    $buffer = ""
    
    while ($running) {
        try {
            # Check if serial port is still valid
            if (-not $serial -or -not $serial.IsOpen) {
                break
            }
            
            # Read available data
            while ($serial.BytesToRead -gt 0 -and $running) {
                $char = $serial.ReadChar()
                
                if ($char -eq 10) {  # LF
                    # End of line, process it
                    $line = $buffer
                    $buffer = ""
                    
                    # Add timestamp if requested
                    $output = if ($Timestamp) { 
                        "[$(Get-Date -Format 'HH:mm:ss.fff')] $line" 
                    } else { 
                        $line 
                    }
                    
                    # Color-code based on content
                    if ($line -match "TRIG") {
                        Write-Host $output -ForegroundColor Red
                    }
                    elseif ($line -match "INIT|READY|ACTIVE") {
                        Write-Host $output -ForegroundColor Green
                    }
                    elseif ($line -match "ERROR|FAIL|WARN") {
                        Write-Host $output -ForegroundColor Yellow
                    }
                    else {
                        Write-Host $output
                    }
                    
                    # Write to log
                    if ($logStream) {
                        $logStream.WriteLine($output)
                        $logStream.Flush()
                    }
                }
                elseif ($char -ne 13) {  # Skip CR
                    $buffer += [char]$char
                }
            }
        }
        catch [System.TimeoutException] {
            # Timeout is OK, just continue
        }
        catch {
            if ($running) {
                Write-Host "ERROR reading from port: $_" -ForegroundColor Red
            }
        }
        
        # Small delay to prevent CPU spinning
        Start-Sleep -Milliseconds 10
    }
}
finally {
    # Cleanup
    Write-Host ""
    Write-Host "--- END OF OUTPUT ---" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Closing connection..." -ForegroundColor Yellow
    
    if ($serial -and $serial.IsOpen) {
        $serial.Close()
        $serial.Dispose()
    }
    
    if ($logStream) {
        $logStream.WriteLine("--- Log ended: $(Get-Date) ---")
        $logStream.Close()
        $logStream.Dispose()
        Write-Host "Log saved to: $LogFile" -ForegroundColor Green
    }
    
    if ($ctrlCHandler) {
        try {
            [Console]::CancelKeyPress.RemoveHandler($ctrlCHandler)
        }
        catch {
            # Ignore cleanup errors
        }
    }
    
    Write-Host "Disconnected." -ForegroundColor Green
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
}
