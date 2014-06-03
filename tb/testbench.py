#!/usr/bin/python3.4
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
#    - runs automated testbenches,
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

class PoCTestbench:
	__debug = False
	__verbose = False
	__platform = ""

	__pocDirectoryPath = None
	__workingDirectoryPath = None
	
	__pythonFilesDirectory = "../py"		# relative to working directory
	__sourceFilesDirectory = "src"			# relative to PoC root directory
	__tempFilesDirectory = "temp"				# relative to PoC root directory
	__isimFilesDirectory = "isim"				# relative to temp directory
	__ghdlFilesDirectory = "ghdl"				# relative to temp directory
	
	__pocConfigFileName = "configuration.ini"
	__pocStructureFileName = "structure.ini"
	__tbConfigFileName = "configuration.ini"
	
	__pocConfig = None
	__pocStructure = None
	__tbConfig = None
	
	def __init__(self, debug, verbose):
		self.__debug = debug
		self.__verbose = verbose
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

		
		# read PoC structure
		# =========================================================================================================================================================
		pocStructureFilePath = self.__workingDirectoryPath / self.__pythonFilesDirectory / self.__pocStructureFileName
		if not pocStructureFilePath.exists():
			print("ERROR: PoC structure file does not exist. (%s)" % str(pocStructureFilePath))
			print()
			return
			
		self.printDebug("reading PoC structure file: %s" % str(pocStructureFilePath))
			
		self.__pocStructure = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__pocStructure.optionxform = str
		self.__pocStructure.read(str(pocConfigFilePath))
		
		
		# read Simulation configuration
		# =========================================================================================================================================================
		tbConfigFilePath = self.__workingDirectoryPath / self.__tbConfigFileName
		if not tbConfigFilePath.exists():
			print("ERROR: Simulation configuration file does not exist. (%s)" % str(tbConfigFilePath))
		self.printDebug("reading Simulation configuration file: %s" % str(tbConfigFilePath))
			
		self.__tbConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__tbConfig.optionxform = str
		self.__tbConfig.read([str(pocConfigFilePath), str(pocStructureFilePath), str(tbConfigFilePath)])
		
	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)

	def isimSimulation(self, module, showLogs):
		if (len(self.__pocConfig.options("Xilinx-ISE")) == 0):
			print("Xilinx ISE is not configured on this system.")
			print("Run 'PoC.py --configure' to configure your Xilinx ISE environment.")
			return
	
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

		iseInstallationDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['InstallationDirectory'])
		iseBinaryDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['BinaryDirectory'])
		vhpcompExecutablePath = iseBinaryDirectoryPath / ("vhpcomp.exe" if (self.__platform == "Windows") else "vhpcomp")
		fuseExecutablePath = iseBinaryDirectoryPath / ("fuse.exe" if (self.__platform == "Windows") else "fuse")
		
#		settingsFilePath = iseInstallationDirectoryPath / "settings64.bat"
		section = "%s.%s" % (fullNamespace, moduleName)
		testbenchName = self.__tbConfig[section]['TestbenchModule']
		prjFilePath =  pathlib.Path(self.__tbConfig[section]['iSimProjectFile'])
		exeFilePath =  tempIsimPath / (self.__tbConfig[section]['TestbenchModule'] + ".exe")
		tclFilePath =  pathlib.Path(self.__tbConfig[section]['iSimTclScript'])
			
#		print()
			
		if (self.__verbose):
			print("Commands to be run:")
#			print("1. Load Xilinx / ISE / iSim environment variables")
			print("2. Change working directory to temporary directory")
			print("3. Compile and Link source files to an executable simulation file")
			print("4. Simulate in tcl batch mode")
			print()
		
#			print("%s" % (str(settingsFilePath)))		
			print('cd "%s"' % str(tempIsimPath))
			print('%s work.%s -prj "%s" -o "%s"' % (str(fuseExecutablePath), testbenchName, str(prjFilePath), str(exeFilePath)))
			print('%s -tclbatch "%s"' % (str(exeFilePath), str(tclFilePath)))
			print()

