# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:            Patrick Lehmann
# 
#	PowerShell Script:  Compile OSVVM's simulation libraries
# 
# Description:
# ------------------------------------
#	This is a PowerShell script compiles OSVVM's simulation libraries into a local
#	directory.
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#											Chair for VLSI-Design, Diagnostics and Architecture
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

# .SYNOPSIS
# This CmdLet pre-compiles the simulation libraries from OSVVM.
# 
# .DESCRIPTION
# This CmdLet:
#   (1) Creates a sub-directory 'osvvm' in the current working directory
#   (2) Compiles all OSVVM simulation libraries and packages for
#       o GHDL
#       o QuestaSim
# 
[CmdletBinding()]
param(
	# Pre-compile all libraries and packages for all simulators
	[switch]$All =				$false,
	
	# Pre-compile the OSVVM libraries for GHDL
	[switch]$GHDL =				$false,
	
	# Pre-compile the OSVVM libraries for QuestaSim
	[switch]$Questa =			$false,
	
	# # Set VHDL Standard to '93
	# [switch]$VHDL93 =			$false,
	# Set VHDL Standard to '08
	[switch]$VHDL2008 =		$false,
	
	# Clean up directory before analyzing.
	[switch]$Clean =			$false,
	
	# Show the embedded help page(s)
	[switch]$Help =				$false
)

$PoCRootDir =		"\..\.."

# resolve paths
$WorkingDir =		Get-Location
$PoCRootDir =		Convert-Path (Resolve-Path ($PSScriptRoot + $PoCRootDir))
$PoCPS1 =				"$PoCRootDir\poc.ps1"

Import-Module $PSScriptRoot\shared.psm1 -ArgumentList "$WorkingDir"

# Display help if no command was selected
$Help = $Help -or (-not ($All -or $GHDL -or $Questa))

if ($Help)
{	Get-Help $MYINVOCATION.InvocationName -Detailed
	return
}
if ($All)
{	$GHDL =				$true
	$QuestaSim =	$true
}

$PreCompiledDir =	Get-PrecompiledDirectoryName $PoCPS1
$OSVVMDirName =		Get-OSVVMDirectoryName $PoCPS1

# GHDL
# ==============================================================================
if ($GHDL)
{	Write-Host "Pre-compiling OSVVM's simulation libraries for GHDL" -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

	$GHDLBinDir =			Get-GHDLBinaryDirectory $PoCPS1
	$GHDLScriptDir =	Get-GHDLScriptDirectory $PoCPS1
	$GHDLDirName =		Get-GHDLDirectoryName $PoCPS1

	# Assemble output directory
	$DestDir="$PoCRootDir\$PrecompiledDir\$GHDLDirName"
	# Create and change to destination directory
	Initialize-DestinationDirectory $DestDir
	
	$GHDLOSVVMScript = "$GHDLScriptDir\compile-osvvm.ps1"
	if (-not (Test-Path $GHDLOSVVMScript -PathType Leaf))
	{ Write-Host "[ERROR]: OSVVM compile script from GHDL is not executable." -ForegroundColor Red
		Exit-PrecompileScript -1
	}
	
	$ISEInstallDir =	Get-ISEInstallationDirectory $PoCPS1
	$SourceDir =			"$ISEInstallDir\ISE\vhdl\src"
	
	# export GHDL environment variable if not allready set
	if (-not (Test-Path env:GHDL))
	{	$env:GHDL = "$GHDLBinDir\ghdl.exe"		}
	
	$Command = "$GHDLOSVVMScript -All -Source $SourceDir -Output $OSVVMDirName"
	Write-Host $Command
	# Invoke-Expression $Command
	if ($LastExitCode -ne 0)
	{	Write-Host "[ERROR]: While executing vendor library compile script from GHDL." -ForegroundColor Red
		Exit-PrecompileScript -1
	}
	
	rm $OSVVMDirName -ErrorAction SilentlyContinue
	try
	{	New-Symlink $OSVVMDirName $OSVVMDirName		}
	catch
	{	Write-Host "[ERROR]: While creating a symlink. Not enough rights?" -ForegroundColor Red
		Exit-PrecompileScript -1
	}
	
	# restore working directory
	cd $WorkingDir
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
}

# QuestaSim/ModelSim
# ==============================================================================
if ($Questa)
{	Write-Host "Pre-compiling OSVVM's simulation libraries for QuestaSim" -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

	$VSimBinDir =			Get-ModelSimBinaryDirectory $PoCPS1
	$VSimDirName =		Get-QuestaSimDirectoryName $PoCPS1

	# Assemble output directory
	$DestDir="$PoCRootDir\$PrecompiledDir\$VSimDirName\$OSVVMDirName"
	# Create and change to destination directory
	Initialize-DestinationDirectory $DestDir

	$ISEBinDir = 		Get-ISEBinaryDirectory $PoCPS1
	$ISE_compxlib =	"$ISEBinDir\compxlib.exe"
	
	New-ModelSim_ini
	
	$Simulator =					"questa"
	$Language =						"vhdl"
	$TargetArchitecture =	"all"
	
	$Command = "$ISE_compxlib -64bit -s $Simulator -l $Language -dir $DestDir -p $VSimBinDir -arch $TargetArchitecture -lib unisim -lib simprim -lib osvvmcorelib -intstyle ise"
	Write-Host $Command
	# Invoke-Expression $Command
	if ($LastExitCode -ne 0)
	{	Write-Host "[ERROR]: While executing vendor library compile script from GHDL." -ForegroundColor Red
		Exit-PrecompileScript -1
	}
	
	# restore working directory
	cd $WorkingDir
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
}

Write-Host "[COMPLETE]" -ForegroundColor Green

Exit-PrecompileScript
