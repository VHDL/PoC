# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Class:			TODO
# 
# Authors:				 	Patrick Lehmann
# 
# Description:
# ------------------------------------
#		TODO:
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

# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from sys import exit

	print("========================================================================")
	print("                  PoC Library - Python Class PoCGHDLSimulator           ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)

import PoC
import PoCSimulator

class PoCGHDLSimulator(PoCSimulator.PoCSimulator):

	executables = {}

	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__executables = {
			'ghdl' :		("ghdl.exe"			if (host.platform == "Windows") else "ghdl")
		}
		
	def run(self, pocEntity):
		from pathlib import Path
		import os
		import re
		import subprocess
	
		self.printNonQuite(str(pocEntity))
		self.printNonQuite("  preparing simulation environment...")

		# create temporary directory for ghdl if not existent
		tempGHDLPath = self.host.Directories["ghdlTemp"]
		if not (tempGHDLPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("Temporary directors: %s" % str(tempGHDLPath))
			tempGHDLPath.mkdir(parents=True)

		# setup all needed paths to execute fuse
		ghdlExecutablePath =		self.host.Directories["GHDLBinary"] / self.__executables['ghdl']
		
		testbenchName = self.host.tbConfig[str(pocEntity)]['TestbenchModule']
		fileFilePath =	self.host.Directories["PoCRoot"] / self.host.tbConfig[str(pocEntity)]['FilesFile']
		
		if (self.getVerbose()):
			print("  Commands to be run:")
			print("  1. Change working directory to temporary directory")
			print("  2. Parse filelist file.")
			print("    a) For every file: Add the VHDL file to GHDL's compile cache.")
			if (self.host.platform == "Windows"):
				print("  3. Compile and run simulation")
			elif (self.host.platform == "Linux"):
				print("  3. Compile simulation")
				print("  4. Run simulation")
			print("  ----------------------------------------")
		
		# change working directory to temporary iSim path
		self.printVerbose('  cd "%s"' % str(tempGHDLPath))
		os.chdir(str(tempGHDLPath))

		# parse project filelist
		filesLineRegExpStr =	r"\s*(?P<Keyword>(vhdl|xilinx))"				# Keywords: vhdl, xilinx
		filesLineRegExpStr +=	r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"		#	VHDL library name
		filesLineRegExpStr +=	r"\s+\"(?P<VHDLFile>.*?)\""						# VHDL filename without "-signs
		filesLineRegExp = re.compile(filesLineRegExpStr)

		self.printDebug("Reading filelist '%s'" % str(fileFilePath))
		self.printNonQuite("  running analysis for every vhdl ...")
		
		# add empty line if logs are enabled
		if self.showLogs:		print()
		
		with fileFilePath.open('r') as fileFileHandle:
			for line in fileFileHandle:
				filesLineRegExpMatch = filesLineRegExp.match(line)
		
				if (filesLineRegExpMatch is not None):
					if (filesLineRegExpMatch.group('Keyword') == "vhdl"):
						vhdlFilePath = self.host.Directories["PoCRoot"] / filesLineRegExpMatch.group('VHDLFile')
					elif (filesLineRegExpMatch.group('Keyword') == "xilinx"):
						if not self.host.Directories.__contains__("ISEInstallation"):
							# check if ISE is configure
							if (len(self.host.pocConfig.options("Xilinx-ISE")) == 0):
								raise PoCNotConfiguredException("This testbench requires some Xilinx Primitves. Please configure Xilinx ISE / Vivado")

							self.host.Directories["ISEInstallation"] = Path(self.host.pocConfig['Xilinx-ISE']['InstallationDirectory'])
						
						vhdlFilePath = self.host.Directories["ISEInstallation"] / "ISE/vhdl/src" / filesLineRegExpMatch.group('VHDLFile')
					vhdlLibraryName = filesLineRegExpMatch.group('VHDLLibrary')

					# assemble fuse command as list of parameters
					parameterList = [
						str(ghdlExecutablePath),
						'-a', '-P.',
						('--work=%s' % vhdlLibraryName),
						str(vhdlFilePath)
					]
					
					command = '%s -a -P. --work=%s "%s"' % (str(ghdlExecutablePath), vhdlLibraryName, str(vhdlFilePath))
					self.printDebug("call ghdl: %s" % str(parameterList))
					self.printVerbose('command: %s' % command)
					ghdlLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)

					if self.showLogs:
						if (ghdlLog != ""):
							print("ghdl messages for : %s" % str(vhdlFilePath))
							print("--------------------------------------------------------------------------------")
							print(ghdlLog)

		
		# running simulation
		# ==========================================================================
		simulatorLog = ""
		
		# run GHDL simulation on Windows
		if (self.host.platform == "Windows"):
			self.printNonQuite("  running simulation...")
		
			parameterList = [
				str(ghdlExecutablePath),
				'-r', '--syn-binding', '-P.',
				'--work=work',
				testbenchName
			]
			command = "%s -r --syn-binding -P. --work=work %s" % (str(ghdlExecutablePath), testbenchName)
		
			self.printDebug("call ghdl: %s" % str(parameterList))
			self.printVerbose('command: %s' % command)
			simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if self.showLogs:
				if (simulatorLog != ""):
					print("ghdl messages for : %s" % str(vhdlFilePath))
					print("--------------------------------------------------------------------------------")
					print(simulatorLog)

		# run GHDL simulation on Linux
		elif (self.host.platform == "Linux"):
			# preparing some variables for Linux
			exeFilePath =		tempGHDLPath / testbenchName
		
			# run elaboration
			self.printNonQuite("  running elaboration...")
		
			parameterList = [
				str(ghdlExecutablePath),
				'-e', '--syn-binding', '-P.',
				'--work=work',
				testbenchName
			]
			command = "%s -e --syn-binding -P. --work=work %s" % (str(ghdlExecutablePath), testbenchName)
		
			self.printDebug("call ghdl: %s" % str(parameterList))
			self.printVerbose('command: %s' % command)
			elaborateLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if self.showLogs:
				if (elaborateLog != ""):
					print("ghdl elaborate messages:")
					print("--------------------------------------------------------------------------------")
					print(elaborateLog)

			# search log for fatal warnings
			analyzeErrors = []
			elaborateLogRegExpStr =	r"(?P<VHDLFile>.*?):(?P<LineNumber>\d+):\d+:warning: component instance \"(?P<ComponentName>[a-z]+)\" is not bound"
			elaborateLogRegExp = re.compile(elaborateLogRegExpStr)

			for logLine in elaborateLog.splitlines():
				print("line: " + logLine)
				elaborateLogRegExpMatch = elaborateLogRegExp.match(logLine)
				if (elaborateLogRegExpMatch is not None):
					analyzeErrors.append({
						'Type' : "Unbound Component",
						'File' : elaborateLogRegExpMatch.group('VHDLFile'),
						'Line' : elaborateLogRegExpMatch.group('LineNumber'),
						'Component' : elaborateLogRegExpMatch.group('ComponentName')
					})
		
			if (len(analyzeErrors) != 0):
				print("  ERROR list:")
				for err in analyzeErrors:
					print("    %s: '%s' in file '%s' at line %s" % (err['Type'], err['Component'], err['File'], err['Line']))
			
				raise PoCSimulator.PoCSimulatorException("Errors while GHDL analysis phase.")

	
			# run simulation
			self.printNonQuite("  running simulation...")
		
			parameterList = [str(exeFilePath)]
			command = str(exeFilePath)
		
			self.printDebug("call ghdl: %s" % str(parameterList))
			self.printVerbose('command: %s' % command)
			simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if self.showLogs:
				if (simulatorLog != ""):
					print("ghdl messages for : %s" % str(vhdlFilePath))
					print("--------------------------------------------------------------------------------")
					print(simulatorLog)

		print()
		try:
			result = self.checkSimulatorOutput(simulatorLog)
			
			if (result == True):
				print("Testbench '%s': PASSED" % testbenchName)
			else:
				print("Testbench '%s': FAILED" % testbenchName)
				
		except PoCSimulator.PoCSimulatorException as ex:
			raise PoCTestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
	
