# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
# 
#	PowerShell Script:	Wrapper Script to execute a given Python script
# 
# Description:
# ------------------------------------
#	This is a bash script (callable) which:
#		- checks for a minimum installed Python version
#		- loads vendor environments before executing the Python programs
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# scan script parameters and mark environment to be loaded
$Debug, $PyWrapper_LoadEnv = Get-PoCEnvironmentArray $PyWrapper_Parameters
# execute vendor and tool pre-hook files if present
Invoke-OpenEnvironment $PyWrapper_LoadEnv | Out-Null

if ($Debug -eq $true ) {
	Write-Host "This is the PoC-Library script wrapper operating in debug mode." -ForegroundColor Yellow
	Write-Host ""
	Write-Host "Directories:" -ForegroundColor Yellow
	Write-Host "  PoC Root        $PoC_RootDir" -ForegroundColor Yellow
	Write-Host "  Working         $PyWrapper_WorkingDir" -ForegroundColor Yellow
	Write-Host "Script:" -ForegroundColor Yellow
	Write-Host "  Filename        $PoC_ScriptPy" -ForegroundColor Yellow
	Write-Host "  Solution        $PoC_Solution" -ForegroundColor Yellow
	Write-Host "  Parameters      $PyWrapper_Parameters" -ForegroundColor Yellow
	Write-Host "Load Environment:" -ForegroundColor Yellow
	Write-Host "  Lattice Diamond $($PyWrapper_LoadEnv['Lattice']['Tools']['Diamond']['Load'])"	-ForegroundColor Yellow
	Write-Host "  Xilinx ISE      $($PyWrapper_LoadEnv['Xilinx']['Tools']['ISE']['Load'])"			-ForegroundColor Yellow
	Write-Host "  Xilinx Vivado   $($PyWrapper_LoadEnv['Xilinx']['Tools']['Vivado']['Load'])"		-ForegroundColor Yellow
	Write-Host ""
}


# execute script with appropriate Python interpreter and all given parameters
if ($PyWrapper_ExitCode -eq 0)
{	$Python_Script = "$PoC_RootDir\$PoC_ScriptPy"
	if ($PoC_Solution -eq "")
	{	$Python_ScriptParameters =	$PyWrapper_Parameters														}
	else
	{	$Python_ScriptParameters =	"--sln=$PoC_Solution " + $PyWrapper_Parameters	}
	
	# execute script with appropriate Python interpreter and all given parameters
	if ($Debug -eq $true)
	{	Write-Host "launching: '$Python_Interpreter $Python_Parameters $Python_Script $Python_ScriptParameters'" -ForegroundColor Yellow
		Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow
	}

	# launching Python script
	Invoke-Expression "$Python_Interpreter $Python_Parameters $Python_Script $Python_ScriptParameters"
	$PyWrapper_ExitCode = $LastExitCode
}

Invoke-CloseEnvironment $PyWrapper_LoadEnv | Out-Null

# clean up environment variables
$env:PoCRootDirectory =			$null
