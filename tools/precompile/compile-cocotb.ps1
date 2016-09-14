# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:            Patrick Lehmann
#
#	PowerShell Script:  Compile Cocotb's simulation libraries
#
# Description:
# ------------------------------------
#	This PowerShell script compiles Cocotb simulation libraries into a local
# directory.
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
#		http:\\www.apache.org\licenses\LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# .SYNOPSIS
# This CmdLet pre-compiles the simulation libraries from Cocotb.
#
# .DESCRIPTION
# This CmdLet:
#   (1) Creates a sub-directory 'cocotb' in the current working directory
#   (2) Compiles all Cocotb simulation libraries for
#       o GHDL
#       o QuestaSim
#
[CmdletBinding()]
param(
	# Pre-compile all libraries and packages for all simulators
	[switch]$All =				$false,

	# Pre-compile the Altera Quartus libraries for GHDL
	[switch]$GHDL =				$false,

	# Pre-compile the Altera Quartus libraries for QuestaSim
	[switch]$Questa =			$false,

	# Set Python version
	[string]$Python =			"2.7",

	# Clean up directory before analyzing.
	[switch]$Clean =			$false,

	# Show the embedded help page(s)
	[switch]$Help =				$false
)

# configure script here
$PoCRootDir =		"\..\.."
$CocotbLibDir=	"lib\cocotb"

# resolve paths
$WorkingDir =		Get-Location
$PoCRootDir =		Convert-Path (Resolve-Path ($PSScriptRoot + $PoCRootDir))
$PoCPS1 =				"$PoCRootDir\poc.ps1"

Import-Module $PSScriptRoot\precompile.psm1 -Verbose:$false -ArgumentList "$WorkingDir"

# Display help if no command was selected
$Help = $Help -or (-not ($All -or $GHDL -or $Questa))

if ($Help)
{	Get-Help $MYINVOCATION.InvocationName -Detailed
	Exit-PrecompileScript
}

$GHDL,$Questa =			Resolve-Simulator $All $GHDL $Questa
$PYTHON_VERSION = switch -regex ($Python)
	{	# "2\.?7"	{	"2.7"	}
		"3\.?4"	{	"3.4"	}
		"3\.?5"	{	"3.5"	}
		default	{ "3.5"	}
	}

$PreCompiledDir =			Get-PrecompiledDirectoryName $PoCPS1

# Get Cocotb installation directory
$CocotbInstallDir =		"$PoCRootDir\$CocotbLibDir"

$COCOTB_IncludeDir =	"$CocotbInstallDir\include"
$COCOTB_SourceDir =		"$CocotbInstallDir\lib"

