# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:				 	Patrick Lehmann
#                   Gustavo Martin
#
#	PowerShell Script:	OSVVM-based simulation script for PoC
#
# Description:
# ------------------------------------
#	This script builds and simulates PoC using OSVVM build system.
#	It supports GHDL and NVC simulators.
#
# License:
# ==============================================================================
# Copyright 2025-2025 The PoC-Library Authors
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#											Chair of VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

[CmdletBinding()]
param(
	[string]$Simulator = "ghdl",
	[string]$Backend = "llvm",
	[string]$Vendor = "GENERIC",
	[string]$Temp = "temp",
	[Parameter(Position=0)]
	[ValidateSet("build-osvvm", "build-poc", "simulate", "regression", "clean", "help")]
	[string]$Command = "help"
)

# Resolve script directory
$ScriptDir = $PSScriptRoot

# Function to display help
function Show-Help {
	Write-Host "PoC OSVVM-based Build and Simulation Script" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "Usage: .\poc.ps1 [OPTIONS] COMMAND"
	Write-Host ""
	Write-Host "Commands:"
	Write-Host "  build-osvvm       Build OSVVM libraries"
	Write-Host "  build-poc         Build PoC libraries"
	Write-Host "  simulate          Run all testbenches"
	Write-Host "  regression        Run complete regression (build-osvvm + build-poc + simulate)"
	Write-Host "  clean             Remove temporary directory"
	Write-Host "  help              Show this help message"
	Write-Host ""
	Write-Host "Options:"
	Write-Host "  -Simulator <sim>  Specify simulator: ghdl (default) or nvc"
	Write-Host "  -Backend <be>     GHDL backend: llvm (default), gcc, or mcode"
	Write-Host "  -Vendor <v>       Target vendor: GENERIC (default), Xilinx, Altera, etc."
	Write-Host "  -Temp <dir>       Temporary directory (default: temp)"
	Write-Host ""
	Write-Host "Examples:"
	Write-Host "  .\poc.ps1 build-osvvm                     # Build OSVVM with GHDL"
	Write-Host "  .\poc.ps1 build-poc                       # Build PoC libraries"
	Write-Host "  .\poc.ps1 simulate                        # Run all tests"
	Write-Host "  .\poc.ps1 regression                      # Run complete regression"
	Write-Host "  .\poc.ps1 -Simulator nvc build-osvvm      # Build OSVVM with NVC"
	Write-Host "  .\poc.ps1 clean                           # Clean temporary files"
	Write-Host ""
}

# Show help if requested
if ($Command -eq "help") {
	Show-Help
	exit 0
}

# Validate simulator
if ($Simulator -ne "ghdl" -and $Simulator -ne "nvc") {
	Write-Host "Error: Unsupported simulator '$Simulator'" -ForegroundColor Red
	Write-Host "Supported simulators: ghdl, nvc"
	exit 1
}

# Set up simulator-specific variables
if ($Simulator -eq "ghdl") {
	$StartScript = "StartGHDL.tcl"
	$TempSubDir = Join-Path $Temp "$Simulator-$Backend"
} elseif ($Simulator -eq "nvc") {
	$StartScript = "StartNVC.tcl"
	$TempSubDir = Join-Path $Temp $Simulator
}

# Check if simulator is installed
if ($Simulator -eq "ghdl") {
	if (-not (Get-Command ghdl -ErrorAction SilentlyContinue)) {
		Write-Host "Error: GHDL not found. Please install GHDL." -ForegroundColor Red
		exit 1
	}
} elseif ($Simulator -eq "nvc") {
	if (-not (Get-Command nvc -ErrorAction SilentlyContinue)) {
		Write-Host "Error: NVC not found. Please install NVC." -ForegroundColor Red
		exit 1
	}
}

# Check if tclsh is installed
if (-not (Get-Command tclsh -ErrorAction SilentlyContinue)) {
	Write-Host "Error: tclsh not found. Please install TCL for Windows." -ForegroundColor Red
	Write-Host "Download from: https://www.magicsplat.com/tcl-installer/ or use 'choco install tcl'" -ForegroundColor Yellow
	exit 1
}

