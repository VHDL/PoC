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

# goto PoC root directory and save this path
cd $POC_ROOTDIR_RELPATH
POC_ROOTDIR_ABSPATH=$(pwd)

# find suitable python version or abort execution
python -c 'import sys; sys.exit(not (0x03040000 < sys.hexversion < 0x04000000))' 2>/dev/null
if [ $? -eq 0 ]; then
	PYTHON_INTERPRETER=$(which python)
fi
# standard python interpreter is not suitable, try to find a suitable version manually
if [ ! $? -eq 0 ]; then
	for pyVersion in 3.9 3.8 3.7 3.6 3.5 3.4; do
		PYTHON_INTERPRETER=$("which python$pyVersion")
		# if ExitCode = 0 => version found
		if [ $? -eq 0 ]; then
			break
		fi
	done
fi
# if no interpreter was found => exit
if [ $PYTHON_INTERPRETER ]; then
	echo 1>&2 "No suitable Python interpreter found."
	echo 1>&2 "The script requires Python >= $POC_PYWRAPPER_MIN_VERSION"
	exit 1
fi

if [ $POC_PYWRAPPER_LOADENV_ISE -eq 0 ]; then
	# if $XILINX environment variable is not set
	if [ -z "$XILINX" ]; then
			iseSettingsFile=$($PYTHON_INTERPRETER $POC_ROOTDIR_ABSPATH/py/configuration.py --ise-settingsfile)
			if [ $iseSettingsFile ]; then
				echo 1>&2 "No Xilinx ISE installation found."
				echo 1>&2 "Run 'poc.py --configure' to configure your Xilinx ISE installation."
				exit 1
			fi
			echo "Loading Xilinx ISE environment '$iseSettingsFile'"
			rescue_args=$@
			set --
			source "$iseSettingsFile"
			set -- $rescue_args
		fi
fi

# TODO: prepared for Vivado support
#
#if [ $POC_PYWRAPPER_LOADENV_VIVADO -eq 0 ]; then
#	# if $XILINX environment variable is not set
#	if [ -z "$XILINX" ]; then
#			vivadoSettingsFile=$($PYTHON_INTERPRETER $POC_ROOTDIR_ABSPATH/py/configuration.py --vivado-settingsfile)
#			if [ $vivadoSettingsFile ]; then
#				echo 1>&2 "No Xilinx Vivado installation found."
#				echo 1>&2 "Run 'poc.py --configure' to configure your Xilinx Vivado installation."
#				exit 1
#			fi
#			echo "Loading Xilinx Vivado environment '$vivadoSettingsFile'"
#			rescue_args=$@
#			set --
#			source "$vivadoSettingsFile"
#			set -- $rescue_args
#		fi
#fi

# execute script with appropriate python interpreter and all given parameters
exec $PYTHON_INTERPRETER $POC_PYWRAPPER_SCRIPT $POC_PYWRAPPER_PARAMS
