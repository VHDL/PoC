#! /bin/bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Bash Script:			Wrapper Script to execute <PoC-Root>/py/Testbench.py
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
PyWrapper_SCRIPT=Testbench.py
PyWrapper_MIN_VERSION=3.4.0

# resolve script directory
# solution is taken from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do													# resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"			# if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# save parameters and script directory
POC_ROOTDIR_RELPATH="$SCRIPT_DIR/.."
PyWrapper_PARAMS=$@
PyWrapper_SCRIPTDIR=$(pwd)

# set default values
PyWrapper_DEBUG=0
PyWrapper_LOADENV_ISE=0
PyWrapper_LOADENV_VIVADO=0
PyWrapper_LOADENV_MODELSIM=0

# search parameter list for platform specific options
#		--isim	-> load Xilinx ISE environment
#		--xsim	-> load Xilinx Vivado environment
#		--vsim	-> load Mentor Graphics ModelSim environment
for param in "$@"; do
	if [ "$param" = "-D" ]; then PyWrapper_DEBUG=1; fi
	if [ "$param" = "--isim" ]; then PyWrapper_LOADENV_ISE=1; fi
	if [ "$param" = "--xsim" ]; then PyWrapper_LOADENV_VIVADO=1; fi
#	if [ "$param" = "--vsim" ]; then PyWrapper_LOADENV_MODELSIM=1; fi
done

# invoke main wrapper
source $POC_ROOTDIR_RELPATH/py/wrapper.sh

exit $POC_EXITCODE
