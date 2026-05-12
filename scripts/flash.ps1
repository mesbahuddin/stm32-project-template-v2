#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Flash firmware to STM32 device

.DESCRIPTION
    Programs the compiled firmware to STM32 using various methods:
    - J-Link (preferred)
    - ST-Link (st-flash or STM32CubeProgrammer)
    - DFU (Device Firmware Update via USB)

.PARAMETER Interface
    Programming interface: JLink (default), STLink, or DFU

.PARAMETER File
    Firmware file to flash (auto-detected if not specified)

.PARAMETER Verify
    Verify flash after programming

.PARAMETER Reset
    Reset device after programming

.EXAMPLE
    .\flash.ps1
    Flash using J-Link with auto-detected firmware

.EXAMPLE
    .\flash.ps1 -Interface DFU
    Flash using USB DFU mode

.EXAMPLE
    .\flash.ps1 -File C:\path\to\firmware.hex
    Flash specific file
#>

param(
    [ValidateSet("JLink", "STLink", "DFU")]
    [string]$Interface = "JLink",
    
    [string]$File = "",
    
    [switch]$Verify,
    
    [switch]$Reset = $true
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  STM32 Flash Programming" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$configFile = Join-Path $scriptDir "build_config.ps1"
$buildType = "Debug"
if (Test-Path $configFile) {
    . $configFile
    Write-Host "Loaded configuration" -ForegroundColor Green
    $buildType = $BUILD_TYPE
} else {
    Write-Host "WARNING: No configuration found, using defaults" -ForegroundColor Yellow
    $BUILD_TYPE = "Debug"
}

# Auto-detect firmware file if not specified
if (-not $File) {
    $searchPaths = @(
        (Join-Path $projectDir "build" $buildType "stm32-project-template-v2.hex"),
        (Join-Path $projectDir "build" $buildType "stm32-project-template-v2.bin"),
        (Join-Path $projectDir "build\Debug\stm32-project-template-v2.hex"),
        (Join-Path $projectDir "build\Release\stm32-project-template-v2.hex"),
        (Join-Path $projectDir "Debug\stm32-project-template-v2.hex"),
        (Join-Path $projectDir "stm32-project-template-v2.hex")
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $File = $path
            break
        }
    }
}

