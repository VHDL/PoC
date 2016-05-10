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
{	Write-Host "ISE: register environment"

	if (Test-Path Alias:tb)
	{	Write-Host "[WARNING] Alias 'tb' is already in use. Use the CmdLet 'Start-Testbench instead.'" -ForegroundColor Yellow	}
	else
	{	Set-Alias -Name tb -Value Start-Testbench -Description "Start a testbench in ISE." -Scope Global												}
}

function Unregister-Environment
{	Write-Host "ISE: unregister environment"
	
	if (Test-Path Alias:tb)		{	Remove-Item Alias:tb		}
}

function Start-Testbench
{	
	
	Write-Host "ISE: Start a testbench only in VHDL'93"
}

function Set-VHDLStandard
{
	[CmdletBinding()]
	param(
		[String] $std
	)
	Write-Host "ISE: Set-VHDLStandard not supported" -ForegroundColor Red
}

Export-ModuleMember -Function 'Register-Environment'
Export-ModuleMember -Function 'Unregister-Environment'
Export-ModuleMember -Function 'Start-Testbench'
Export-ModuleMember -Function 'Set-VHDLStandard'

