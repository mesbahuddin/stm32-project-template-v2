#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build STM32 firmware using CMake presets

.DESCRIPTION
    Compiles the firmware using CMake presets (CMakePresets.json)
    Must run config.ps1 first to set up build configuration

.PARAMETER Clean
    Clean build directory before compiling

.PARAMETER Jobs
    Number of parallel jobs (default: auto)

.EXAMPLE
    .\build.ps1
    Build with current configuration

.EXAMPLE
    .\build.ps1 -Clean
    Clean and rebuild from scratch
#>

param(
    [switch]$Clean,
    [int]$Jobs = 0
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFile = Join-Path $scriptDir "build_config.ps1"

# Check if configuration exists
if (-not (Test-Path $configFile)) {
    Write-Host "ERROR: Build configuration not found!" -ForegroundColor Red
    Write-Host "Please run .\config.ps1 first to configure the build." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "  .\config.ps1 -BuildType Debug" -ForegroundColor White
    exit 1
}

# Load configuration
. $configFile

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "STM32 Firmware Build" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Build Type: $BUILD_TYPE" -ForegroundColor White
Write-Host "  Preset: $BUILD_TYPE" -ForegroundColor Gray
Write-Host "  Defines: $DEFINES" -ForegroundColor Gray
Write-Host ""

# Auto-detect number of jobs
if ($Jobs -eq 0) {
    $Jobs = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    if ($Jobs -eq 0) { $Jobs = 4 }
}

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    $buildDir = Join-Path (Join-Path $projectDir "build") $BUILD_TYPE
    if (Test-Path $buildDir) {
        Remove-Item -Recurse -Force $buildDir
        Write-Host "Build directory cleaned: $buildDir" -ForegroundColor Green
    } else {
        Write-Host "Build directory does not exist, nothing to clean." -ForegroundColor Gray
    }
    Write-Host ""
}

# Configure using preset
Write-Host "Configuring with CMake preset: $BUILD_TYPE" -ForegroundColor Yellow
Write-Host ""

$cmakeConfigArgs = @(
    "--preset", $BUILD_TYPE
)

Write-Host "  cmake $([string]::Join(' ', $cmakeConfigArgs))" -ForegroundColor Gray
Write-Host ""

# Store current directory and switch to project root
$originalDir = Get-Location
Set-Location $projectDir

$cmakeResult = Start-Process -FilePath "cmake" -ArgumentList $cmakeConfigArgs -Wait -PassThru -NoNewWindow

if ($cmakeResult.ExitCode -ne 0) {
    Write-Host ""
    Write-Host "ERROR: CMake configuration failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure ARM GCC is in PATH (arm-none-eabi-gcc)" -ForegroundColor White
    Write-Host "  2. Check that CMakePresets.json exists" -ForegroundColor White
    Write-Host "  3. Verify toolchain file: cmake/gcc-arm-none-eabi.cmake" -ForegroundColor White
    exit 1
}

Write-Host "Configuration complete." -ForegroundColor Green
Write-Host ""

# Build using preset - capture output for parsing
Write-Host "Building with $Jobs parallel jobs..." -ForegroundColor Yellow
Write-Host ""

$cmakeBuildArgs = @(
    "--build", "--preset", $BUILD_TYPE
    "--parallel", $Jobs
)

Write-Host "  cmake $([string]::Join(' ', $cmakeBuildArgs))" -ForegroundColor Gray
Write-Host ""

# Run build and capture output (from project directory)
$buildOutput = & cmake $cmakeBuildArgs 2>&1
$buildExitCode = $LASTEXITCODE

# Switch back to original directory
Set-Location $originalDir

# Parse and display build output with color coding
$errorCount = 0
$warningCount = 0
$memoryStats = @()
$inWarningsSection = $false

