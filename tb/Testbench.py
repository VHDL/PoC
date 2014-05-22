#!/usr/bin/python
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ============================================================================================================================================================
# Python Main Module:  Entry point to the testbench tools in PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - runs automated testbenches,
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
import subprocess
import sys
import textwrap

class PoCTestbench:
	__debug = False
	__verbose = False

	__pocDirectoryPath = None
	__workingDirectoryPath = None
	
	__pythonFilesDirectory = "../py"		# relative to working directory
	__sourceFilesDirectory = "src"			# relative to PoC root directory
	__tempFilesDirectory = "temp"				# relative to PoC root directory
	__isimFilesDirectory = "isim"				# relative to temp directory
	
	__pocConfigFileName = "configuration.ini"
	__pocStructureFileName = "structure.ini"
	__tbConfigFileName = "configuration.ini"
	
	__pocConfig = None
	__pocStructure = None
	__tbConfig = None
	
	def __init__(self, debug, verbose):
		self.__debug = debug
		self.__verbose = verbose
		
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
		self.__pocConfig.read(str(pocConfigFilePath))
		
		# parsing values into class fields
		self.__pocDirectoryPath = pathlib.Path(self.__pocConfig['PoC']['InstallationDirectory'])

		
		# read PoC structure
		# =========================================================================================================================================================
		pocStructureFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocStructureFileName
		if not pocStructureFilePath.exists():
			print("ERROR: PoC structure file does not exist. (%s)" % str(pocStructureFilePath))
			print()
			return
			
		self.printDebug("reading PoC structure file: %s" % str(pocStructureFilePath))
			
		self.__pocStructure = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__pocStructure.read(str(pocConfigFilePath))
		
		
		# read Simulation configuration
		# =========================================================================================================================================================
		tbConfigFilePath = self.__workingDirectoryPath / self.__tbConfigFileName
		if not tbConfigFilePath.exists():
			print("ERROR: Simulation configuration file does not exist. (%s)" % str(tbConfigFilePath))
		self.printDebug("reading Simulation configuration file: %s" % str(tbConfigFilePath))
			
		self.__tbConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__tbConfig.read([str(pocConfigFilePath), str(pocStructureFilePath), str(tbConfigFilePath)])
		
	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)

			
	def isimSimulation(self, module):
		temp = module.split('_', 1)
		namespacePrefix = temp[0]
		moduleName = temp[1]
		fullNamespace = self.getNamespaceForPrefix(namespacePrefix)
		
		print("Preparing simulation environment for '%s.%s'" % (fullNamespace, moduleName))
		tempIsimPath = self.__pocDirectoryPath / self.__tempFilesDirectory / self.__isimFilesDirectory
		if not (tempIsimPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("temporary directors: %s" % str(tempIsimPath))
			tempIsimPath.mkdir(parents=True)

		print()
		print("Commands to be run:")
			
		if (self.__verbose):
			print("1. Change working directory to temporary directory")
			print("2. Compile source files")
			print("3. Link compiled files to an executable simulation file")
			print("4. Simulate in tcl batch mode")
			print()
			
		print("cd %s" % str(tempIsimPath))
		print("%s\\vhpcomp -prj %s" % (self.__pocConfig['Xilinx-ISE']['BinaryDirectory'], self.__tbConfig[fullNamespace][(module + '.iSimProjectFile')]))
		print("%s\\fuse work.%s -prj %s -o %s" % (
			self.__pocConfig['Xilinx-ISE']['BinaryDirectory'],
			self.__tbConfig[fullNamespace][(module + '.TestbenchModule')],
			self.__tbConfig[fullNamespace][(module + '.iSimProjectFile')],
			self.__tbConfig[fullNamespace][(module + '.TestbenchModule')] + ".exe"
			))
		print("%s\\%s -tclbatch %s" % (
			str(tempIsimPath),
			self.__tbConfig[fullNamespace][(module + '.TestbenchModule')] + ".exe",
			self.__tbConfig[fullNamespace][(module + '.iSimTclScript')]))
		print()

		os.chdir(str(tempIsimPath))
		
#		compilerLog = subprocess.check_output([
#			str(pathlib.Path(self.__pocConfig['Xilinx-ISE']['BinaryDirectory']) / "vhpcomp"),
#			"-prj",
#			str(pathlib.Path(self.__tbConfig[fullNamespace][(module + '.iSimProjectFile')]))
#			],
#			stderr=subprocess.STDOUT, universal_newlines=True)
#		
#		print("Compiler Log (vhpcomp)")
#		print("--------------------------------------------------------------------------------")
#		print(compilerLog)
#		print("--------------------------------------------------------------------------------")
		
		linkerLog = subprocess.check_output([
			str(pathlib.Path(self.__pocConfig['Xilinx-ISE']['BinaryDirectory']) / "fuse"),
			("work.%s" % self.__tbConfig[fullNamespace][(module + '.TestbenchModule')]),
			"-prj",
			str(pathlib.Path(self.__tbConfig[fullNamespace][(module + '.iSimProjectFile')])),
			"-o",
			str(pathlib.Path(self.__tbConfig[fullNamespace][(module + '.TestbenchModule')] + ".exe"))
			],
			stderr=subprocess.STDOUT, universal_newlines=True)
		
		print("Linker Log (fuse)")
		print("--------------------------------------------------------------------------------")
		print(linkerLog)
#		print("--------------------------------------------------------------------------------")
		
		simulatorLog = subprocess.check_output([
			str(pathlib.Path(self.__tbConfig[fullNamespace][(module + '.TestbenchModule')] + ".exe")),
			"-tclbatch",
			str(pathlib.Path(self.__tbConfig[fullNamespace][(module + '.iSimTclScript')]))
			],
			stderr=subprocess.STDOUT, universal_newlines=True)
		
		print()
		print("Simulator Log")
		print("--------------------------------------------------------------------------------")
		print(simulatorLog)
		print("--------------------------------------------------------------------------------")		
		
	def getNamespaceForPrefix(self, namespacePrefix):
		return self.__tbConfig['NamespacePrefixes'][namespacePrefix]
	
# main program
def main():
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	
	try:
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Testbench Service Tool.
				'''))

		# add arguments
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('--isim', action='store_const', const=True, default=False, help='use Xilinx ISE Simulator (iSim)')
		argParser.add_argument('--vsim', action='store_const', const=True, default=False, help='use Mentor Graphics ModelSim (vSim)')
		argParser.add_argument('--ghdl', action='store_const', const=True, default=False, help='use GHDL Simulator (ghdl)')
		argParser.add_argument("module", help="Specify the module which should be tested.")
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("Exception: %s" % ex.__str__())

	test = PoCTestbench(args.d, args.v)
	
	if args.configure:
		test.readNamespaceStructure()
	elif args.isim:
		test.isimSimulation(args.module)
	elif args.vsim:
		test.vsimSimulation(args.module)
	elif args.ghdl:
		test.ghdlSimulation(args.module)
	else:
		argParser.print_help()
	
# entry point
if __name__ == "__main__":
	main()
else:
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	print("This is no library file!")
