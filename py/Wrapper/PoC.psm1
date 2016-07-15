# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
# 
#	PowerShell Script:	Wrapper Script to execute 
# 
# Description:
# ------------------------------------
#	This is a PowerShell wrapper script (executable) which:
#		- 
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

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)][string]$Py_Interpreter,
	[Parameter(Mandatory=$true)][string]$Py_Parameters,
	[Parameter(Mandatory=$true)][string]$PoC_FrontEnd
)

# Configure wrapper here
$PoC_RootDir = Convert-Path (Resolve-Path ($PSScriptRoot + "\."))			# relative path to PoC root directory

Write-Host "PoC initialized"

function poc
{	<#
		.SYNOPSIS
		PoC front-end function
		.DESCRIPTION
		undocumented
	#>
	$env:PoCRootDirectory =			$PoC_RootDir
	
	$Expr = "$Py_Interpreter $Py_Parameters $PoC_FrontEnd $args"
	Invoke-Expression $Expr
	return $LastExitCode
}

Export-ModuleMember -Function 'poc'