foreach ($line in $buildOutput) {
    # Check for memory usage stats
    if ($line -match "^(RAM|CCMRAM|FLASH):\s+(\d+)\s+B\s+(\d+)\s+(KB|MB)\s+([\d.]+)%") {
        $memoryStats += $line
        Write-Host $line -ForegroundColor Cyan
        continue
    }
    
    # Check for size stats (text, data, bss, dec, hex)
    if ($line -match "^\s*\d+\s+\d+\s+\d+\s+\d+\s+[0-9a-f]+\s+") {
        Write-Host $line -ForegroundColor Cyan
        continue
    }
    
    # Check for errors
    if ($line -match "error:|undefined reference|FAILED:" -and $line -notmatch "0 error") {
        $errorCount++
        Write-Host $line -ForegroundColor Red
        continue
    }
    
    # Check for warnings
    if ($line -match "warning:") {
        $warningCount++
        Write-Host $line -ForegroundColor Yellow
        continue
    }
    
    # Progress indicators [XX/YY]
    if ($line -match "^\[\d+/\d+\]") {
        # Show compilation progress
        if ($line -match "Building C object") {
            $fileName = $line -replace ".*Building C object.*\/([^\/]+\.c\.obj).*", '$1'
            Write-Host "  $line" -ForegroundColor DarkGray -NoNewline
            Write-Host "`r" -NoNewline
        }
        elseif ($line -match "Linking") {
            Write-Host "  $line" -ForegroundColor Green
        }
        else {
            Write-Host "  $line" -ForegroundColor DarkGray
        }
        continue
    }
    
    # Default output
    Write-Host $line
}

# Clear the last progress line if needed
Write-Host ""

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "======================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Errors: $errorCount" -ForegroundColor Red
    Write-Host "  Warnings: $warningCount" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check output above for details." -ForegroundColor Yellow
    exit 1
}

# Check for output file
$buildTypeDir = Join-Path (Join-Path $projectDir "build") $BUILD_TYPE
$elfFile = Get-ChildItem -Path $buildTypeDir -Filter "*.elf" -File | Select-Object -First 1 | ForEach-Object { $_.FullName }
$hexFile = Get-ChildItem -Path $buildTypeDir -Filter "*.hex" -File | Select-Object -First 1 | ForEach-Object { $_.FullName }
$binFile = Get-ChildItem -Path $buildTypeDir -Filter "*.bin" -File | Select-Object -First 1 | ForEach-Object { $_.FullName }

