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

$CurrentEnvironment =	$null
$VendorModulePath =		".\py"
$Environments = @{
	ISE = New-Object PSObject -Property @{
		Name =					"ISE";
		PSModuleName =	"Xilinx-ISE"
	};
	GHDL = New-Object PSObject -Property @{
		Name =					"GHDL";
		PSModuleName =	"GHDL"
	};	
}

$Aliases = @()

function Register-PoC
{
	foreach ($a in (Get-Item Alias:))
	{	$script:Aliases += $a
		Write-Host "$($a.Name) => $($a.ReferencedCommand) ($($a.Visibility))"
		Remove-Item "Alias:$($a.Name)" -Force
	}
}

function Unregister-PoC
{	
	Clear-Environment
	
	foreach ($a in $script:Aliases)
	{	Write-Host "$($a.Name) <= $($a.ReferencedCommand)"
		if (Test-Path "Alias:$($a.Name)")
		{	Write-Host "$($a.Name) exists."			}
		else
		{	Set-Alias -Name $a.Name -Value $a.ReferencedCommand -Scope $a.Visibility		}
	}
	
	if (Test-Path Alias:env)		{	Remove-Item Alias:env		}
	if (Test-Path Alias:quit)		{	Remove-Item Alias:quit	}
	
	Remove-Module PoC
}

function Set-Environment
{	<#
		.SYNOPSIS
		Loads a vendor environment
		.DESCRIPTION
		undocumented
		.PARAMETER Environment
		The name of the environment
	#>
	[CmdletBinding()]
	param(
		[String] $Environment
	)
	Write-Host "Set-Environment to '$Environment'"
	Write-Host "Debug: CurrentEnvironment = '$($script:CurrentEnvironment.Name)'"
	if ($script:Environments.Contains($Environment))
	{	$env = $script:Environments[$Environment]
		
		# load the vendor module
		$ModulePath = $VendorModulePath + "\" + $env.PSModuleName + ".psm1"
		Import-Module $ModulePath -Scope Global
		
		# invoke register function
		Register-Environment
		
		$script:CurrentEnvironment = $env
	}
	else
	{	Write-Host "Unknown environment." -ForegroundColor Red		}
}

function Get-Environment
{	<#
		.SYNOPSIS
		Unloads a vendor environment
		.DESCRIPTION
		undocumented
	#>
	Write-Host "Get-Environment"
	return $script:CurrentEnvironment
}

function Clear-Environment
{	<#
		.SYNOPSIS
		Unloads a vendor environment
		.DESCRIPTION
		undocumented
	#>
	Write-Host "Clear-Environment"
	Write-Host "Debug: CurrentEnvironment = '$($script:CurrentEnvironment.Name)'"
	if ($script:CurrentEnvironment -ne $null)
	{	# invoke unregister function
		Unregister-Environment
		
		# unload vendor module
		Remove-Module $script:CurrentEnvironment.PSModuleName
		
		$script:CurrentEnvironment = $null
	}
	else
	{	Write-Host "No environment loaded."		}
}

function Switch-Environment
{	<#
		.SYNOPSIS
		Loads another vendor environment
		.DESCRIPTION
		undocumented
		.PARAMETER Environment
		The name of the environment
	#>
	[CmdletBinding()]
	param(
		[String]
		$Environment
	)
	if ($Environment -eq "")
	{	Clear-Environment		}
	else
	{	if ($script:CurrentEnvironment -ne $null)
		{	Clear-Environment		}
		Set-Environment $Environment
	}
}


Export-ModuleMember -Function 'Register-PoC'
Export-ModuleMember -Function 'Unregister-PoC'
Export-ModuleMember -Function 'Set-Environment'
Export-ModuleMember -Function 'Get-Environment'
Export-ModuleMember -Function 'Clear-Environment'
Export-ModuleMember -Function 'Switch-Environment'

Set-Alias -Name env -Value Switch-Environment -Description "Sets a vendor environment for PoC." -Scope Global
Set-Alias -Name quit -Value Unregister-PoC -Description "Unload this module." -Scope Global

Register-PoC
