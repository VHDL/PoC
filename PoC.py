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
	
	__pythonFilesDirectory = "py"
	__configFileName = "poc_config.ini"
	__config = None
	
	def __init__(self, debug, verbose):
		self.__workingDirectoryPath = pathlib.Path.cwd()
		self.__debug = debug
		self.__verbose = verbose
		
		configFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__configFileName
		if configFilePath.exists():
			if (self.__debug):
				print("DEBUG: reading configuration file: %s" % configFilePath)
			
			self.__config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
			self.__config.read(str(configFilePath))
		else:
			if (self.__verbose):
				print("configuration file does not exists; creating a new one")
			
			self.__config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
			self.__config['PoC'] = {
				'InstallationDirectory' : str(self.__workingDirectoryPath),
				'Version' : '0.0.0'
			}
			self.__config['Xilinx_ISE'] = {
				'InstallationDirectory' : '',
				'Version' : ''
			}
			self.__config['Xilinx_Vivado'] = {
				'InstallationDirectory' : '',
				'Version' : ''
			}
			self.__config['Altera_QuartusII'] = {
				'InstallationDirectory' : '',
				'Version' : ''
			}
			self.__config['GHDL'] = {
				'InstallationDirectory' : '',
				'Version' : ''
			}
			self.__config['GTKWave'] = {
				'InstallationDirectory' : '',
				'Version' : ''
			}

			# Writing configuration to disc
			with configFilePath.open('w') as configFileHandle:
				self.__config.write(configFileHandle)
			
			if (self.__debug):
				print("DEBUG: new configuration file created: %s" % configFilePath)
			
	def autoConfiguration(self):
		if (self.__verbose):
			print("starting auto configuration...")

		if (self.__debug):
			print("DEBUG: working directory: %s" % self.__workingDirectoryPath)
			print("DEBUG: platform: %s" % platform.system())
			print()
		
		if (platform.system() == 'Windows'):
			if (os.getenv('XILINX') != None):
				print("env: XILINX = %s" % os.getenv('XILINX'))
				
				
				
				
		elif (platform.system() == 'Linux'):
			if (os.getenv('XILINX') != None):
				print("env: XILINX = %s" % os.getenv('XILINX'))
		
		else:
			print("Unknown platform")
		#print(self.__config.get("Xilinx_ISE", "InstallDirectory"))
	
				
	
# main program
def main():
	print("PoC Library - Repository Service Tool")
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
		config.autoConfiguration()
	else:
		argParser.print_help()

		
	
# entry point
if __name__ == "__main__":
	main()
else:
	print("PoC Library - Repository Service Tool")
	print("========================================================================")
	print()
	print("This is no library file!")
