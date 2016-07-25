# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
# 
#	PowerShell Script:	Wrapper Script to execute <PoC-Root>/py/PoC.py
# 
# Description:
# ------------------------------------
#	This is a bash wrapper script (executable) which:
#		- saves the current working directory as an environment variable
#		- delegates the call to <PoC-Root>/py/wrapper.sh
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
#
# Change this, if PoC solutions and PoC projects are used
$RootDir_RelPath =			"."		# relative path to PoC root directory
$PoC_Solution =					""		# solution name

# save parameters and current working directory
$PyWrapper_Parameters =	$args
$PyWrapper_WorkingDir =	Get-Location
$PyWrapper_ExitCode =		0

# Configure PoC environment here
$PoC_PythonDir =				"py"
$PoC_WrapperDir =				"py\Wrapper"
$PoC_Module =						"PoC"
$PoC_Wrapper =					"Wrapper.ps1"

# Configure wrapper here
$Py_MinVersion =				"3.5"
$PoC_ScriptPy =					"$PoC_PythonDir\PoC.py"

$PoCRootDir =						Convert-Path (Resolve-Path ($PSScriptRoot + "\" + $RootDir_RelPath))
Import-Module "$PoCRootDir\$PoC_WrapperDir\$PoC_Module.psm1" -ArgumentList @($Py_MinVersion, $PoCRootDir)

# invoke main wrapper
. "$PoCRootDir\$PoC_WrapperDir\$PoC_Wrapper"

# restore working directory if changed
Set-Location $PyWrapper_WorkingDir

# unload PowerShell module
Remove-Module $PoC_Module

# return exit status
exit $PyWrapper_ExitCode