# GHDL
# ==============================================================================
if ($GHDL)
{	Write-Host "Pre-compiling Altera's simulation libraries for GHDL" -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

	$GHDLBinDir =			Get-GHDLBinaryDirectory $PoCPS1
	$GHDLScriptDir =	Get-GHDLScriptDirectory $PoCPS1
	$GHDLDirName =		Get-GHDLDirectoryName $PoCPS1

	# Assemble output directory
	$DestDir = "$PoCRootDir\$PrecompiledDir\$GHDLDirName"
	# Create and change to destination directory
	Initialize-DestinationDirectory $DestDir

	# clean cocotb directory
	# if [ -d $DestDir\cocotb ]; then
		# Write-Host "Cleaning library 'cocotb' ..."
		# rm -rf cocotb
	# fi

	# Cocotb paths and settings
	$COCOTB_BuildDir =	"$DestDir\cocotb"
	$COCOTB_ObjDir =		$COCOTB_BuildDir
	$COCOTB_SharedDir =	$COCOTB_BuildDir

	mkdir $COCOTB_ObjDir -ErrorAction SilentlyContinue | Out-Null
	mkdir $COCOTB_SharedDir -ErrorAction SilentlyContinue | Out-Null

	$COCOTB_INCLUDE_SEARCH_DIR =	"-I$COCOTB_IncludeDir"
	$COCOTB_LIBRARY_SEARCH_DIR =	"-L$COCOTB_SharedDir"

	# System and Linux paths and settings
	$System_IncludeDir =	"\usr\include"
	$System_Executables =	"\usr\bin"
	$System_Libraries =		"\usr\lib"
	$Linux_IncludeDir =		"$System_IncludeDir\x86_64-linux-gnu"

	$LINUX_INCLUDE_SEARCH_DIR =		"-I$System_IncludeDir -I$Linux_IncludeDir"
	$LINUX_LIBRARY_SEARCH_DIR =		"-L$System_Libraries"

	# Python paths and settings
	$PY_LIBRARY =									"python$PY_VERSION"
	$PYTHON_DEFINES =							"-DPYTHON_SO_LIB =	lib$PY_LIBRARY.so"
	$PYTHON_INCLUDE_SEARCH_DIR =	"`"-IC:\Program Files\Python 3.5\include`""
	$PYTHON_LIBRARY_SEARCH_DIR =	""
	$PYTHON_LIBRARY =							"-l$PY_LIBRARY"

	# Common CC and LD variables
	$CC_WARNINGS =	"-Werror -Wcast-qual -Wcast-align -Wwrite-strings -Wall -Wno-unused-parameter"
	$LD_WARNINGS =	"-Waggregate-return"	# -Wstrict-prototypes
	$CC_DEBUG =			"-g -DDEBUG"
	$CC_DEFINES =		"-DMODELSIM"
	$CC_FLAGS =			"-fno-common"

	$CXX_WARNINGS =	$CC_WARNINGS
	$CXX_DEBUG =		$CC_DEBUG
	$CXX_FLAGS =		$CC_FLAGS

	# Configure executables
	$CC =		"gcc"
	$CXX =	"g++"
	$LD =		"gcc"

  Write-Host "Compiling 'libcocotbutils.so'..." -ForegroundColor Yellow
	$CC_DEFINES =							$CC_DEFINES
	$CC_WARNINGS =						$CC_WARNINGS
	$CC_INCLUDE_SEARCH_DIR =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	$CC_LIBRARY_SEARCH_DIR =	$LINUX_LIBRARY_SEARCH_DIR
	$CC_LIBRARIES =						""
	$Command = "$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir\cocotb_utils.o $COCOTB_SourceDir\utils\cocotb_utils.c"
	Write-Host $Command -ForegroundColor DarkCyan
	Invoke-Expression $Command
	if ($LastExitCode -ne 0)
	{	Write-Host "[ERROR]: While compiling 'cocotb_utils.c' with CC." -ForegroundColor Red
		Exit-PrecompileScript -1
	}
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libcocotbutils.so $COCOTB_ObjDir\cocotb_utils.o"
	Invoke-Expression $Command
	if ($LastExitCode -ne 0)
	{	Write-Host "[ERROR]: While linking 'libcocotbutils.so' with CC." -ForegroundColor Red
		Exit-PrecompileScript -1
	}

	Write-Host "Compiling 'libcocotbutils.so'..." -ForegroundColor Yellow
	$CC_DEFINES =	"$CC_DEFINES -DFILTER"
	$CC_WARNINGS =	"$CC_WARNINGS $LD_WARNINGS"
	$CC_INCLUDE_SEARCH_DIR =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	$CC_LIBRARY_SEARCH_DIR =	"$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	$CC_LIBRARIES =	"-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
	$Command = "$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir\gpi_logging.o $COCOTB_SourceDir\gpi_log\gpi_logging.c"
	Invoke-Expression $Command
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libgpilog.so $COCOTB_ObjDir\gpi_logging.o"
	Invoke-Expression $Command


	Write-Host "Compiling 'libcocotb.so'..." -ForegroundColor Yellow
	$CC_DEFINES =	"$CC_DEFINES $PYTHON_DEFINES"
	$CC_WARNINGS =	"$CC_WARNINGS $LD_WARNINGS"
	$CC_INCLUDES =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	$CC_LIBRARY_DIRS =	$LINUX_LIBRARY_SEARCH_DIR
	$CC_LIBRARIES =	"-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
	Invoke-Expression $Command
	$Command = "$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir\gpi_embed.o $COCOTB_SourceDir\embed\gpi_embed.c"
	Invoke-Expression $Command
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libcocotb.so $COCOTB_ObjDir\gpi_embed.o"


	Write-Host "Compiling 'libgpi.so'..." -ForegroundColor Yellow
	$CXX_DEFINES =	"$CC_DEFINES -DVPI_CHECKING -DLIB_EXT =	so -DSINGLETON_HANDLES"
	$CXX_WARNINGS =	"$CXX_WARNINGS"
	$CXX_INCLUDES =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	$CC_WARNINGS =	"$CC_WARNINGS $LD_WARNINGS"
	$CC_LIBRARY_DIRS =	$LINUX_LIBRARY_SEARCH_DIR
	$CC_LIBRARIES =	"-lcocotbutils -lgpilog -lcocotb -lstdc++"
	Invoke-Expression $Command
	$Command = "$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\GpiCbHdl.o $COCOTB_SourceDir\gpi\GpiCbHdl.cpp"
	Invoke-Expression $Command
	$Command = "$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\GpiCommon.o $COCOTB_SourceDir\gpi\GpiCommon.cpp"
	Invoke-Expression $Command
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libgpi.so $COCOTB_ObjDir\GpiCbHdl.o $COCOTB_ObjDir\GpiCommon.o"


	Write-Host "Compiling 'libsim.so'..." -ForegroundColor Yellow
	$CC_DEFINES =	"$CC_DEFINES $PYTHON_DEFINES"
	$CC_WARNINGS =	"$CC_WARNINGS $LD_WARNINGS"
	$CC_INCLUDES =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	$CC_LIBRARY_DIRS =	$LINUX_LIBRARY_SEARCH_DIR
	$CC_LIBRARIES =	"-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
	Invoke-Expression $Command
	$Command = "$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir\simulatormodule.o $COCOTB_SourceDir\simulator\simulatormodule.c"
	Invoke-Expression $Command
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libsim.so $COCOTB_ObjDir\simulatormodule.o"


	Write-Host "Creating symlink 'simulator.so'..." -ForegroundColor Yellow
	# ln -sf $COCOTB_SharedDir\libsim.so $COCOTB_SharedDir\simulator.so


	Write-Host "Compiling 'libvpi.so'..." -ForegroundColor Yellow
	$CXX_DEFINES =	"$CC_DEFINES -DVPI_CHECKING"
	$CXX_WARNINGS =	"$CXX_WARNINGS"
	$CXX_INCLUDES =	"$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	$CC_WARNINGS =	"$CC_WARNINGS $LD_WARNINGS"
	$CC_LIBRARY_DIRS =	$LINUX_LIBRARY_SEARCH_DIR
	$CC_LIBRARIES =	"-lgpi -lgpilog -lstdc++"
	Invoke-Expression $Command
	$Command = "$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\VpiImpl.o $COCOTB_SourceDir\vpi\VpiImpl.cpp"
	Invoke-Expression $Command
	$Command = "$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\VpiCbHdl.o $COCOTB_SourceDir\vpi\VpiCbHdl.cpp"
	Invoke-Expression $Command
	$Command = "$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libvpi.so $COCOTB_ObjDir\VpiImpl.o $COCOTB_ObjDir\VpiCbHdl.o"


	Write-Host "Removing object files..." -ForegroundColor Yellow
	rm cocotb\*.o

	cd $WorkingDir
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
}

Write-Host "---- ENDE ----"
Exit-PrecompileScript -1

# QuestaSim/ModelSim
# ==============================================================================
if ($Questa)
{	Write-Host "Pre-compiling Altera's simulation libraries for QuestaSim" -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
#	# Get GHDL directories
#	# <= $VSimBinDir
#	# <= $VSimDirName
#	GetVSimDirectories $PoC_sh
#
#	# Assemble output directory
#	DestDir=$PoCRootDir\$PrecompiledDir\$VSimDirName
#	# Create and change to destination directory
#	# -> $DestinationDirectory
#	CreateDestinationDirectory $DestDir
#
#	# clean cocotb directory
#	if [ -d $DestDir\cocotb ]; then
#		Write-Host "${YELLOW}Cleaning library 'osvvm' ..."
#		rm -rf cocotb
#	fi
#
#	# Cocotb paths and settings
#	COCOTB_BuildDir=$DestDir\cocotb
#	COCOTB_ObjDir=$COCOTB_BuildDir
#	COCOTB_SharedDir=$COCOTB_BuildDir
#
#	mkdir -p $COCOTB_ObjDir
#	mkdir -p $COCOTB_SharedDir
#
#	COCOTB_INCLUDE_SEARCH_DIR="-I$COCOTB_IncludeDir"
#	COCOTB_LIBRARY_SEARCH_DIR="-L$COCOTB_SharedDir"
#
#	# System and Linux paths and settings
#	System_IncludeDir="\usr\include"
#	System_Executables="\usr\bin"
#	System_Libraries="\usr\lib"
#	Linux_IncludeDir="$System_IncludeDir\x86_64-linux-gnu"
#
#	LINUX_INCLUDE_SEARCH_DIR="-I$System_IncludeDir -I$Linux_IncludeDir"
#	LINUX_LIBRARY_SEARCH_DIR="-L$System_Libraries"
#
#	# Python paths and settings
#	PY_VERSION="2.7"
#	PY_LIBRARY="python$PY_VERSION"
#	PYTHON_DEFINES="-DPYTHON_SO_LIB=lib$PY_LIBRARY.so"
#	PYTHON_INCLUDE_SEARCH_DIR="-I$System_IncludeDir\$PY_LIBRARY"
#	PYTHON_LIBRARY_SEARCH_DIR=
#	PYTHON_LIBRARY="-l$PY_LIBRARY"
#
#	# QuestaSim\ModelSim paths and settings
#	VSIM_IncludeDir="$VSimBinDir\..\include"
#
#	VSIM_INCLUDE_SEARCH_DIR="-I$VSIM_IncludeDir"
#
#	# Common CC and LD variables
#	CC_WARNINGS="-Werror -Wcast-qual -Wcast-align -Wwrite-strings -Wall -Wno-unused-parameter"
#	LD_WARNINGS="-Wstrict-prototypes -Waggregate-return"
#	CC_DEBUG="-g -DDEBUG"
#	CC_DEFINES="-DMODELSIM"
#	CC_FLAGS="-fno-common -fpic"
#
#	CXX_WARNINGS=$CC_WARNINGS
#	CXX_DEBUG=$CC_DEBUG
#	CXX_FLAGS=$CC_FLAGS
#
#	# Configure executables
#	CC="$VSimBinDir\..\gcc-4.7.4-linux_x86_64\bin\gcc"
#	CXX="$VSimBinDir\..\gcc-4.7.4-linux_x86_64\bin\g++"
#	LD="$System_Executables\gcc"
#
#  Write-Host "Compiling 'libcocotbutils.so'..."
#	CC_DEFINES=$CC_DEFINES
#	CC_WARNINGS=$CC_WARNINGS
#	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
#	CC_LIBRARY_SEARCH_DIR=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES=
#	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir\cocotb_utils.o $COCOTB_SourceDir\utils\cocotb_utils.c
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libcocotbutils.so $COCOTB_ObjDir\cocotb_utils.o
#
#
#	Write-Host "Compiling 'libcocotbutils.so'..."
#	CC_DEFINES="$CC_DEFINES -DFILTER"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
#	CC_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
#	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
#	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir\gpi_logging.o $COCOTB_SourceDir\gpi_log\gpi_logging.c
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libgpilog.so $COCOTB_ObjDir\gpi_logging.o
#
#
#	Write-Host "Compiling 'libcocotb.so'..."
#	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
#	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
#	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir\gpi_embed.o $COCOTB_SourceDir\embed\gpi_embed.c
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libcocotb.so $COCOTB_ObjDir\gpi_embed.o
#
#
#	Write-Host "Compiling 'libgpi.so'..."
#	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING -DLIB_EXT=so -DSINGLETON_HANDLES"
#	CXX_WARNINGS="$CXX_WARNINGS"
#	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES="-lcocotbutils -lgpilog -lcocotb -lstdc++"
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\GpiCbHdl.o $COCOTB_SourceDir\gpi\GpiCbHdl.cpp
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\GpiCommon.o $COCOTB_SourceDir\gpi\GpiCommon.cpp
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libgpi.so $COCOTB_ObjDir\GpiCbHdl.o $COCOTB_ObjDir\GpiCommon.o
#
#
#	Write-Host "Compiling 'libsim.so'..."
#	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
#	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
#	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir\simulatormodule.o $COCOTB_SourceDir\simulator\simulatormodule.c
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libsim.so $COCOTB_ObjDir\simulatormodule.o
#
#
#	Write-Host "Creating symlink 'simulator.so'..."
#	ln -sf $COCOTB_SharedDir\libsim.so $COCOTB_SharedDir\simulator.so
#
#
#	Write-Host "Compiling 'libvpi.so'..."
#	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING"
#	CXX_WARNINGS="$CXX_WARNINGS"
#	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES="-lgpi -lgpilog -lstdc++"
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\VpiImpl.o $COCOTB_SourceDir\vpi\VpiImpl.cpp
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\VpiCbHdl.o $COCOTB_SourceDir\vpi\VpiCbHdl.cpp
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libvpi.so $COCOTB_ObjDir\VpiImpl.o $COCOTB_ObjDir\VpiCbHdl.o
#
#
#	Write-Host "Compiling 'libfli.so'..."
#	CXX_DEFINES="$CC_DEFINES -DFLI_CHECKING -DUSE_CACHE"
#	CXX_WARNINGS="$CXX_WARNINGS"
#	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $VSIM_INCLUDE_SEARCH_DIR"
#	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
#	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
#	CC_LIBRARIES="-lgpi -lgpilog -lstdc++"
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\FliImpl.o $COCOTB_SourceDir\fli\FliImpl.cpp
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\FliCbHdl.o $COCOTB_SourceDir\fli\FliCbHdl.cpp
#	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir\FliObjHdl.o $COCOTB_SourceDir\fli\FliObjHdl.cpp
#	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir\libfli.so $COCOTB_ObjDir\FliImpl.o $COCOTB_ObjDir\FliCbHdl.o $COCOTB_ObjDir\FliObjHdl.o
#
#
#	Write-Host "Removing object files..."
#	rm cocotb\*.o

# restore working directory
	cd $WorkingDir
	Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
}

Write-Host "[COMPLETE]" -ForegroundColor Green

Exit-PrecompileScript
