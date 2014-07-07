#! /bin/bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Bash Script:			Wrapper Script to execute a given python script
# 
#	Authors:				 	Patrick Lehmann
#										Thomas B. Preusser
#										Martin Zabel
# 
# Description:
# ------------------------------------
#	This is a bash script (callable) which:
#		- 
#		- 
#		-
#
# License:
# ==============================================================================
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

# script settings
POC_SCRIPTSDIR=py

RED='\e[0;31m'			# Yellow
YELLOW='\e[1;33m'		# Yellow
NOCOLOR='\e[0m'			# No Color

# goto PoC root directory and save this path
cd $POC_ROOTDIR_RELPATH
POC_ROOTDIR_ABSPATH=$(pwd)
export PoCRootDirectory=$POC_ROOTDIR_ABSPATH

if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then
	echo -e "${YELLOW}This is the PoC Library script wrapper operating in debug mode.${NOCOLOR}"
	echo
	echo -e "${YELLOW}Directories:${NOCOLOR}"
	echo -e "${YELLOW}  Script root:   $POC_PYWRAPPER_SCRIPTDIR${NOCOLOR}"
	echo -e "${YELLOW}  PoC abs. root: $POC_ROOTDIR_ABSPATH${NOCOLOR}"
	echo -e "${YELLOW}Script:${NOCOLOR}"
	echo -e "${YELLOW}  Filename:      $POC_PYWRAPPER_SCRIPT${NOCOLOR}"
	echo -e "${YELLOW}  Parameters:    $POC_PYWRAPPER_PARAMS${NOCOLOR}"
	echo -e "${YELLOW}Load Environment:${NOCOLOR}"
	echo -e "${YELLOW}  Xilinx ISE:    $POC_PYWRAPPER_LOADENV_ISE${NOCOLOR}"
	echo -e "${YELLOW}  Xilinx VIVADO: $POC_PYWRAPPER_LOADENV_VIVADO${NOCOLOR}"
	echo
fi

# find suitable python version or abort execution
PYTHON_VERSIONTEST='import sys; sys.exit(not (0x03040000 < sys.hexversion < 0x04000000))'
python -c $PYTHON_VERSIONTEST 2>/dev/null
if [ $? -eq 0 ]; then
	PYTHON_INTERPRETER=$(which python)
	if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}PythonInterpreter: use standard interpreter: '$PYTHON_INTERPRETER'${NOCOLOR}"; fi
else
	# standard python interpreter is not suitable, try to find a suitable version manually
	for pyVersion in 3.9 3.8 3.7 3.6 3.5 3.4; do
		PYTHON_INTERPRETER=$(which python$pyVersion)
		# if ExitCode = 0 => version found
		if [ $? -eq 0 ]; then
			# redo version test
			$PYTHON_INTERPRETER -c $PYTHON_VERSIONTEST 2>/dev/null
			if [ $? -eq 0 ]; then break; fi
		fi
	done
	if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}PythonInterpreter: use this interpreter: '$PYTHON_INTERPRETER'${NOCOLOR}"; fi
fi
# if no interpreter was found => exit
if [ ! $PYTHON_INTERPRETER ]; then
	echo 1>&2 -e "${RED}No suitable Python interpreter found.${NOCOLOR}"
	echo 1>&2 -e "${RED}The script requires Python >= $POC_PYWRAPPER_MIN_VERSION${NOCOLOR}"
	exit 1
fi

cd $POC_ROOTDIR_ABSPATH/$POC_SCRIPTSDIR

# load Xilinx ISE environment
if [ $POC_PYWRAPPER_LOADENV_ISE -eq 1 ]; then
	# if $XILINX environment variable is not set
	if [ -z "$XILINX" ]; then
		command="$PYTHON_INTERPRETER $POC_ROOTDIR_ABSPATH/py/Configuration.py --ise-settingsfile"
		if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}getting ISE settings file: command='$command'${NOCOLOR}"; fi
		iseSettingsFile=$($command)
		if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}ISE settings file: '$iseSettingsFile'${NOCOLOR}"; fi
		if [ ! $iseSettingsFile ]; then
			echo 1>&2 -e "${RED}No Xilinx ISE installation found.${NOCOLOR}"
			echo 1>&2 -e "${RED}Run 'poc.py --configure' to configure your Xilinx ISE installation.${NOCOLOR}"
			exit 1
		fi
		echo -e "${YELLOW}Loading Xilinx ISE environment '$iseSettingsFile'${NOCOLOR}"
		rescue_args=$@
		set --
		source "$iseSettingsFile"
		set -- $rescue_args
	fi
fi

# load Xilinx Vivado environment
if [ $POC_PYWRAPPER_LOADENV_VIVADO -eq 1 ]; then
	# if $XILINX environment variable is not set
	if [ -z "$XILINX" ]; then
		command="$PYTHON_INTERPRETER $POC_ROOTDIR_ABSPATH/py/Configuration.py --vivado-settingsfile"
		if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}getting Vivado settings file: command='$command'${NOCOLOR}"; fi
		vivadoSettingsFile=$($command)
		if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then echo -e "${YELLOW}Vivado settings file: '$vivadoSettingsFile'${NOCOLOR}"; fi
		if [ ! $vivadoSettingsFile ]; then
			echo 1>&2 -e "${RED}No Xilinx Vivado installation found.${NOCOLOR}"
			echo 1>&2 -e "${RED}Run 'poc.py --configure' to configure your Xilinx Vivado installation.${NOCOLOR}"
			exit 1
		fi
		echo -e "${YELLOW}Loading Xilinx vivadoivado environment '$vivadoSettingsFile'${NOCOLOR}"
		rescue_args=$@
		set --
		source "$vivadoSettingsFile"
		set -- $rescue_args
	fi
fi

# execute script with appropriate python interpreter and all given parameters
if [ $POC_PYWRAPPER_DEBUG -eq 1 ]; then
	echo -e "${YELLOW}cd $POC_ROOTDIR_ABSPATH/$POC_SCRIPTSDIR${NOCOLOR}"
	echo -e "${YELLOW}launching: '$PYTHON_INTERPRETER $POC_PYWRAPPER_SCRIPT $POC_PYWRAPPER_PARAMS'${NOCOLOR}"
	echo -e "${YELLOW}------------------------------------------------------------${NOCOLOR}"
	echo
fi
exec $PYTHON_INTERPRETER $POC_PYWRAPPER_SCRIPT $POC_PYWRAPPER_PARAMS

unset PoCRootDirectory