# Clean command
if ($Command -eq "clean") {
	Write-Host "Cleaning temporary directory: $Temp" -ForegroundColor Yellow
	$TempPath = Join-Path $ScriptDir $Temp
	if (Test-Path $TempPath) {
		Remove-Item -Path $TempPath -Recurse -Force
	}
	Write-Host "Done!" -ForegroundColor Green
	exit 0
}

# Create temporary directory
$TempSubDirPath = Join-Path $ScriptDir $TempSubDir
New-Item -ItemType Directory -Force -Path $TempSubDirPath | Out-Null
Push-Location $TempSubDirPath

# Build OSVVM
if ($Command -eq "build-osvvm") {
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Building OSVVM libraries with $Simulator" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	
	# Get absolute paths
	$LibDir = Resolve-Path (Join-Path $ScriptDir "lib")
	
	# Create TCL script
	$TclScript = @"
source $LibDir/OSVVM-Scripts/$StartScript
set CurrentWorkingDirectory $LibDir
build $LibDir/OsvvmLibraries.pro OsvvmLibraries
"@
	$TclScript | Out-File -FilePath "run_osvvm.tcl" -Encoding ASCII
	
	# Run the build
	if ($Simulator -eq "ghdl") {
		& tclsh run_osvvm.tcl
	} else {
		& nvc --do run_osvvm.tcl
	}
	
	$ExitCode = $LASTEXITCODE
	Pop-Location
	
	if ($ExitCode -eq 0) {
		Write-Host "OSVVM build completed successfully!" -ForegroundColor Green
	} else {
		Write-Host "OSVVM build failed with exit code $ExitCode" -ForegroundColor Red
		exit $ExitCode
	}
	exit 0
}

# Build PoC
if ($Command -eq "build-poc") {
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Building PoC libraries with $Simulator" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	
	# Ensure my_project.vhdl exists
	$MyProjectFile = Join-Path $ScriptDir "tb\common\my_project.vhdl"
	$TemplateFile = Join-Path $ScriptDir "src\common\my_project.vhdl.template"
	
	if (-not (Test-Path $MyProjectFile)) {
		if (Test-Path $TemplateFile) {
			Write-Host "Creating my_project.vhdl from template..." -ForegroundColor Yellow
			Copy-Item $TemplateFile $MyProjectFile
		} else {
			Write-Host "Error: my_project.vhdl not found and template missing" -ForegroundColor Red
			Pop-Location
			exit 1
		}
	}
	
	# Get absolute paths
	$LibDir = Resolve-Path (Join-Path $ScriptDir "lib")
	$SrcDir = Resolve-Path (Join-Path $ScriptDir "src")
	$TbDir = Resolve-Path (Join-Path $ScriptDir "tb")
	
	# Create TCL script
	$TclScript = @"
source $LibDir/OSVVM-Scripts/$StartScript

namespace eval ::poc {
  variable myConfigFile  "$TbDir/common/my_config_$Vendor.vhdl"
  variable myProjectFile "$TbDir/common/my_project.vhdl"
  variable vendor        "$Vendor"
}

if {`$::osvvm::ToolName eq "GHDL"} {
  SetExtendedAnalyzeOptions {-frelaxed -Wno-specs -Wno-elaboration}
}
if {`$::osvvm::ToolName eq "NVC"} {
  SetExtendedAnalyzeOptions {--relaxed}
}

build $SrcDir/PoC.pro PoC
"@
	$TclScript | Out-File -FilePath "run_poc.tcl" -Encoding ASCII
	
	# Run the build
	if ($Simulator -eq "ghdl") {
		& tclsh run_poc.tcl
	} else {
		& nvc --do run_poc.tcl
	}
	
	$ExitCode = $LASTEXITCODE
	Pop-Location
	
	if ($ExitCode -eq 0) {
		Write-Host "PoC build completed successfully!" -ForegroundColor Green
	} else {
		Write-Host "PoC build failed with exit code $ExitCode" -ForegroundColor Red
		exit $ExitCode
	}
	exit 0
}

