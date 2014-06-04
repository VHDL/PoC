#! /bin/sh
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Main Module:  Entry point to configure the local copy of this PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - configures the PoC Library to your local environment,
#    - ...
#
# License:
# ==============================================================================
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

""":"
# this is a python bootloader written in bash to load the minimal required python version
# Source:		https://github.com/apache/cassandra/blob/trunk/bin/cqlsh
# License:	Apache License-2.0
#
# use default python version (/usr/bin/python) if >= 3.4.0
python -c 'import sys; sys.exit(not (0x03040000 < sys.hexversion < 0x04000000))' 2>/dev/null && exec python "$0" "$@"
# try to load highest installed python version first
for pyversion in 3.9 3.8 3.7 3.6 3.5 3.4; do
	which python$pyversion > /dev/null 2>&1 && exec python$pyversion "$0" "$@"
done
# if no suitable version is installed, write error message to STDERR and exit
echo "No appropriate python version found." >&2
exit 1
":"""

import argparse
import configparser
import os
import pathlib
import platform
import re
import string
import sys
import textwrap

class PoCConfiguration:
	__workingDirectoryPath = None
	__debug = False
	__verbose = False
	__platform = ""
	
	__pythonFilesDirectory = "py"
	__pocConfigFileName = "configuration.ini"
	__pocStructureFileName = "structure.ini"
	
	__pocConfig = None
	__pocStructure = None
	
	def __init__(self, debug, verbose):
		self.__workingDirectoryPath = pathlib.Path.cwd()
		self.__debug = debug
		self.__verbose = verbose
		self.__platform = platform.system()
		
		configFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocConfigFileName
		if configFilePath.exists():
			if (self.__debug):
				print("DEBUG: reading configuration file: %s" % configFilePath)
			
			self.__pocConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
			self.__pocConfig.optionxform = str
			self.__pocConfig.read(str(configFilePath))
		else:
			if (self.__verbose):
				print("configuration file does not exists; creating a new one")
			
			self.__pocConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
			self.__pocConfig.optionxform = str
			self.__pocConfig['PoC'] = {
				'Version' : '0.0.0',
				'InstallationDirectory' : self.__workingDirectoryPath.as_posix(),
				'SourceFilesDirectory' : '${InstallationDirectory}/src',
				'TestbenchFilesDirectory' : '${InstallationDirectory}/tb',
				'TempFilesDirectory' : '${InstallationDirectory}/temp',
				'iSimFilesDirectory' : '${InstallationDirectory}/isim'
			}
			self.__pocConfig['Xilinx'] = {
				'InstallationDirectory' : '????'
			}
			self.__pocConfig['Xilinx-ISE'] = {
				'Version' : '????',
				'InstallationDirectory' : '${Xilinx:InstallationDirectory}/${Version}/ISE_DS',
				'BinaryDirectory' : '${InstallationDirectory}/ISE/bin/????64'
			}
			self.__pocConfig['Xilinx-Vivado'] = {
				'Version' : '????',
				'InstallationDirectory' : '${Xilinx:InstallationDirectory}/Vivado/${Version}',
				'BinaryDirectory' : '${InstallationDirectory}/bin'
			}
			self.__pocConfig['Altera-QuartusII'] = {
#				'Version' : '',
#				'InstallationDirectory' : '${Xilinx:InstallationDirectory}\Vivado\${Version}',
#				'BinaryDirectory' : '${InstallationDirectory}\bin'
			}
			self.__pocConfig['Altera-ModelSim'] = {
#				'Version' : '',
#				'InstallationDirectory' : '${Xilinx:InstallationDirectory}\Vivado\${Version}',
#				'BinaryDirectory' : '${InstallationDirectory}\bin'
			}
			self.__pocConfig['Mentor-ModelSim'] = {
#				'Version' : '',
#				'InstallationDirectory' : '${Xilinx:InstallationDirectory}\Vivado\${Version}',
#				'BinaryDirectory' : '${InstallationDirectory}\bin'
			}
			self.__pocConfig['GHDL'] = {
				'Version' : '0.31',
				'InstallationDirectory' : '????/GHDL/${Version}',
				'BinaryDirectory' : '${InstallationDirectory}/bin'
			}
			self.__pocConfig['GTKWave'] = {
#				'Version' : '',
#				'InstallationDirectory' : '${Xilinx:InstallationDirectory}\Vivado\${Version}',
#				'BinaryDirectory' : '${InstallationDirectory}\bin'
			}

			# Writing configuration to disc
			with configFilePath.open('w') as configFileHandle:
				self.__pocConfig.write(configFileHandle)
			
			if (self.__debug):
				print("DEBUG: new configuration file created: %s" % configFilePath)
	
	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)
	
	def autoConfiguration(self):
		self.printVerbose("starting auto configuration...")

		self.printDebug("working directory: %s" % self.__workingDirectoryPath)
		self.printDebug("platform: %s" % platform.system())
		print()
		
		if (self.__platform == 'Windows'):
			if (os.getenv('XILINX') != None):
				print("env: XILINX = %s" % os.getenv('XILINX'))
				
				
				
				
		elif (self.__platform == 'Linux'):
			if (os.getenv('XILINX') != None):
				print("env: XILINX = %s" % os.getenv('XILINX'))
		
		else:
			print("Unknown platform")
		#print(self.__pocConfig.get("Xilinx_ISE", "InstallDirectory"))
	
	def manualConfiguration(self):
		self.printVerbose("starting manual configuration...")
		print('Explanation of abbreviations:')
		print('  y - yes')
		print('  n - no')
		print('  p - pass (jump to next question)')
		print('Upper case means default value')
		print()
		
		if (self.__platform == 'Windows'):
			# Ask for installed Xilinx ISE
			isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
			isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
			if (isXilinxISE != 'p'):
				if (isXilinxISE == 'Y'):
					xilinxDirectory = input('Xilinx Installation Directory [C:\Xilinx]: ')
					iseVersion = input('Xilinx ISE Version Number [14.7]: ')
					print()
				
					xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "C:\Xilinx"
					iseVersion = iseVersion if iseVersion != "" else "14.7"
				
					xilinxDirectoryPath = pathlib.Path(xilinxDirectory)
					iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"
				
					if not xilinxDirectoryPath.exists():
						print("ERROR: Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
						return
				
					if not iseDirectoryPath.exists():
						print("ERROR: Xilinx ISE version '%s' is not installed." % iseVersion)
						return
				
					self.__pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
					self.__pocConfig['Xilinx-ISE']['Version'] = iseVersion
					self.__pocConfig['Xilinx-ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
					self.__pocConfig['Xilinx-ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/nt64'
				elif (isXilinxISE == 'n'):
					self.__pocConfig['Xilinx-ISE'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Ask for installed Xilinx Vivado
			isXilinxVivado = input('Is Xilinx Vivado installed on your system? [Y/n/p]: ')
			isXilinxVivado = isXilinxVivado if isXilinxVivado != "" else "Y"
			if (isXilinxVivado != 'p'):
				if (isXilinxVivado == 'Y'):
					xilinxDirectory = input('Xilinx Installation Directory [C:\Xilinx]: ')
					vivadoVersion = input('Xilinx Vivado Version Number [2014.1]: ')
					print()
				
					xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "C:\Xilinx"
					vivadoVersion = vivadoVersion if vivadoVersion != "" else "2014.1"
				
					xilinxDirectoryPath = pathlib.Path(xilinxDirectory)
					vivadoDirectoryPath = xilinxDirectoryPath / "Vivado" / vivadoVersion
				
					if not xilinxDirectoryPath.exists():
						print("ERROR: Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
						return
				
					if not vivadoDirectoryPath.exists():
						print("ERROR: Xilinx Vivado version '%s' is not installed." % vivadoVersion)
						return
				
					self.__pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
					self.__pocConfig['Xilinx-Vivado']['Version'] = vivadoVersion
					self.__pocConfig['Xilinx-Vivado']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/Vivado/${Version}'
					self.__pocConfig['Xilinx-Vivado']['BinaryDirectory'] = '${InstallationDirectory}/bin'
				elif (isXilinxVivado == 'n'):
					self.__pocConfig['Xilinx-Vivado'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Ask for installed GHDL
			isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
			isGHDL = isGHDL if isGHDL != "" else "Y"
			if (isGHDL != 'p'):
				if (isGHDL == 'Y'):
					ghdlDirectory = input('GHDL Installation Directory [C:\Program Files (x86)\GHDL]: ')
					ghdlVersion = input('GHDL Version Number [0.31]: ')
					print()
				
					ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "C:\Program Files (x86)\GHDL"
					ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"
				
					ghdlDirectoryPath = pathlib.Path(ghdlDirectory)
					ghdlExecutablePath = ghdlDirectoryPath / "bin" / "ghdl.exe"
				
					if not ghdlDirectoryPath.exists():
						print("ERROR: GHDL Installation Directory '%s' does not exist." % ghdlDirectory)
						return
				
					if not ghdlExecutablePath.exists():
						print("ERROR: GHDL is not installed.")
						return
				
					self.__pocConfig['GHDL']['Version'] = ghdlVersion
					self.__pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
					self.__pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}/bin'
				elif (isGHDL == 'n'):
					self.__pocConfig['GHDL'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Writing configuration to disc
			configFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocConfigFileName
			print("Writing configuration file to '%s'" % str(configFilePath))
			with configFilePath.open('w') as configFileHandle:
				self.__pocConfig.write(configFileHandle)
			
		elif (self.__platform == 'Linux'):
			# Ask for installed Xilinx ISE
			isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
			isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
			if (isXilinxISE != 'p'):
				if (isXilinxISE == 'Y'):
					xilinxDirectory = input('Xilinx Installation Directory [/opt/xilinx]: ')
					iseVersion = input('Xilinx ISE Version Number [14.7]: ')
					print()
				
					xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "/opt/xilinx"
					iseVersion = iseVersion if iseVersion != "" else "14.7"
				
					xilinxDirectoryPath = pathlib.Path(xilinxDirectory)
					iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"
				
					if not xilinxDirectoryPath.exists():
						print("ERROR: Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
						return
				
					if not iseDirectoryPath.exists():
						print("ERROR: Xilinx ISE version '%s' is not installed." % iseVersion)
						return
				
					self.__pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
					self.__pocConfig['Xilinx-ISE']['Version'] = iseVersion
					self.__pocConfig['Xilinx-ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
					self.__pocConfig['Xilinx-ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/lin64'
				elif (isXilinxISE == 'n'):
					self.__pocConfig['Xilinx-ISE'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Ask for installed Xilinx Vivado
			isXilinxVivado = input('Is Xilinx Vivado installed on your system? [Y/n/p]: ')
			isXilinxVivado = isXilinxVivado if isXilinxVivado != "" else "Y"
			if (isXilinxVivado != 'p'):
				if (isXilinxVivado == 'Y'):
					xilinxDirectory = input('Xilinx Installation Directory [/opt/xilinx]: ')
					vivadoVersion = input('Xilinx Vivado Version Number [2014.1]: ')
					print()
				
					xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "/opt/xilinx"
					vivadoVersion = vivadoVersion if vivadoVersion != "" else "2014.1"
				
					xilinxDirectoryPath = pathlib.Path(xilinxDirectory)
					vivadoDirectoryPath = xilinxDirectoryPath / "vivado" / vivadoVersion
				
					if not xilinxDirectoryPath.exists():
						print("ERROR: Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
						return
				
					if not vivadoDirectoryPath.exists():
						print("ERROR: Xilinx Vivado version '%s' is not installed." % vivadoVersion)
						return
				
					self.__pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
					self.__pocConfig['Xilinx-Vivado']['Version'] = vivadoVersion
					self.__pocConfig['Xilinx-Vivado']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/vivado/${Version}'
					self.__pocConfig['Xilinx-Vivado']['BinaryDirectory'] = '${InstallationDirectory}/bin'
				elif (isXilinxVivado == 'n'):
					self.__pocConfig['Xilinx-Vivado'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Ask for installed GHDL
			isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
			isGHDL = isGHDL if isGHDL != "" else "Y"
			if (isGHDL != 'p'):
				if (isGHDL == 'Y'):
					ghdlDirectory = input('GHDL Installation Directory [/usr/bin]: ')
					ghdlVersion = input('GHDL Version Number [0.31]: ')
					print()
				
					ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "/usr/bin"
					ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"
				
					ghdlDirectoryPath = pathlib.Path(ghdlDirectory)
					ghdlExecutablePath = ghdlDirectoryPath / "ghdl"
				
					if not ghdlDirectoryPath.exists():
						print("ERROR: GHDL Installation Directory '%s' does not exist." % ghdlDirectory)
						return
				
					if not ghdlExecutablePath.exists():
						print("ERROR: GHDL is not installed.")
						return
				
					self.__pocConfig['GHDL']['Version'] = ghdlVersion
					self.__pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
					self.__pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}'
				elif (isGHDL == 'n'):
					self.__pocConfig['GHDL'] = {}
				else:
					print("ERROR: unknown option")
					return
			
			# Writing configuration to disc
			configFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocConfigFileName
			print("Writing configuration file to '%s'" % str(configFilePath))
			with configFilePath.open('w') as configFileHandle:
				self.__pocConfig.write(configFileHandle)
		
		else:
			print("ERROR: Unknown platform")
			return

	
# main program
def main():
	print("========================================================================")
	print("                  PoC Library - Repository Service Tool                 ")
	print("========================================================================")
	print()
	
	try:
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Repository Service Tool.
				'''))

		# add arguments
#		argParser.add_argument("file", help="Specify the assembler log file.")
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('--configure', action='store_const', const=True, default=False, help='configures PoC Library')
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("Exception: %s" % ex.__str__())

	if args.configure:
		config = PoCConfiguration(args.d, args.v)
		#config.autoConfiguration()
		config.manualConfiguration()
	else:
		argParser.print_help()

		
	
# entry point
if __name__ == "__main__":
	main()
else:
	print("========================================================================")
	print("                  PoC Library - Repository Service Tool                 ")
	print("========================================================================")
	print()
	print("This is no library file!")