# Check if firmware file exists
if (-not $File -or -not (Test-Path $File)) {
    Write-Host "ERROR: Firmware file not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Searched paths:" -ForegroundColor Yellow
    foreach ($path in $searchPaths) {
        Write-Host "  $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Please build first or specify file:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1" -ForegroundColor White
    Write-Host "  .\flash.ps1 -File C:\path\to\firmware.hex" -ForegroundColor White
    exit 1
}

Write-Host "Firmware file: $File" -ForegroundColor Green
Write-Host "Interface: $Interface" -ForegroundColor Green
Write-Host "Build Type: $buildType" -ForegroundColor Gray
Write-Host ""

# Check for required tools
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Flash based on interface
switch ($Interface) {
    "JLink" {
        Write-Host "Programming via J-Link..." -ForegroundColor Yellow
        Write-Host ""
        
        if (Test-Command "JLink.exe") {
            $device = "STM32L496xx"
            $speed = "4000"
            
            $jlinkScript = @"
device $device
si 1
speed $speed
connect
r
h
loadfile "$File"
$(if ($Verify) { "verify" })
$(if ($Reset) { "r" })
g
qc
"@
            
            $scriptFile = [System.IO.Path]::GetTempFileName()
            $jlinkScript | Out-File -FilePath $scriptFile -Encoding ASCII
            
            Write-Host "Using J-Link..." -ForegroundColor Green
            Write-Host "  Device: $device" -ForegroundColor Gray
            Write-Host "  Speed: $speed kHz" -ForegroundColor Gray
            
            $result = Start-Process -FilePath "JLink.exe" -ArgumentList "-CommanderScript", $scriptFile -Wait -PassThru -NoNewWindow
            
            Remove-Item $scriptFile
            
            if ($result.ExitCode -ne 0) {
                Write-Host ""
                Write-Host "ERROR: Programming failed!" -ForegroundColor Red
                exit 1
            }
        }
        else {
            Write-Host "ERROR: J-Link not found!" -ForegroundColor Red
            Write-Host "Please install J-Link software:" -ForegroundColor Yellow
            Write-Host "  https://www.segger.com/downloads/jlink/" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Or use ST-Link mode:" -ForegroundColor Yellow
            Write-Host "  .\flash.ps1 -Interface STLink" -ForegroundColor White
            exit 1
        }
    }
    
    "STLink" {
        Write-Host "Programming via ST-Link..." -ForegroundColor Yellow
        Write-Host ""
        
        # Try STM32CubeProgrammer first (CLI)
        $cubeProgrammer = Get-ChildItem -Path "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin" -Filter "STM32_Programmer_CLI.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($cubeProgrammer) {
            Write-Host "Using STM32CubeProgrammer..." -ForegroundColor Green
            $args = @("-c", "port=SWD", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            
            Write-Host "  Command: STM32_Programmer_CLI $([string]::Join(' ', $args))" -ForegroundColor Gray
            $result = Start-Process -FilePath $cubeProgrammer.FullName -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($result.ExitCode -ne 0) {
                Write-Host ""
                Write-Host "ERROR: Programming failed!" -ForegroundColor Red
                exit 1
            }
        }
        # Try st-flash (open source alternative)
        elseif (Test-Command "st-flash") {
            Write-Host "Using st-flash..." -ForegroundColor Green
            
            $ext = [System.IO.Path]::GetExtension($File).ToLower()
            if ($ext -eq ".hex") {
                # st-flash works better with bin files
                Write-Host "Converting HEX to BIN..." -ForegroundColor Yellow
                $binFile = [System.IO.Path]::ChangeExtension($File, ".bin")
                # Note: Would need hex2bin tool here
                Write-Host "WARNING: st-flash prefers BIN files. Please provide BIN or install STM32CubeProgrammer." -ForegroundColor Yellow
            }
            
            $args = @("write", $File, "0x8000000")
            Write-Host "  Command: st-flash $([string]::Join(' ', $args))" -ForegroundColor Gray
            $result = Start-Process -FilePath "st-flash" -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($result.ExitCode -ne 0) {
                Write-Host ""
                Write-Host "ERROR: Programming failed!" -ForegroundColor Red
                exit 1
            }
        }
        else {
            Write-Host "ERROR: No ST-Link tool found!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please install one of:" -ForegroundColor Yellow
            Write-Host "  - STM32CubeProgrammer (recommended)" -ForegroundColor White
            Write-Host "    https://www.st.com/en/development-tools/stm32cubeprog.html" -ForegroundColor Gray
            Write-Host "  - st-link tools (open source)" -ForegroundColor White
            Write-Host "    https://github.com/stlink-org/stlink" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Or use J-Link mode:" -ForegroundColor Yellow
            Write-Host "  .\flash.ps1 -Interface JLink" -ForegroundColor White
            exit 1
        }
    }
    
    "DFU" {
        Write-Host "Programming via USB DFU..." -ForegroundColor Yellow
        Write-Host ""
        
        # Check for DfuSe or STM32CubeProgrammer
        $dfuPath = "C:\Program Files (x86)\STMicroelectronics\Software\Flash Loader Demo\DfuSeCommand.exe"
        $cubeProgrammer = Get-ChildItem -Path "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin" -Filter "STM32_Programmer_CLI.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($cubeProgrammer) {
            Write-Host "Using STM32CubeProgrammer (DFU)..." -ForegroundColor Green
            $args = @("-c", "port=USB1", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            
            Write-Host "  Command: STM32_Programmer_CLI $([string]::Join(' ', $args))" -ForegroundColor Gray
            $result = Start-Process -FilePath $cubeProgrammer.FullName -ArgumentList $args -Wait -PassThru -NoNewWindow
            
            if ($result.ExitCode -ne 0) {
                Write-Host ""
                Write-Host "ERROR: Programming failed!" -ForegroundColor Red
                Write-Host "Make sure device is in DFU mode (hold BOOT0, press reset)" -ForegroundColor Yellow
                exit 1
            }
        }
        elseif (Test-Path $dfuPath) {
            Write-Host "Using DfuSeCommand..." -ForegroundColor Green
            Write-Host "WARNING: DfuSe requires special file format. STM32CubeProgrammer recommended." -ForegroundColor Yellow
            
            # Note: DfuSe requires .dfu files, not raw hex
            Write-Host ""
            Write-Host "Please use STM32CubeProgrammer for DFU:" -ForegroundColor Yellow
            Write-Host "  https://www.st.com/en/development-tools/stm32cubeprog.html" -ForegroundColor Gray
            exit 1
        }
        else {
            Write-Host "ERROR: No DFU tool found!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please install STM32CubeProgrammer:" -ForegroundColor Yellow
            Write-Host "  https://www.st.com/en/development-tools/stm32cubeprog.html" -ForegroundColor Gray
            Write-Host ""
            Write-Host "To enter DFU mode:" -ForegroundColor Yellow
            Write-Host "  1. Hold BOOT0 button" -ForegroundColor White
            Write-Host "  2. Press and release RESET" -ForegroundColor White
            Write-Host "  3. Release BOOT0" -ForegroundColor White
            Write-Host "  4. Run flash command" -ForegroundColor White
            exit 1
        }
    }
}

Write-Host ""
Write-Host "Programming completed successfully!" -ForegroundColor Green
Write-Host ""

if ($Reset) {
    Write-Host "Device has been reset and should be running." -ForegroundColor Green
} else {
    Write-Host "Reset device to start new firmware." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next step:" -ForegroundColor Green
Write-Host "  .\monitor.ps1  - Monitor serial output" -ForegroundColor White
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan

# Explicitly exit with success code
exit 0
