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
    
    [string]$Device = "",
    
    [switch]$Verify,
    
    [switch]$Reset = $true
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

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
$searchedPaths = @()
if (-not $File) {
    $buildTypeDir = Join-Path (Join-Path $projectDir "build") $buildType
    if (Test-Path $buildTypeDir) {
        $elf = Get-ChildItem -Path $buildTypeDir -Filter "*.elf" -File | Select-Object -First 1
        $hex = Get-ChildItem -Path $buildTypeDir -Filter "*.hex" -File | Select-Object -First 1
        $bin = Get-ChildItem -Path $buildTypeDir -Filter "*.bin" -File | Select-Object -First 1
        
        # Priority: hex, then bin, then elf
        if ($hex) { $File = $hex.FullName }
        elseif ($bin) { $File = $bin.FullName }
        elseif ($elf) { $File = $elf.FullName }
    }
    
    # Fallback to search paths if not found dynamically
    if (-not $File) {
        $projectName = Split-Path $projectDir -Leaf
        $searchedPaths = @(
            "$projectDir\build\$buildType\$projectName.hex",
            "$projectDir\build\$buildType\$projectName.bin",
            "$projectDir\build\$buildType\stm32-project-template-v2.hex",
            "$projectDir\build\$buildType\stm32-project-template-v2.bin",
            "$projectDir\build\Debug\stm32-project-template-v2.hex",
            "$projectDir\build\Release\stm32-project-template-v2.hex"
        )
        
        foreach ($path in $searchedPaths) {
            if (Test-Path $path) {
                $File = $path
                break
            }
        }
    }
}

# Check if firmware file exists
if (-not $File -or -not (Test-Path $File)) {
    Write-Host "ERROR: Firmware file not found!" -ForegroundColor Red
    Write-Host ""
    if ($searchedPaths.Count -gt 0) {
        Write-Host "Searched paths:" -ForegroundColor Yellow
        foreach ($path in $searchedPaths) {
            Write-Host "  $path" -ForegroundColor Gray
        }
    } else {
        Write-Host "Build type directory '$buildTypeDir' searched but no binary (.hex, .bin, .elf) found." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Please build first or specify file:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1" -ForegroundColor White
    Write-Host "  .\flash.ps1 -File C:\path\to\firmware.hex" -ForegroundColor White
    exit 1
}

# Auto-detect MCU device from .ioc if not specified
if (-not $Device) {
    $iocFile = Get-ChildItem -Path $projectDir -Filter "*.ioc" -File | Select-Object -First 1
    if ($iocFile) {
        $iocContent = Get-Content $iocFile.FullName
        foreach ($line in $iocContent) {
            if ($line -match "Mcu\.CPN\s*=\s*([a-zA-Z0-9]+)") {
                $rawCpn = $Matches[1]
                # Segger J-Link generic compatibility, e.g. STM32F407VGT6 -> STM32F407xx
                if ($rawCpn -match "^(STM32[a-zA-Z0-9]{5})") {
                    $Device = $Matches[1] + "xx"
                } else {
                    $Device = $rawCpn
                }
                break
            }
        }
    }
}
if (-not $Device) {
    # Fallback to template default
    $Device = "STM32L496xx"
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

# Locate STM32CubeProgrammer CLI robustly on Windows
function Find-CubeProgrammer {
    # 1. Check if it's already in the PATH
    $cmd = Get-Command "STM32_Programmer_CLI.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    
    # 2. Check in C:\ST for versioned STM32CubeCLT paths (e.g. C:\ST\STM32CubeCLT_1.21.0\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe)
    if (Test-Path "C:\ST") {
        $cltPath = Get-ChildItem -Path "C:\ST" -Filter "STM32_Programmer_CLI.exe" -Recurse -File -ErrorAction SilentlyContinue | 
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($cltPath) {
            return $cltPath.FullName
        }
    }
    
    # 3. Check default installation directory in Program Files
    $defaultProgFiles = "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe"
    if (Test-Path $defaultProgFiles) {
        return $defaultProgFiles
    }
    
    # 4. Check Program Files (x86)
    $defaultProgFilesX86 = "C:\Program Files (x86)\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe"
    if (Test-Path $defaultProgFilesX86) {
        return $defaultProgFilesX86
    }
    
    return $null
}

# Flash based on interface
switch ($Interface) {
    "JLink" {
        Write-Host "Programming via J-Link..." -ForegroundColor Yellow
        Write-Host ""
        
        if (Test-Command "JLink.exe") {
            $device = $Device
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
        $cubeProgrammerPath = Find-CubeProgrammer
        
        if ($cubeProgrammerPath) {
            Write-Host "Using STM32CubeProgrammer at: $cubeProgrammerPath" -ForegroundColor Green
            $args = @("-c", "port=SWD", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            
            Write-Host "  Command: STM32_Programmer_CLI $([string]::Join(' ', $args))" -ForegroundColor Gray
            $result = Start-Process -FilePath $cubeProgrammerPath -ArgumentList $args -Wait -PassThru -NoNewWindow
            
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
        $cubeProgrammerPath = Find-CubeProgrammer
        
        if ($cubeProgrammerPath) {
            Write-Host "Using STM32CubeProgrammer (DFU) at: $cubeProgrammerPath" -ForegroundColor Green
            $args = @("-c", "port=USB1", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            
            Write-Host "  Command: STM32_Programmer_CLI $([string]::Join(' ', $args))" -ForegroundColor Gray
            $result = Start-Process -FilePath $cubeProgrammerPath -ArgumentList $args -Wait -PassThru -NoNewWindow
            
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
