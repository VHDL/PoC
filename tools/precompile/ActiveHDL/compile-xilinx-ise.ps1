# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
# 
#	PowerShell Script:	Script to compile the simulation libraries from Xilinx ISE
#											for Active-HDL on Windows
# 
# Description:
# ------------------------------------
#	This is a PowerShell script (executable) which:
#		- creates a subdirectory in the current working directory
#		- compiles all Xilinx ISE simulation libraries and packages
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
# This CmdLet compiles the simulation libraries from Xilinx.
# 
# .DESCRIPTION
# This CmdLet:
#   (1) creates a subdirectory in the current working directory
#   (2) compiles all Xilinx ISE simulation libraries and packages
#       - unisim (incl. secureip)
#       - unimacro
#       - simprim (incl. secureip)
#
[CmdletBinding()]
param(
	# Compile all libraries and packages.
	[switch]$All =			$null,
	
	# Compile the Xilinx simulation library.
	[switch]$Unisim =		$false,
	
	# Compile the Xilinx macro library.
	[switch]$Unimacro =	$false,
	
	# Compile the Xilinx post-map simulation library.
	[switch]$Simprim =	$false,
	
	# Compile the Xilinx secureip library.
	[switch]$SecureIP =	$false,
	
	# Clean up directory before analyzing.
	[switch]$Clean =		$false,
	
	# Skip warning messages. (Show errors only.)
	[switch]$SuppressWarnings = $false,
	
	# Show the embedded help page(s)
	[switch]$Help =							$false
)

if ($Help)
{	Get-Help $MYINVOCATION.InvocationName -Detailed
	return
}

# ---------------------------------------------
# save working directory
$WorkingDir = Get-Location

# load modules from GHDL's 'vendors' library directory
Import-Module $PSScriptRoot\..\config.psm1
Import-Module $PSScriptRoot\..\shared.psm1

$BinaryDir =		"C:\Lattice\diamond\3.7_x64\active-hdl\BIN"
$LibraryTool =	$BinaryDir + "\vlib.exe"
$VHDLCompiler =	$BinaryDir + "\vcom.exe"

# extract data from configuration
$SourceDir =			$InstallationDirectory["XilinxISE"] + "\ISE_DS\ISE\vhdl\src"
$DestinationDir = $DestinationDirectory["XilinxISE"]

if (-not $All)
{	$All =			$false	}
elseif ($All -eq $true)
{	$Unisim =		$true
	$Simprim =	$true
	$Unimacro =	$true
	$SecureIP =	$true
}
$StopCompiling = $false


# define global GHDL Options
$GlobalOptions = ("-93", "-relax")

# create "Xilinx" directory and change to it
Write-Host "Creating vendor directory: '$DestinationDir'" -ForegroundColor Yellow
mkdir $DestinationDir -ErrorAction SilentlyContinue | Out-Null
cd $DestinationDir

# Cleanup
# ==============================================================================
if ($Clean)
{	Write-Host "Cleaning up vendor directory ..." -ForegroundColor Yellow
	rm *.cf
}

# Library UNISIM
# ==============================================================================
# compile unisim packages
if ((-not $StopCompiling) -and $Unisim)
{	Write-Host "Compiling library 'unisim' ..." -ForegroundColor Yellow
	$InvokeExpr = $LibraryTool + " " + "unisim"
	Write-Host $InvokeExpr
	$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
	$StopCompiling = ($LastExitCode -ne 0)
}

if ((-not $StopCompiling) -and $Unisim)
{	$Options = $GlobalOptions
	$Files = (
		"$SourceDir\unisims\unisim_VPKG.vhd",
		"$SourceDir\unisims\unisim_VCOMP.vhd")
	foreach ($File in $Files)
	{	Write-Host "Analyzing package '$File'" -ForegroundColor Cyan
		$InvokeExpr = $VHDLCompiler + " " + ($Options -join " ") + " -work unisim " + $File + " 2>&1"
		Write-Host $InvokeExpr
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		if ($StopCompiling)	{ break }
	}
}

