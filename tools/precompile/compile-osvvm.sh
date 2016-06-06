#! /bin/bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
#                     Martin Zabel
# 
#	Bash Script:				Script to compile the OSVVM library for Questa / ModelSim
#                     on Linux
# 
# Description:
# ------------------------------------
#	This is a Bash script (executable) which:
#		- creates a subdirectory in the current working directory
#		- compiles all OSVVM packages 
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

poc_sh=../../poc.sh
OSVVMLibDir=lib/osvvm

# define color escape codes
RED='\e[0;31m'			# Red
YELLOW='\e[1;33m'		# Yellow
NOCOLOR='\e[0m'			# No Color

# command line argument processing
NO_COMMAND=TRUE
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-c|--clean)
		CLEAN=TRUE
		NO_COMMAND=FALSE
		;;
		-a|--all)
		COMPILE_ALL=TRUE
		NO_COMMAND=FALSE
		;;
		--ghdl)
		COMPILE_FOR_GHDL=TRUE
		;;
		--questa)
		COMPILE_FOR_VSIM=TRUE
		;;
		-h|--help)
		HELP=TRUE
		NO_COMMAND=FALSE
		;;
		*)		# unknown option
		UNKNOWN_OPTION=TRUE
		;;
	esac
	shift # past argument or value
done

if [ "$NO_COMMAND" == "TRUE" ]; then
	HELP=TRUE
fi

if [ "$UNKNOWN_OPTION" == "TRUE" ]; then
	echo -e $COLORED_ERROR "Unknown command line option.${ANSI_RESET}"
	exit -1
elif [ "$HELP" == "TRUE" ]; then
	if [ "$NO_COMMAND" == "TRUE" ]; then
		echo -e $COLORED_ERROR " No command selected."
	fi
	echo ""
	echo "Synopsis:"
	echo "  Script to compile the simulation library OSVVM for"
	echo "  - GHDL"
	echo "  - QuestaSim/ModelSim"
	echo "  on Linux."
	echo ""
	echo "Usage:"
	echo "  compile-osvvm.sh [-c|--clean] [-h|--all|--ghdl|--vsim]"
	echo ""
	echo "Common commands:"
	echo "  -h --help             Print this help page"
	echo "  -c --clean            Remove all generated files"
	echo ""
	echo "Tool chain:"
	echo "  -a --all              Compile for all tool chains."
	echo "  -g --ghdl             Compile for GHDL."
	echo "  -v --vsim             Compile for QuestaSim/ModelSim."
	echo ""
	exit 0
fi

# Files
Files=(
	$SourceDir/NamePkg.vhd
	$SourceDir/OsvvmGlobalPkg.vhd
	$SourceDir/TextUtilPkg.vhd
	$SourceDir/TranscriptPkg.vhd
	$SourceDir/AlertLogPkg.vhd
	$SourceDir/MemoryPkg.vhd
	$SourceDir/MessagePkg.vhd
	$SourceDir/SortListPkg_int.vhd
	$SourceDir/RandomBasePkg.vhd
	$SourceDir/RandomPkg.vhd
	$SourceDir/CoveragePkg.vhd
	$SourceDir/OsvvmContext.vhd
)

PoCRootDir=$($poc_sh query INSTALL.PoC:InstallationDirectory 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot get PoC installation dir.${NOCOLOR}"
	echo 1>&2 -e "${RED}$PoCRootDir${NOCOLOR}"
	exit -1;
fi

PrecompiledDir=$($poc_sh query CONFIG.DirectoryNames:PrecompiledFiles 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot get precompiled dir.${NOCOLOR}"
	echo 1>&2 -e "${RED}$PrecompiledDir${NOCOLOR}"
	exit -1;
fi

# Setup destination directory
SourceDir=$PoCRootDir/$OSVVMLibDir
DestDir=$PoCRootDir/$PrecompiledDir

if [ "$COMPILE_ALL" == "TRUE" ]; then
	COMPILE_FOR_GHDL=TRUE
	COMPILE_FOR_VSIM=TRUE
fi

# GHDL
# ==============================================================================
if [ "$COMPILE_FOR_GHDL" == "TRUE" ]; then
	DestDir=$DestDir/ghdl/osvvm/v08
	
	# Get GHDL binary
	BinDir=$($poc_sh query INSTALL.GHDL:BinaryDirectory 2>/dev/null)	# Path to the simulators bin directory
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot get GHDL binary dir.${NOCOLOR}"
		echo 1>&2 -e "${RED}$BinDir${NOCOLOR}"
		exit -1;
	fi
	
	# Cleanup
	if [ "$CLEAN" == "TRUE" ]; then
		echo -e "${ANSI_YELLOW}Cleaning library 'osvvm' ...${ANSI_RESET}"
		rm -Rf $DestDir 2> /dev/null
	fi
	
	# Create and change to destination directory
	mkdir -p $DestDir
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot create output directory.${NOCOLOR}"
		exit -1;
	fi
	cd $DestDir
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot change to output directory.${NOCOLOR}"
		exit -1;
	fi
	
	# Analyze each VHDL source file.
	for file in ${Files[@]}; do
		echo "Compiling $file..."
		$BinDir/ghdl -a -fexplicit -frelaxed-rules --no-vital-checks --warn-binding --mb-comments --std=08 --work=osvvm $file
	done
fi

# QuestaSim/ModelSim
# ==============================================================================
if [ "$COMPILE_FOR_VSIM" == "TRUE" ]; then
	DestDir=$DestDir/vsim
	
	# Get QuestaSim/ModelSim binary
	BinDir=$($poc_sh query ModelSim:BinaryDirectory 2>/dev/null)	# Path to the simulators bin directory
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot get QuestaSim/ModelSim binary dir.${NOCOLOR}"
		echo 1>&2 -e "${RED}$BinDir${NOCOLOR}"
		exit -1;
	fi
	
	# Create and change to destination directory
	mkdir -p $DestDir
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot create output directory.${NOCOLOR}"
		exit -1;
	fi
	cd $DestDir
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${RED}ERROR: Cannot change to output directory.${NOCOLOR}"
		exit -1;
	fi
	
	# Compile libraries with vcom, executed in destination directory
	rm -rf osvvm
	vlib osvvm
	vmap -del osvvm
	vmap osvvm $DestDir/osvvm
	for file in ${Files[@]}; do
		echo "Compiling $file..."
		$BinDir/vcom -2008 -work osvvm $file
	done
fi
