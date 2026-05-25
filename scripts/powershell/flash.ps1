#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Flash firmware to STM32 device

.DESCRIPTION
    Programs the compiled firmware to STM32 using various methods:
    - J-Link (preferred)
    - ST-Link (st-flash or STM32CubeProgrammer)
    - DFU (Device Firmware Update via USB)

    The programming interface is read from build_config.ps1 (set via config.ps1).
    The -Interface parameter overrides the saved config for one-off use.

    The MCU device is auto-detected from the .ioc file in the project root.

.PARAMETER Interface
    Override programming interface: JLink, STLink, or DFU. Uses config default if omitted.

.PARAMETER File
    Firmware file to flash (auto-detected if not specified)

.PARAMETER Device
    MCU device name (auto-detected from .ioc if not specified)

.PARAMETER Verify
    Verify flash after programming

.PARAMETER Reset
    Reset device after programming

.EXAMPLE
    .\flash.ps1
    Flash using configured interface with auto-detected firmware

.EXAMPLE
    .\flash.ps1 -Interface DFU
    Flash using USB DFU mode (one-time override)
#>

param(
    [ValidateSet("JLink", "STLink", "DFU", "")]
    [string]$Interface = "",
    [string]$File = "",
    [string]$Device = "",
    [switch]$Verify,
    [switch]$Reset = $true
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

# Get project name from CMakeLists.txt (the binary output name)
$cmakeFile = Join-Path $projectDir "CMakeLists.txt"
$projectName = Split-Path $projectDir -Leaf  # fallback
if (Test-Path $cmakeFile) {
    $match = Select-String -Path $cmakeFile -Pattern 'project\(([^)]+)\)'
    if ($match) { $projectName = $match.Matches.Groups[1].Value.Trim() }
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  STM32 Flash Programming" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$configFile = Join-Path $scriptDir "build_config.ps1"
if (Test-Path $configFile) {
    . $configFile
} else {
    $global:BUILD_TYPE = "Debug"
    $global:FLASH_INTERFACE = "JLink"
}

# Resolve interface: parameter override > config default > JLink
if (-not $Interface) { $Interface = $FLASH_INTERFACE }

# Auto-detect firmware file if not specified
$searchedPaths = @()
if (-not $File) {
    $buildDir = Join-Path $projectDir "build"
    $buildTypeDir = Join-Path $buildDir $BUILD_TYPE
    if (Test-Path $buildTypeDir) {
        $elf = Get-ChildItem -Path $buildTypeDir -Filter "*.elf" -File | Select-Object -First 1
        $hex = Get-ChildItem -Path $buildTypeDir -Filter "*.hex" -File | Select-Object -First 1
        $bin = Get-ChildItem -Path $buildTypeDir -Filter "*.bin" -File | Select-Object -First 1
        if ($hex) { $File = $hex.FullName }
        elseif ($bin) { $File = $bin.FullName }
        elseif ($elf) { $File = $elf.FullName }
    }

    if (-not $File) {
        $projectName = Split-Path $projectDir -Leaf
        $searchedPaths = @(
            "$projectDir\build\$BUILD_TYPE\$projectName.hex",
            "$projectDir\build\$BUILD_TYPE\$projectName.bin",
            "$projectDir\build\$BUILD_TYPE\$projectName.elf"
        )
        foreach ($path in $searchedPaths) {
            if (Test-Path $path) { $File = $path; break }
        }
    }
}

if (-not $File -or -not (Test-Path $File)) {
    Write-Host "ERROR: Firmware file not found!" -ForegroundColor Red; Write-Host ""
    Write-Host "Please build first:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1" -ForegroundColor White
    exit 1
}

# Auto-detect MCU device from .ioc if not specified
if (-not $Device) {
    $iocFile = Get-ChildItem -Path $projectDir -Filter "*.ioc" -File | Select-Object -First 1
    if ($iocFile) {
        foreach ($line in Get-Content $iocFile.FullName) {
            if ($line -match "Mcu\.CPN\s*=\s*([a-zA-Z0-9]+)") {
                $raw = $Matches[1]
                if ($raw -match "^(STM32[a-zA-Z0-9]{5})") { $Device = $Matches[1] + "xx" }
                else { $Device = $raw }
                break
            }
        }
    }
}
if (-not $Device) { $Device = "STM32U3xx" }

Write-Host "Firmware file: $File" -ForegroundColor Green
Write-Host "Interface: $Interface (from config)" -ForegroundColor Green
Write-Host "Device: $Device" -ForegroundColor Green
Write-Host "Build Type: $BUILD_TYPE" -ForegroundColor Gray
Write-Host ""

function Test-Command { param([string]$Command) $null = Get-Command $Command -ErrorAction SilentlyContinue; return $? }

function Find-CubeProgrammer {
    $cmd = Get-Command "STM32_Programmer_CLI.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path "C:\ST") {
        $p = Get-ChildItem -Path "C:\ST" -Filter "STM32_Programmer_CLI.exe" -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($p) { return $p.FullName }
    }
    foreach ($p in @("C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe",
                     "C:\Program Files (x86)\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

switch ($Interface) {
    "JLink" {
        Write-Host "Programming via J-Link..." -ForegroundColor Yellow; Write-Host ""
        if (Test-Command "JLink.exe") {
            $jlinkScript = @"
device $Device
si 1
speed 4000
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
            Write-Host "  Device: $Device, Speed: 4000 kHz" -ForegroundColor Gray
            $result = Start-Process -FilePath "JLink.exe" -ArgumentList "-CommanderScript", $scriptFile -Wait -PassThru -NoNewWindow
            Remove-Item $scriptFile
            if ($result.ExitCode -ne 0) { Write-Host ""; Write-Host "ERROR: Programming failed!" -ForegroundColor Red; exit 1 }
        } else {
            Write-Host "ERROR: J-Link not found!" -ForegroundColor Red
            Write-Host "Set different interface: .\config.ps1 -FlashInterface STLink" -ForegroundColor Yellow; exit 1
        }
    }

    "STLink" {
        Write-Host "Programming via ST-Link..." -ForegroundColor Yellow; Write-Host ""
        $cubePath = Find-CubeProgrammer
        if ($cubePath) {
            Write-Host "Using STM32CubeProgrammer at: $cubePath" -ForegroundColor Green
            $args = @("-c", "port=SWD", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            $result = Start-Process -FilePath $cubePath -ArgumentList $args -Wait -PassThru -NoNewWindow
            if ($result.ExitCode -ne 0) { Write-Host ""; Write-Host "ERROR: Programming failed!" -ForegroundColor Red; exit 1 }
        } elseif (Test-Command "st-flash") {
            Write-Host "Using st-flash..." -ForegroundColor Green
            $result = Start-Process -FilePath "st-flash" -ArgumentList @("write", $File, "0x8000000") -Wait -PassThru -NoNewWindow
            if ($result.ExitCode -ne 0) { Write-Host ""; Write-Host "ERROR: Programming failed!" -ForegroundColor Red; exit 1 }
        } else {
            Write-Host "ERROR: No ST-Link tool found!" -ForegroundColor Red; exit 1
        }
    }

    "DFU" {
        Write-Host "Programming via USB DFU..." -ForegroundColor Yellow; Write-Host ""
        $cubePath = Find-CubeProgrammer
        if ($cubePath) {
            Write-Host "Using STM32CubeProgrammer (DFU)..." -ForegroundColor Green
            $args = @("-c", "port=USB1", "-w", $File, "-v")
            if ($Reset) { $args += "-rst" }
            $result = Start-Process -FilePath $cubePath -ArgumentList $args -Wait -PassThru -NoNewWindow
            if ($result.ExitCode -ne 0) {
                Write-Host ""; Write-Host "ERROR: Programming failed!" -ForegroundColor Red
                Write-Host "Make sure device is in DFU mode (hold BOOT0, press reset)" -ForegroundColor Yellow; exit 1
            }
        } else { Write-Host "ERROR: No DFU tool found!" -ForegroundColor Red; exit 1 }
    }
}

Write-Host ""; Write-Host "Programming completed successfully!" -ForegroundColor Green; Write-Host ""
if ($Reset) { Write-Host "Device has been reset and should be running." -ForegroundColor Green }
else { Write-Host "Reset device to start new firmware." -ForegroundColor Yellow }
Write-Host ""; Write-Host "======================================" -ForegroundColor Cyan
exit 0