# Simulate
if ($Command -eq "simulate") {
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Running PoC simulations with $Simulator" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	
	# Ensure my_project.vhdl exists
	$MyProjectFile = Join-Path $ScriptDir "tb\common\my_project.vhdl"
	$TemplateFile = Join-Path $ScriptDir "src\common\my_project.vhdl.template"
	
	if (-not (Test-Path $MyProjectFile)) {
		if (Test-Path $TemplateFile) {
			Write-Host "Creating my_project.vhdl from template..." -ForegroundColor Yellow
			Copy-Item $TemplateFile $MyProjectFile
		} else {
			Write-Host "Error: my_project.vhdl not found and template missing" -ForegroundColor Red
			Pop-Location
			exit 1
		}
	}
	
	# Get absolute paths
	$LibDir = Resolve-Path (Join-Path $ScriptDir "lib")
	$TbDir = Resolve-Path (Join-Path $ScriptDir "tb")
	
	# Create TCL script
	$TclScript = @"
source $LibDir/OSVVM-Scripts/$StartScript

namespace eval ::poc {
  variable myConfigFile  "$TbDir/common/my_config_$Vendor.vhdl"
  variable myProjectFile "$TbDir/common/my_project.vhdl"
  variable vendor        "$Vendor"
}

if {`$::osvvm::ToolName eq "GHDL"} {
  SetExtendedSimulateOptions {-frelaxed -Wno-specs -Wno-binding}
}
if {`$::osvvm::ToolName eq "NVC"} {
}

build $TbDir/RunAllTests.pro
"@
	$TclScript | Out-File -FilePath "run_simulate.tcl" -Encoding ASCII
	
	# Run the simulation
	if ($Simulator -eq "ghdl") {
		& tclsh run_simulate.tcl
	} else {
		& nvc --do run_simulate.tcl
	}
	
	$ExitCode = $LASTEXITCODE
	Pop-Location
	
	if ($ExitCode -eq 0) {
		Write-Host "Simulations completed successfully!" -ForegroundColor Green
		Write-Host "Reports are available in: $TempSubDir\reports" -ForegroundColor Cyan
	} else {
		Write-Host "Simulations failed with exit code $ExitCode" -ForegroundColor Red
		exit $ExitCode
	}
	exit 0
}

# Regression - run complete workflow
if ($Command -eq "regression") {
	Pop-Location  # Exit temp directory first
	
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Running complete regression workflow" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host ""
	
	# Get script path
	$ScriptPath = Join-Path $ScriptDir "poc.ps1"
	
	# Step 1: Build OSVVM
	Write-Host "Step 1/3: Building OSVVM libraries..." -ForegroundColor Yellow
	& powershell -File $ScriptPath -Simulator $Simulator -Backend $Backend -Vendor $Vendor -Temp $Temp build-osvvm
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Regression failed at build-osvvm step" -ForegroundColor Red
		exit 1
	}
	Write-Host ""
	
	# Step 2: Build PoC
	Write-Host "Step 2/3: Building PoC libraries..." -ForegroundColor Yellow
	& powershell -File $ScriptPath -Simulator $Simulator -Backend $Backend -Vendor $Vendor -Temp $Temp build-poc
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Regression failed at build-poc step" -ForegroundColor Red
		exit 1
	}
	Write-Host ""
	
	# Step 3: Run simulations
	Write-Host "Step 3/3: Running simulations..." -ForegroundColor Yellow
	& powershell -File $ScriptPath -Simulator $Simulator -Backend $Backend -Vendor $Vendor -Temp $Temp simulate
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Regression failed at simulate step" -ForegroundColor Red
		exit 1
	}
	Write-Host ""
	
	Write-Host "========================================" -ForegroundColor Green
	Write-Host "Regression completed successfully!" -ForegroundColor Green
	Write-Host "========================================" -ForegroundColor Green
	exit 0
}

Pop-Location
exit 0
