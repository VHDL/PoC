@echo off
rem EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
rem vim: tabstop=2:shiftwidth=2:noexpandtab
rem kate: tab-width 2; replace-tabs off; indent-width 2;
rem 
rem ==============================================================================
rem	Bash Script:		Wrapper Script to execute <PoC-Root>/py/Configuration.py
rem 
rem	Authors:				Patrick Lehmann
rem 
rem Description:
rem ------------------------------------
rem	This is a bash wrapper script (executable) which:
rem		- saves the current working directory as an environment variable
rem		- delegates the call to <PoC-Root>/py/wrapper.sh
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

rem configure wrapper here
set POC_ROOTDIR_RELPATH=.
set POC_PYWRAPPER_SCRIPT=Configuration.py
set POC_PYWRAPPER_MIN_VERSION=3.4.0

rem save parameters and current working directory
set POC_PYWRAPPER_PARAMS=%*
set POC_PYWRAPPER_SCRIPTDIR=%~dp0
set POC_PYWRAPPER_SCRIPTDIR=%POC_PYWRAPPER_SCRIPTDIR:~0,-1%

rem search parameters for specific options like '-D' to enable batch script debug mode
echo %POC_PYWRAPPER_PARAMS% | find "-D" > nul
if %ERRORLEVEL% == 0 ( set POC_PYWRAPPER_DEBUG=1 ) else ( set POC_PYWRAPPER_DEBUG=0 )

set POC_PYWRAPPER_LOADENV_ISE=0
set POC_PYWRAPPER_LOADENV_VIVADO=0

rem call %POC_ROOTDIR_RELPATH%\py\wrapper.cmd
call %POC_ROOTDIR_RELPATH%\py\wrapper.cmd

rem unset all variables
set POC_ROOTDIR_RELPATH=
set POC_PYWRAPPER_SCRIPT=
set POC_PYWRAPPER_MIN_VERSION=
set POC_PYWRAPPER_PARAMS=
set POC_PYWRAPPER_SCRIPTDIR=
set POC_PYWRAPPER_SCRIPTDIR=
set POC_PYWRAPPER_DEBUG=
set POC_PYWRAPPER_LOADENV_ISE=
set POC_PYWRAPPER_LOADENV_VIVADO=

if %POC_EXITCODE% == 1 (
	set POC_EXITCODE=
	exit /B 1
) else (
	set POC_EXITCODE=
)
@echo on
