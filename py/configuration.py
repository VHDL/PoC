# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Main Module:  Entry point to the testbench tools in PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - returns settings, paths and variables from PoC configuration and PoC structure
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

import argparse
import configparser
import os
import pathlib
import platform
import re
import string
import subprocess
import sys
import textwrap

class PoCBootloader:
	__debug = False
	__platform = ""

	__pocDirectoryPath = None
	__workingDirectoryPath = None
	
	__pythonFilesDirectory = "../py"		# relative to working directory
	__pocConfigFileName = "configuration.ini"
	
	__pocConfig = None
	
	def __init__(self, debug):
		self.__debug = debug
		self.__platform = platform.system()
		
		self.__workingDirectoryPath = pathlib.Path.cwd()
		
		# read PoC configuration
		# =========================================================================================================================================================
		pocConfigFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocConfigFileName
		if not pocConfigFilePath.exists():
			print("ERROR: PoC configuration file does not exist. (%s)" % str(pocConfigFilePath))
			print()
			print("Please run PoC.py --configure in PoC root directory.")
			return
			
		self.printDebug("reading PoC configuration file: %s" % str(pocConfigFilePath))
			
		self.__pocConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__pocConfig.optionxform = str
		self.__pocConfig.read(str(pocConfigFilePath))
		
		# parsing values into class fields
		self.__pocDirectoryPath = pathlib.Path(self.__pocConfig['PoC']['InstallationDirectory'])
		
	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def getISESettingsFile(self):
		if (len(self.__pocConfig.options("Xilinx-ISE")) == 0):
			print("ERROR: Xilinx ISE is not configured on this system.")
			print("Run 'poc.py --configure' to configure your Xilinx ISE environment.")
			return
		
		iseInstallationDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['InstallationDirectory'])
		iseBinaryDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['BinaryDirectory'])
		
		print(str(iseInstallationDirectoryPath / "settings64.sh"))
		return
		
	def getVivadoSettingsFile(self):
		print("ERROR: not implemented!")
		return
	
# main program
def main():
	if (cmpVersion(sys.version_info, [3,4,0]) < 0):
		print("ERROR: Used Python is to old: %s" % sys.version)
		print("Minimal required Python version is 3.4.0")
		return
	
	try:
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Bootloader.
				'''))

		# add arguments
		argParser.add_argument('-d',										action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('--ise-settingsfile',		action='store_const', const=True, default=False, help='Return Xilinx ISE settings file')
		argParser.add_argument('--vivado-settingsfile', action='store_const', const=True, default=False, help='Return Xilinx Vivado settings file')
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("Exception: %s" % ex.__str__())

	print(dir(args))
	return
		
	boot = PoCBootloader(args.d)
	
	if args.ise:
		boot.getISESettingsFile()
	elif args.vivado:
		boot.getVivadoSettingsFile()
	else:
		argParser.print_help()

def cmpVersion(version1, version2):
	if (version1.major > version2[0]):
		return 1
	elif (version1.major == version2[0]):
		if (version1.minor > version2[1]):
			return 1
		elif (version1.minor == version2[1]):
			if (version1.micro > version2[2]):
				return 1
			elif (version1.micro == version2[2]):
				return 0
			else:
				return -1
		else:
			return -1
	else:
		return -1


# entry point
if __name__ == "__main__":
	main()
else:
	print("========================================================================")
	print("                  PoC Library - Bootloader                              ")
	print("========================================================================")
	print()
	print("This is no library file!")
