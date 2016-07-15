# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	PowerShell Script:	Wrapper Script to execute <PoC-Root>/py/Configuration.py
# 
#	Authors:						Patrick Lehmann
# 
# Description:
# ------------------------------------
#	This is a PowerShell wrapper script (executable) which:
#		- 
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

$VHDLStandard = "93"

function Register-Environment
{	Write-Host "GHDL: register environment"


	if (Test-Path Alias:tb)
	{	Write-Host "[WARNING] Alias 'tb' is already in use. Use the CmdLet 'Start-Testbench instead.'" -ForegroundColor Yellow	}
	else
	{	Set-Alias -Name tb -Value Start-Testbench -Description "Start a testbench in GHDL." -Scope Global												}

}

function Unregister-Environment
{	Write-Host "GHDL: unregister environment"
	
	if (Test-Path Alias:tb)		{	Remove-Item Alias:tb		}
}

function Start-Testbench
{	
	
	Write-Host "GHDL: Start a testbench with VHDL standard set to '$($script:VHDLStandard)'"
}

function Set-VHDLStandard
{
	[CmdletBinding()]
	param(
		[String] $std
	)
	Write-Host "Set-VHDLStandard"
	if (($std -eq "87") -or ($std -eq "1987"))
	{	$script:VHDLStandard = "87"	}
	elseif (($std -eq "93") -or ($std -eq "1993"))
	{	$script:VHDLStandard = "93"	}
	elseif (($std -eq "02") -or ($std -eq "2001"))
	{	$script:VHDLStandard = "02"	}
	elseif (($std -eq "08") -or ($std -eq "2008"))
	{	$script:VHDLStandard = "08"	}
	else
	{ Write-Host "Unknown VHDL Standard: '$std'. Supported standards: 87, 93, 02, 08." -ForegroundColor Red		}
}

Export-ModuleMember -Function 'Register-Environment'
Export-ModuleMember -Function 'Unregister-Environment'
Export-ModuleMember -Function 'Start-Testbench'
Export-ModuleMember -Function 'Set-VHDLStandard'

