#!/bin/bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:				 	Martin Zabel
# 
#	Bash Script:			Compile Altera's simulation libraries
# 
# Description:
# ------------------------------------
#	This is a bash script compiles Altera's simulation libraries into a local
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

poc_sh=../../poc.sh
Simulator=questasim					# questasim
Language=vhdl								# vhdl
TargetArchitecture="cycloneiii	stratixiv"		# space separated device list

# define color escape codes
RED='\e[0;31m'			# Red
YELLOW='\e[1;33m'		# Yellow
NOCOLOR='\e[0m'			# No Color

# Setup command to execute
QuartusSH=$($poc_sh query Altera.Quartus:BinaryDirectory 2>/dev/null)/quartus_sh
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot get Altera Quartus binary dir.${NOCOLOR}"
	exit;
fi

DestDir=$($poc_sh query PoC:InstallationDirectory 2>/dev/null)/temp/precompiled/vsim/altera	# Output directory
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot get PoC installation dir.${NOCOLOR}"
	exit;
fi 

SimulatorDir=$($poc_sh query ModelSim:InstallationDirectory 2>/dev/null)/bin	# Path to the simulators bin directory
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot get ModelSim installation dir.${NOCOLOR}"
	exit;
fi 

# Change to destination directory and create initial modelsim.ini
mkdir -p $DestDir
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot create output directory.${NOCOLOR}"
	exit;
fi 

cd $DestDir
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot change to output directory.${NOCOLOR}"
	exit;
fi 
echo "[Library]" > modelsim.ini
echo "others = ../modelsim.ini" >> modelsim.ini
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${RED}ERROR: Cannot create initial modelsim.ini.${NOCOLOR}"
	exit;
fi 

# Execute command in destination directory
$QuartusSH --simlib_comp -tool $Simulator -language $Language -tool_path $SimulatorDir -directory $DestDir -rtl_only

for Family in $TargetArchitecture; do
	$QuartusSH --simlib_comp -tool $Simulator -language $Language -family $Family -tool_path $SimulatorDir -directory $DestDir -no_rtl
done