#		settingsLog = subprocess.check_output([str(settingsFilePath)], stderr=subprocess.STDOUT, universal_newlines=True)
#		print(settingsLog)

		os.chdir(str(tempIsimPath))
		
		# running fuse
		print("running fuse...")
		linkerLog = subprocess.check_output([
			str(fuseExecutablePath),
			('work.%s' % testbenchName),
			'-prj',
			str(prjFilePath),
			'-o',
			str(exeFilePath)
			], stderr=subprocess.STDOUT, universal_newlines=True)
		
		if showLogs:
			print("fuse log (fuse)")
			print("--------------------------------------------------------------------------------")
			print(linkerLog)
			print()
		
		# running simulation
		print("running simulation...")
		simulatorLog = subprocess.check_output([
			str(exeFilePath),
			'-tclbatch',
			str(tclFilePath)
			], stderr=subprocess.STDOUT, universal_newlines=True)
		
		if showLogs:
			print("simulator log")
			print("--------------------------------------------------------------------------------")
			print(simulatorLog)
			print("--------------------------------------------------------------------------------")		
	
		print()
		# check output
		matchPos = simulatorLog.index("SIMULATION RESULT = ")
		if (matchPos >= 0):
			if (simulatorLog[matchPos + 20 : matchPos + 26] == "PASSED"):
				print("Testbench '%s': PASSED" % testbenchName)
			elif (simulatorLog[matchPos + 20: matchPos + 26] == "FAILED"):
				print("Testbench '%s': FAILED" % testbenchName)
			else:
				print("Testbench '%s': ERROR" % testbenchName)
				print()
				print("ERROR: This testbench is not working correctly.")
				return
		else:
			print("Testbench '%s': ERROR" % "")
			print()
			print("ERROR: This testbench is not working correctly.")
			return
	
	def vsimSimulation(self, module, showLogs):
		if ((len(self.__pocConfig.options("Altera-ModelSim")) == 0) or (len(self.__pocConfig.options("Mentor-ModelSim")) == 0)):
			print("ModelSim is not configured on this system.")
			print("Run 'PoC.py --configure' to configure your ModelSim environment.")
			return
		
		print("ERROR: not implemented.")
	
	def ghdlSimulation(self, module, showLogs):
		if (len(self.__pocConfig.options("GHDL")) == 0):
			print("GHDL is not configured on this system.")
			print("Run 'PoC.py --configure' to configure your GHDL environment.")
			return
	
		temp = module.split('_', 1)
		namespacePrefix = temp[0]
		moduleName = temp[1]
		fullNamespace = self.getNamespaceForPrefix(namespacePrefix)
		
		print("Preparing simulation environment for '%s.%s'" % (fullNamespace, moduleName))
		tempGhdlPath = self.__pocDirectoryPath / self.__tempFilesDirectory / self.__ghdlFilesDirectory
		if not (tempGhdlPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("temporary directors: %s" % str(tempGhdlPath))
			tempGhdlPath.mkdir(parents=True)

		ghdlInstallationDirectoryPath = pathlib.Path(self.__pocConfig['GHDL']['InstallationDirectory'])
		ghdlBinaryDirectoryPath = pathlib.Path(self.__pocConfig['GHDL']['BinaryDirectory'])
		ghdlExecutablePath = ghdlBinaryDirectoryPath / ("ghdl.exe" if (self.__platform == "Windows") else "ghdl")
		
#		settingsFilePath = iseInstallationDirectoryPath / "settings64.bat"
		section = "%s.%s" % (fullNamespace, moduleName)
		testbenchName = self.__tbConfig[section]['TestbenchModule']
		prjFilePath =  pathlib.Path(self.__tbConfig[section]['iSimProjectFile'])
			
		if (self.__verbose):
			print("Commands to be run:")
			print("1. Parse iSim prj files to extract dependencies.")
			print("2. Change working directory to temporary directory")
			print("3. Add vhdl files to ghdl cache.")
			print("4. Add testbench file to ghdl cache.")
			print("5. Compile and run simulation")
			print()
		
			print('cd "%s"' % str(tempGhdlPath))
			print('%s -a --work=PoC "%s"' % (str(ghdlExecutablePath), 'path/to/sourcefile.vhdl'))
			print('%s -r --work=work work.%s' % (str(ghdlExecutablePath), testbenchName))
			print()

#		settingsLog = subprocess.check_output([str(settingsFilePath)], stderr=subprocess.STDOUT, universal_newlines=True)
#		print(settingsLog)

		os.chdir(str(tempGhdlPath))
		print(os.getcwd())
		
		regexp = re.compile(r"""vhdl\s+(?P<Library>[_a-zA-Z0-9]+)\s+\"(?P<VHDLFile>.*)\"""")
		
		# add files to GHDL cache
		print("ghdl -a for every file...")		
		with prjFilePath.open('r') as prjFileHandle:
			for line in prjFileHandle:
				regExpMatch = regexp.match(line)
				
				if (regExpMatch is not None):
					command = '%s -a --work=%s "%s"' % (str(ghdlExecutablePath), regExpMatch.group('Library'), str(pathlib.Path(regExpMatch.group('VHDLFile'))))
					self.printDebug('command: %s' % command)
					ghdlLog = subprocess.check_output([
						str(ghdlExecutablePath),
						'-a',
						('--work=%s' % regExpMatch.group('Library')),
						str(pathlib.Path(regExpMatch.group('VHDLFile')))
						], stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
					if showLogs:
						print("ghdl call: %s" % command)
						
						if (ghdlLog != ""):
							print("ghdl messages for : %s" % str(pathlib.Path(regExpMatch.group('VHDLFile'))))
							print("--------------------------------------------------------------------------------")
							print(ghdlLog)
		
		simulatorLog = ""
		
		# run GHDL simulation on Windows
		if (self.__platform == "Windows"):
			simulatorLog = subprocess.check_output([
				str(ghdlExecutablePath),
				'-r',
				'--work=work',
				testbenchName
				], stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if showLogs:
				command = "%s -r --work=work %s" % (str(ghdlExecutablePath), testbenchName)
				print("ghdl call: %s" % command)
				
				if (simulatorLog != ""):
					print("ghdl simulation messages:")
					print("--------------------------------------------------------------------------------")
					print(simulatorLog)
		elif (self.__platform == "Linux"):
			elaborateLog = subprocess.check_output([
				str(ghdlExecutablePath),
				'-e', '--syn-binding',
				'--work=work',
				testbenchName
				], stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if showLogs:
				command = "%s -e --syn-binding --work=work %s" % (str(ghdlExecutablePath), testbenchName)
				print("ghdl call: %s" % command)
				
				if (elaborateLog != ""):
					print("ghdl elaborate messages:")
					print("--------------------------------------------------------------------------------")
					print(elaborateLog)

			simulatorLog = subprocess.check_output([
				('./%s' % testbenchName)
				], stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if showLogs:
				command = './%s' % testbenchName
				print("ghdl call: %s" % command)
				
				if (simulatorLog != ""):
					print("ghdl simulation messages:")
					print("--------------------------------------------------------------------------------")
					print(simulatorLog)
		else:
			print("ERROR: Platform not supported!")
			return

		print()
		matchPos = simulatorLog.index("SIMULATION RESULT = ")
		if (matchPos >= 0):
			if (simulatorLog[matchPos + 20 : matchPos + 26] == "PASSED"):
				print("Testbench '%s': PASSED" % testbenchName)
			elif (simulatorLog[matchPos + 20: matchPos + 26] == "FAILED"):
				print("Testbench '%s': FAILED" % testbenchName)
			else:
				print("Testbench '%s': ERROR" % testbenchName)
				print()
				print("ERROR: This testbench is not working correctly.")
				return
		else:
			print("Testbench '%s': ERROR" % "")
			print()
			print("ERROR: This testbench is not working correctly.")
			return

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
		argParser.add_argument('-l', action='store_const', const=True, default=False, help='show logs')
		argParser.add_argument('--isim', action='store_const', const=True, default=False, help='use Xilinx ISE Simulator (iSim)')
		argParser.add_argument('--vsim', action='store_const', const=True, default=False, help='use Mentor Graphics ModelSim (vSim)')
		argParser.add_argument('--ghdl', action='store_const', const=True, default=False, help='use GHDL Simulator (ghdl)')
		argParser.add_argument("module", help="Specify the module which should be tested.")
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("Exception: %s" % ex.__str__())

	test = PoCTestbench(args.d, args.v)
	
	if args.isim:
		test.isimSimulation(args.module, args.l)
	elif args.vsim:
		test.vsimSimulation(args.module, args.l)
	elif args.ghdl:
		test.ghdlSimulation(args.module, args.l)
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