# compile unisim primitives
if ((-not $StopCompiling) -and $Unisim)
{	$Options = $GlobalOptions
	$Files = dir "$SourceDir\unisims\primitive\*.vhd*"
	foreach ($File in $Files)
	{	Write-Host "Analyzing primitive '$($File.FullName)'" -ForegroundColor Cyan
		$InvokeExpr = $VHDLCompiler + " " + ($Options -join " ") + " -work unisim " + $File.FullName + " 2>&1"
		Write-Host $InvokeExpr
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		if ($StopCompiling)	{ break }
	}
}

# compile unisim secureip primitives
if ((-not $StopCompiling) -and $Unisim -and $SecureIP)
{	Write-Host "Compiling library secureip primitives ..." -ForegroundColor Yellow
	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = dir "$SourceDir\unisims\secureip\*.vhd*"
	foreach ($File in $Files)
	{	Write-Host "Analyzing primitive '$($File.FullName)'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=secureip " + $File.FullName + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		#if ($StopCompiling)	{ break }
	}
}

# Library UNIMACRO
# ==============================================================================
# compile unimacro packages
if ((-not $StopCompiling) -and $Unimacro)
{	Write-Host "Compiling library 'unimacro' ..." -ForegroundColor Yellow
	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = @(
		"$SourceDir\unimacro\unimacro_VCOMP.vhd")
	foreach ($File in $Files)
	{	Write-Host "Analyzing package '$File'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=unimacro " + $File + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		if ($StopCompiling)	{ break }
	}
}

# compile unimacro macros
if ((-not $StopCompiling) -and $Unimacro)
{	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = dir "$SourceDir\unimacro\*_MACRO.vhd*"
	foreach ($File in $Files)
	{	Write-Host "Analyzing primitive '$($File.FullName)'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=unimacro " + $File.FullName + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		if ($StopCompiling)	{ break }
	}
}

# Library SIMPRIM
# ==============================================================================
# compile simprim packages
if ((-not $StopCompiling) -and $Simprim)
{	Write-Host "Compiling library 'simprim' ..." -ForegroundColor Yellow
	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = (
		"$SourceDir\simprims\simprim_Vpackage.vhd",
		"$SourceDir\simprims\simprim_Vcomponents.vhd")
	foreach ($File in $Files)
	{	Write-Host "Analyzing package '$File'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=simprim " + $File + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		if ($StopCompiling)	{ break }
	}
}

# compile simprim primitives
if ((-not $StopCompiling) -and $Simprim)
{	Write-Host "Compiling library 'simprim' ..." -ForegroundColor Yellow
	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = dir "$SourceDir\simprims\primitive\other\*.vhd*"
	foreach ($File in $Files)
	{	Write-Host "Analyzing primitive '$($File.FullName)'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=simprim " + $File.FullName + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		#if ($StopCompiling)	{ break }
	}
}

# compile simprim secureip primitives
if ((-not $StopCompiling) -and $Simprim -and $SecureIP)
{	Write-Host "Compiling secureip primitives ..." -ForegroundColor Yellow
	$Options = $GlobalOptions
	$Options += "--ieee=synopsys"
	$Options += "--std=93c"
	$Files = dir "$SourceDir\simprims\secureip\other\*.vhd*"
	foreach ($File in $Files)
	{	Write-Host "Analyzing primitive '$($File.FullName)'" -ForegroundColor Cyan
		$InvokeExpr = "ghdl.exe " + ($Options -join " ") + " --work=simprim " + $File.FullName + " 2>&1"
		$ErrorRecordFound = Invoke-Expression $InvokeExpr | Restore-NativeCommandStream | Write-ColoredActiveHDLLine $SuppressWarnings
		$StopCompiling = ($LastExitCode -ne 0)
		#if ($StopCompiling)	{ break }
	}
}

Write-Host "--------------------------------------------------------------------------------"
Write-Host "Compiling Xilinx ISE libraries " -NoNewline
if ($StopCompiling)
{	Write-Host "[FAILED]" -ForegroundColor Red				}
else
{	Write-Host "[SUCCESSFUL]" -ForegroundColor Green	}

# unload PowerShell modules
Remove-Module shared
Remove-Module config

# restore working directory
cd $WorkingDir