if (-not $elfFile) {
    $projectName = Split-Path $projectDir -Leaf
    $elfFile = Join-Path $buildTypeDir "$projectName.elf"
    $hexFile = Join-Path $buildTypeDir "$projectName.hex"
    $binFile = Join-Path $buildTypeDir "$projectName.bin"
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""

# Parse Flash/RAM usage from arm-none-eabi-size output
# Format: text    data     bss     dec     hex    filename
$flashTotal = 0
$ramTotal = 0
$flashKB = 0
$ramKB = 0
$flashPercent = 0
$ramPercent = 0
$flashRemainingKB = 0
$ramRemainingKB = 0

# Default fallbacks
$flashTotalKB = 2048   # 2 MB Flash
$ramTotalKB = 320      # 320 KB RAM

# Search for the linker script to dynamically extract memory sizes
$ldFile = Get-ChildItem -Path $projectDir -Filter "*_flash.ld" -File -Recurse | Select-Object -First 1
if ($ldFile) {
    $ldContent = Get-Content $ldFile.FullName
    foreach ($line in $ldContent) {
        if ($line -match "\bFLASH\b\s*\(\w+\)\s*:\s*ORIGIN\s*=\s*\w+,\s*LENGTH\s*=\s*(\d+)\s*([KM])") {
            $val = [int]$Matches[1]
            $unit = $Matches[2].ToUpper()
            $flashTotalKB = if ($unit -eq "M") { $val * 1024 } else { $val }
        }
        if ($line -match "\bRAM\b\s*\(\w+\)\s*:\s*ORIGIN\s*=\s*\w+,\s*LENGTH\s*=\s*(\d+)\s*([KM])") {
            $val = [int]$Matches[1]
            $unit = $Matches[2].ToUpper()
            $ramTotalKB = if ($unit -eq "M") { $val * 1024 } else { $val }
        }
    }
}

foreach ($line in $buildOutput) {
    if ($line -match '^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([0-9a-f]+)\s+([\w.-]+)') {
        $text = [int]$Matches[1]   # code (flash)
        $data = [int]$Matches[2]   # initialized data (flash + RAM)
        $bss  = [int]$Matches[3]   # zero-initialized data (RAM)
        $dec  = [int]$Matches[4]
        $hex  = $Matches[5]
        $file = $Matches[6]
        
        $flashTotal = $text + $data  # total flash (code + initialized data)
        $ramTotal   = $data + $bss   # total RAM (initialized + zero-initialized)
        $flashKB = [math]::Round($flashTotal / 1024, 2)
        $ramKB   = [math]::Round($ramTotal / 1024, 2)
        $flashPercent = [math]::Round(($flashTotal / ($flashTotalKB * 1024)) * 100, 1)
        $ramPercent   = [math]::Round(($ramTotal / ($ramTotalKB * 1024)) * 100, 1)
        $flashRemainingKB = [math]::Round(($flashTotalKB * 1024 - $flashTotal) / 1024, 2)
        $ramRemainingKB   = [math]::Round(($ramTotalKB * 1024 - $ramTotal) / 1024, 2)
        
        # Also update elfFile if it was found by size
        if ($file -match '\.elf$') {
            $elfFile = Join-Path $buildTypeDir $file
        }
    }
}

# Fallback: if project was already built (no compilation output), directly run arm-none-eabi-size to get sizes
if ($flashTotal -eq 0 -and (Test-Path $elfFile)) {
    $sizeCmd = "arm-none-eabi-size"
    $null = Get-Command $sizeCmd -ErrorAction SilentlyContinue
    if ($?) {
        $sizeOutput = & $sizeCmd $elfFile 2>&1
        foreach ($line in $sizeOutput) {
            if ($line -match '^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([0-9a-f]+)\s+([\w.-]+)') {
                $text = [int]$Matches[1]
                $data = [int]$Matches[2]
                $bss  = [int]$Matches[3]
                
                $flashTotal = $text + $data
                $ramTotal   = $data + $bss
                $flashKB = [math]::Round($flashTotal / 1024, 2)
                $ramKB   = [math]::Round($ramTotal / 1024, 2)
                $flashPercent = [math]::Round(($flashTotal / ($flashTotalKB * 1024)) * 100, 1)
                $ramPercent   = [math]::Round(($ramTotal / ($ramTotalKB * 1024)) * 100, 1)
                $flashRemainingKB = [math]::Round(($flashTotalKB * 1024 - $flashTotal) / 1024, 2)
                $ramRemainingKB   = [math]::Round(($ramTotalKB * 1024 - $ramTotal) / 1024, 2)
            }
        }
    }
}

if ($flashTotal -gt 0 -or $ramTotal -gt 0) {
    # Color coding for percentages
    $flashColor = if ($flashPercent -gt 90) { "Red" } elseif ($flashPercent -gt 70) { "Yellow" } else { "Green" }
    $ramColor   = if ($ramPercent -gt 90)   { "Red"   } elseif ($ramPercent -gt 70)   { "Yellow" } else { "Green" }
    
    Write-Host "Flash/RAM Usage:" -ForegroundColor Cyan
    Write-Host "  Flash: $flashKB KB / $flashTotalKB KB ($flashPercent%)" -ForegroundColor $flashColor
    Write-Host "    Code (text): $([math]::Round($text / 1024, 2)) KB" -ForegroundColor DarkGray
    Write-Host "    Data (data): $([math]::Round($data / 1024, 2)) KB" -ForegroundColor DarkGray
    Write-Host "    Free:        $flashRemainingKB KB remaining" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  RAM:   $ramKB KB / $ramTotalKB KB ($ramPercent%)" -ForegroundColor $ramColor
    Write-Host "    Data (data): $([math]::Round($data / 1024, 2)) KB" -ForegroundColor DarkGray
    Write-Host "    BSS (zero):  $([math]::Round($bss / 1024, 2)) KB" -ForegroundColor DarkGray
    Write-Host "    Free:        $ramRemainingKB KB remaining" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host ""
}

Write-Host "Output files:" -ForegroundColor Yellow
if (Test-Path $elfFile) {
    $size = (Get-Item $elfFile).Length
    $sizeKB = [math]::Round($size / 1024, 2)
    Write-Host "  ELF: $elfFile ($sizeKB KB)" -ForegroundColor White
}
if (Test-Path $hexFile) {
    $size = (Get-Item $hexFile).Length
    $sizeKB = [math]::Round($size / 1024, 2)
    Write-Host "  HEX: $hexFile ($sizeKB KB)" -ForegroundColor White
}
if (Test-Path $binFile) {
    $size = (Get-Item $binFile).Length
    $sizeKB = [math]::Round($size / 1024, 2)
    Write-Host "  BIN: $binFile ($sizeKB KB)" -ForegroundColor White
}

Write-Host ""
Write-Host "Build Summary:" -ForegroundColor Yellow
Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { "Yellow" } else { "Green" })

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  .\flash.ps1    - Flash to device" -ForegroundColor White
Write-Host "  .\monitor.ps1  - Monitor serial output" -ForegroundColor White
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
