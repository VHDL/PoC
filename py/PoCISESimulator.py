# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 	Patrick Lehmann
# 
# Python Class:			TODO
# 
# Description:
# ------------------------------------
#		TODO:
#		- 
#		- 
#
# License:
# ==============================================================================
# Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

	print("=" * 80)
	print("{: ^80s}".format("PoC Library - Python Class PoCISESimulator"))
	print("=" * 80)
	print()
	print("This is no executable file!")
	exit(1)

import PoCSimulator

class PoCISESimulator(PoCSimulator.PoCSimulator):

	__executables = {}

	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		if (host.platform == "Windows"):
			self.__executables['vhcomp'] =	"vhpcomp.exe"
			self.__executables['fuse'] =		"fuse.exe"
		elif (host.platform == "Linux"):
			self.__executables['vhcomp'] =	"vhpcomp"
			self.__executables['fuse'] =		"fuse"
		else:
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
	def run(self, pocEntity):
		from pathlib import Path
		import os
		import re
		import subprocess
	
		self.printNonQuiet(str(pocEntity))
		self.printNonQuiet("  preparing simulation environment...")
		
		
		# create temporary directory for isim if not existent
		tempISimPath = self.host.directories["iSimTemp"]
		if not (tempISimPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("Temporary directors: %s" % str(tempISimPath))
			tempISimPath.mkdir(parents=True)

		# setup all needed paths to execute fuse
		#vhpcompExecutablePath =	self.host.directories["ISEBinary"] / self.__executables['vhpcomp']
		fuseExecutablePath =		self.host.directories["ISEBinary"] / self.__executables['fuse']
		
		testbenchName =		 self.host.tbConfig[str(pocEntity)]['TestbenchModule']
		fileListFilePath =	self.host.directories["PoCRoot"] / self.host.tbConfig[str(pocEntity)]['FileListFile']
		tclFilePath =				self.host.directories["PoCRoot"] / self.host.tbConfig[str(pocEntity)]['iSimTclScript']
		prjFilePath =				tempISimPath / (testbenchName + ".prj")
		exeFilePath =				tempISimPath / (testbenchName + ".exe")

		# report the next steps in execution
#		if (self.getVerbose()):
#			print("  Commands to be run:")
#			print("  1. Change working directory to temporary directory.")
#			print("  2. Parse filelist and write iSim project file.")
#			print("  3. Compile and Link source files to an executable simulation file.")
#			print("  4. Simulate in tcl batch mode.")
#			print("  ----------------------------------------")
		
		# change working directory to temporary iSim path
		self.printVerbose('  cd "%s"' % str(tempISimPath))
		os.chdir(str(tempISimPath))

		# parse project filelist
		regExpStr =	 r"\s*(?P<Keyword>(vhdl|xilinx))"				# Keywords: vhdl, xilinx
		regExpStr += r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"		#	VHDL library name
		regExpStr += r"\s+\"(?P<VHDLFile>.*?)\""						# VHDL filename without "-signs
		regExp = re.compile(regExpStr)

		self.printDebug("Reading filelist '%s'" % str(fileListFilePath))
		iSimProjectFileContent = ""
		with fileListFilePath.open('r') as prjFileHandle:
			for line in prjFileHandle:
				regExpMatch = regExp.match(line)
				
				if (regExpMatch is not None):
					if (regExpMatch.group('Keyword') == "vhdl"):
						vhdlFilePath = self.host.directories["PoCRoot"] / regExpMatch.group('VHDLFile')
					elif (regExpMatch.group('Keyword') == "xilinx"):
						vhdlFilePath = self.host.directories["ISEInstallation"] / "ISE/vhdl/src" / regExpMatch.group('VHDLFile')
					vhdlLibraryName = regExpMatch.group('VHDLLibrary')
					iSimProjectFileContent += "vhdl %s \"%s\"\n" % (vhdlLibraryName, str(vhdlFilePath))
					
					if (not vhdlFilePath.exists()):
						raise PoCSimulator.PoCSimulatorException("Can not find " + str(vhdlFilePath)) from FileNotFoundError(str(vhdlFilePath))
		
		# write iSim project file
		self.printDebug("Writing iSim project file to '%s'" % str(prjFilePath))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(iSimProjectFileContent)


		# running fuse
		# ==========================================================================
		self.printNonQuiet("  running fuse...")
		# assemble fuse command as list of parameters
		parameterList = [
			str(fuseExecutablePath),
			('test.%s' % testbenchName),
			'--incremental',
			'--timeprecision_vhdl', '1fs',			# set minimum time precision to 1 fs
			'-mt', '4',													# enable multithread support
			'-prj',	str(prjFilePath),
			'-o',		str(exeFilePath)
		]
		command = " ".join(parameterList)
		
		self.printDebug("call fuse: %s" % str(parameterList))
		self.printVerbose("    command: %s" % command)
		
		try:
			linkerLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing fuse: %s" % str(vhdlFilePath))
			print("Return Code: %i" % ex.returncode)
			print("--------------------------------------------------------------------------------")
			print(ex.output)
		
		if self.showLogs:
			print("fuse log (fuse)")
			print("--------------------------------------------------------------------------------")
			print(linkerLog)
			print()
		
		# running simulation
		self.printNonQuiet("  running simulation...")
		parameterList = [
			str(exeFilePath),
			'-tclbatch', str(tclFilePath)
		]
		command = " ".join(parameterList)
		
		self.printDebug("call simulation: %s" % str(parameterList))
		self.printVerbose("    command: %s" % command)
		
		try:
			simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing ghdl: %s" % str(vhdlFilePath))
			print("Return Code: %i" % ex.returncode)
			print("--------------------------------------------------------------------------------")
			print(ex.output)
		
		if self.showLogs:
			print("simulator log")
			print("--------------------------------------------------------------------------------")
			print(simulatorLog)
			print("--------------------------------------------------------------------------------")		
	
		print()
		try:
			result = self.checkSimulatorOutput(simulatorLog)
			
			if (result == True):
				print("Testbench '%s': PASSED" % testbenchName)
			else:
				print("Testbench '%s': FAILED" % testbenchName)
				
		except PoCSimulatorException as ex:
			raise PoCTestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
	
