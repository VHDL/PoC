# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	PowerShell Script:	Wrapper Script to execute a given python script
# 
#	Authors:				 		Patrick Lehmann
# 
# Description:
# ------------------------------------
#	This is a PowerShell script (callable) which:
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
$PoC_ExitCode = 0
$PoC_ScriptDir = "py"

# goto PoC root directory and save this path
Set-Location $PoC_RootDir_RelPath
$PoC_RootDir_AbsPath = Get-Location

# publish PoC root directory as environment variable
$env:PoCRootDirectory = $PoC_RootDir_AbsPath

if ($PoC_PyWrapper_Debug -eq $true ) {
	Write-Host "This is the PoC Library script wrapper operating in debug mode." -ForegroundColor Yellow
	Write-Host ""
	Write-Host "Directories:" -ForegroundColor Yellow
	Write-Host "  Script root:   $PoC_PyWrapper_ScriptDir" -ForegroundColor Yellow
	Write-Host "  PoC abs. root: $PoC_RootDir_AbsPath" -ForegroundColor Yellow
	Write-Host "Script:" -ForegroundColor Yellow
	Write-Host "  Filename:      $PoC_PyWrapper_Script" -ForegroundColor Yellow
	Write-Host "  Parameters:    $PoC_PyWrapper_Paramters" -ForegroundColor Yellow
	Write-Host "Load Environment:" -ForegroundColor Yellow
	Write-Host "  Xilinx ISE:    $PoC_PyWrapper_LoadEnv_ISE" -ForegroundColor Yellow
	Write-Host "  Xilinx VIVADO: $PoC_PyWrapper_LoadEnv_Vivado" -ForegroundColor Yellow
	Write-Host ""
}

# find suitable python version or abort execution
$Python_VersionTest = 'py.exe -3 -c "import sys; sys.exit(not (0x03040000 < sys.hexversion < 0x04000000))"'
Invoke-Expression $Python_VersionTest | Out-Null
if ($LastExitCode -eq 0) {
    $Python_Interpreter = "py.exe"
		$Python_Parameters =	(, "-3")
 	if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "PythonInterpreter: '$Python_Interpreter $Python_Parameters'" -ForegroundColor Yellow }
} else {
    Write-Host "ERROR: No suitable Python interpreter found." -ForegroundColor Red
    Write-Host "The script requires Python $PoC_PyWrapper_MinVersion." -ForegroundColor Yellow
    $PoC_ExitCode = 1
}

# load environments if needed and no error occurred
if ($PoC_ExitCode -eq 0) {
	# goto script directory
	if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "cd $PoC_RootDir_AbsPath\$PoC_ScriptDir" -ForegroundColor Yellow }
	Set-Location $PoC_RootDir_AbsPath\$PoC_ScriptDir
}

if ($PoC_ExitCode -eq 0) {
	# load Xilinx ISE environment if not loaded before
	if ($PoC_PyWrapper_LoadEnv_ISE -eq $true) {
		if (-not (Test-Path env:XILINX)) {
			$PoC_Command = "$Python_Interpreter $Python_Parameters $PoC_RootDir_AbsPath\$PoC_ScriptDir\Configuration.py --ise-settingsfile"
			if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "Getting ISE settings file: command='$PoC_Command'" -ForegroundColor Yellow }

			# execute python script to receive ISE settings filename
			$PoC_ISE_SettingsFile = Invoke-Expression $PoC_Command
			if ($LastExitCode -eq 0) {
				if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "ISE settings file: '$PoC_ISE_SettingsFile'" }
				if ($PoC_ISE_SettingsFile -eq "") {
					Write-Host "ERROR: No Xilinx ISE installation found." -ForegroundColor Red
					Write-Host "Run 'poc.ps1 --configure' to configure your Xilinx ISE installation." -ForegroundColor Yellow
					$PoC_ExitCode = 1
				} else {
					Write-Host "Loading Xilinx ISE environment '$PoC_ISE_SettingsFile'" -ForegroundColor Yellow
					if (($PoC_ISE_SettingsFile -like "*.bat") -or ($PoC_ISE_SettingsFile -like "*.cmd")) {
						Import-Module PSCX
						Invoke-BatchFile -path $PoC_ISE_SettingsFile
					} else {
						. $PoC_ISE_SettingsFile
					}
				}
			} else {
				Write-Host "ERROR: ExitCode for '$PoC_Command' was not zero. Aborting script execution" -ForegroundColor Red
				Write-Host $PoC_ISE_SettingsFile -ForegroundColor Red
				$PoC_ExitCode = 1
			}
		}
	}
}

if ($PoC_ExitCode -eq 0) {
	# load Xilinx Vivado environment if not loaded before
	if ($PoC_PyWrapper_LoadEnv_Vivado -eq $true) {
		if (-not (Test-Path env:XILINX)) {
			$PoC_Command = "$Python_Interpreter $Python_Parameters $PoC_RootDir_AbsPath\$PoC_ScriptDir\Configuration.py --vivado-settingsfile"
			if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "Getting Vivado settings file: command='$PoC_Command'" -ForegroundColor Yellow }

			# execute python script to receive ISE settings filename
			$PoC_Vivado_SettingsFile = Invoke-Expression $PoC_Command
			if ($LastExitCode -eq 0) {
				if ($PoC_PyWrapper_Debug -eq $true) { Write-Host "Vivado settings file: '$PoC_ISE_SettingsFile'" }
				if ($PoC_Vivado_SettingsFile -eq "") {
					Write-Host "ERROR: No Xilinx Vivado installation found." -ForegroundColor Red
					Write-Host "Run 'poc.ps1 --configure' to configure your Xilinx Vivado installation." -ForegroundColor Yellow
					$PoC_ExitCode = 1
				} else {
					Write-Host "Loading Xilinx Vivado environment '$PoC_Vivado_SettingsFile'" -ForegroundColor Yellow
					if (($PoC_Vivado_SettingsFile -like "*.bat") -or ($PoC_Vivado_SettingsFile -like "*.cmd")) {
						Import-Module PSCX
						Invoke-BatchFile -path $PoC_Vivado_SettingsFile
					} else {
						. $PoC_Vivado_SettingsFile
					}
				}
			} else {
				Write-Host "ERROR: ExitCode for '$PoC_Command' was not zero. Aborting script execution" -ForegroundColor Red
				$PoC_ExitCode = 1
			}
		}
	}
}

if ($PoC_ExitCode -eq 0) {
	# execute script with appropriate python interpreter and all given parameters
	if ($PoC_PyWrapper_Debug -eq $true) {
		Write-Host "launching: '$PYTHON_INTER $PoC_PyWrapper_SCRIPT $PoC_PyWrapper_PARAMS'" -ForegroundColor Yellow
		Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
	}

	# launch python script
	Invoke-Expression "$Python_Interpreter $Python_Parameters $PoC_PyWrapper_Script $PoC_PyWrapper_Paramters"
}

# go back to script dir
Set-Location $PoC_PyWrapper_ScriptDir

# clean up
$env:PoCRootDirectory = $null
