rem EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
rem vim: tabstop=2:shiftwidth=2:noexpandtab
rem kate: tab-width 2; replace-tabs off; indent-width 2;
rem 
rem ==============================================================================
rem	Bash Script:		Wrapper Script to execute a given python script
rem 
rem	Authors:				Patrick Lehmann
rem									Thomas B. Preusser
rem									Martin Zabel
rem 
rem Description:
rem ------------------------------------
rem	This is a bash script (callable) which:
rem		- 
rem		- 
rem		-
rem
rem License:
rem ==============================================================================
rem Copyright 2007-2014 Technische Universitaet Dresden - Germany
rem											Chair for VLSI-Design, Diagnostics and Architecture
rem 
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem 
rem		http://www.apache.org/licenses/LICENSE-2.0
rem 
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.
rem ==============================================================================

rem script settings
set POC_SCRIPTSDIR=py

rem goto PoC root directory and save this path
cd %POC_ROOTDIR_RELPATH%
for /f %%i in ('cd') do set POC_ROOTDIR_ABSPATH=%%i

if %POC_PYWRAPPER_DEBUG% == 1  (
	echo This is the PoC Library script wrapper operating in debug mode.
	echo ---------------------------------------------------------------
	echo Directories:
	echo   Script root:   %POC_PYWRAPPER_SCRIPTDIR%
	echo   PoC abs. root: %POC_ROOTDIR_ABSPATH%
	echo Script:
	echo   Filename:      %POC_PYWRAPPER_SCRIPT%
	echo   Parameters:    %POC_PYWRAPPER_PARAMS%
	echo Load Environment:
	echo   Xilinx ISE:    %POC_PYWRAPPER_LOADENV_ISE%
	echo   Xilinx VIVADO: %POC_PYWRAPPER_LOADENV_VIVADO%
	echo ---------------------------------------------------------------
)

rem find suitable python version or abort execution
set PYTHON_VERSIONTEST="import sys; sys.exit(not (0x03040000 < sys.hexversion < 0x04000000))"
python -c %PYTHON_VERSIONTEST% > nul
if %ERRORLEVEL% == 0 (
	set PYTHON_INTERPRETER=python
 	if %POC_PYWRAPPER_DEBUG% == 1 echo PythonInterpreter: use standard interpreter: '%PYTHON_INTERPRETER%'
) else (
	echo No suitable Python interpreter found.
	echo The script requires Python %POC_PYWRAPPER_MIN_VERSION%.
	
	cd %POC_PYWRAPPER_SCRIPTDIR%
	exit /B 1
)

cd %POC_ROOTDIR_ABSPATH%\%POC_SCRIPTSDIR%

if %POC_PYWRAPPER_LOADENV_ISE% == 1 (
	rem if $XILINX environment variable is not set
 	if not defined XILINX (
 		set command=%PYTHON_INTERPRETER% %POC_ROOTDIR_ABSPATH%\py\Configuration.py --ise-settingsfile
 		if %POC_PYWRAPPER_DEBUG% == 1 echo getting ISE settings file: command='%command%'
 		for /f %%i in ('%command%') do set iseSettingsFile=%%i
 		if %POC_PYWRAPPER_DEBUG% == 1 echo ISE settings file: '%iseSettingsFile%'
 		if %iseSettingsFile% == "" (
 			echo No Xilinx ISE installation found.
 			echo Run 'poc.py --configure' to configure your Xilinx ISE installation.
 			
			cd %POC_PYWRAPPER_SCRIPTDIR%
			exit /B 1
 		)
 		echo Loading Xilinx ISE environment '%iseSettingsFile%'
 		call %iseSettingsFile%
 	)
)

rem TODO: add Vivado support here


rem execute script with appropriate python interpreter and all given parameters
if %POC_PYWRAPPER_DEBUG% == 1 (
	echo cd %POC_ROOTDIR_ABSPATH%\%POC_SCRIPTSDIR%
	echo launching: '%PYTHON_INTERPRETER% %POC_PYWRAPPER_SCRIPT% %POC_PYWRAPPER_PARAMS%'
	echo ------------------------------------------------------------
)

%PYTHON_INTERPRETER% %POC_PYWRAPPER_SCRIPT% %POC_PYWRAPPER_PARAMS%

rem go back to script dir
cd %POC_PYWRAPPER_SCRIPTDIR%