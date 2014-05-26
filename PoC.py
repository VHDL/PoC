#!/usr/bin/python
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ============================================================================================================================================================
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
# ============================================================================================================================================================
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
# ============================================================================================================================================================

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

		self.printDebug("DEBUG: working directory: %s" % self.__workingDirectoryPath)
		self.printDebug("DEBUG: platform: %s" % platform.system())
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

		self.printDebug("working directory: %s" % self.__workingDirectoryPath)
		self.printDebug("platform: %s" % platform.system())
		print()
		
		if (self.__platform == 'Windows'):
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
			
			
			# Writing configuration to disc
			configFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocConfigFileName
			print("Writing configuration file to '%s'" % str(configFilePath))
			with configFilePath.open('w') as configFileHandle:
				self.__pocConfig.write(configFileHandle)
			
				
		elif (self.__platform == 'Linux'):
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
				
			if iseDirectoryPath.exists():
				print("ERROR: Xilinx ISE version '%s' is not installed." % iseVersion)
				return
			
			self.__pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
			self.__pocConfig['Xilinx-ISE']['Version'] = iseVersion
			self.__pocConfig['Xilinx-ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
			self.__pocConfig['Xilinx-ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/lin64'
		
			
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
