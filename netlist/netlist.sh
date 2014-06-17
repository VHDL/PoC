#! /bin/bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Bash Script:			Wrapper Script to execute <PoC-Root>/py/Netlist.py
# 
#	Authors:				 	Patrick Lehmann
# 
# Description:
# ------------------------------------
#	This is a bash wrapper script (executable) which:
#		- saves the current working directory as an environment variable
#		- delegates the call to <PoC-Root>/py/wrapper.sh
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

# configure wrapper here
POC_ROOTDIR_RELPATH=..
#POC_PYWRAPPER_SCRIPT=$0
POC_PYWRAPPER_SCRIPT=Netlist.py
POC_PYWRAPPER_MIN_VERSION=3.4.0

# save parameters and current working directory
POC_PYWRAPPER_PARAMS=$@
POC_PYWRAPPER_SCRIPTDIR=$(pwd)

POC_PYWRAPPER_DEBUG=0
POC_PYWRAPPER_LOADENV_ISE=0
POC_PYWRAPPER_LOADENV_VIVADO=0

# search parameter list for platform specific options
#		--coregen	-> load Xilinx ISE environment
for param in "$@"; do
	if [ "$param" = "-D" ];					then POC_PYWRAPPER_DEBUG=1; fi
	if [ "$param" = "--coregen" ];	then POC_PYWRAPPER_LOADENV_ISE=1; fi
	if [ "$param" = "--xst" ];			then POC_PYWRAPPER_LOADENV_ISE=1; fi
done

source $POC_ROOTDIR_RELPATH/py/wrapper.sh
