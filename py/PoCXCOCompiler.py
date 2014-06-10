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
	print("                  PoC Library - Python Class PoCXCOCompiler             ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)

import PoCCompiler

class PoCXCOCompiler(PoCCompiler.PoCCompiler):

	executables = {}

	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__executables = {
			'CoreGen' :	("coregen.exe"	if (host.platform == "Windows") else "coregen")
		}
		
	def run(self, pocEntity):
		from pathlib import Path
		import os
		import re
		import subprocess
	
		self.printNonQuite(str(pocEntity))
		self.printNonQuite("  preparing compiler environment...")
		
		
		# create temporary directory for CoreGen if not existent
		tempCoreGenPath = self.host.Directories["coreGenTemp"]
		if not (tempCoreGenPath).exists():
			self.printVerbose("Creating temporary directory for core generator files.")
			self.printDebug("Temporary directors: %s" % str(tempCoreGenPath))
			tempCoreGenPath.mkdir(parents=True)

		# setup all needed paths to execute coreGen
		coreGenExecutablePath =		self.host.Directories["ISEBinary"] / self.__executables['CoreGen']
		
		ipCoreName = self.host.netListConfig[str(pocEntity)]['IPCoreName']
		fileFilePath =	self.host.Directories["PoCRoot"] / self.host.netListConfig[str(pocEntity)]['FilesFile']
		tclFilePath =		self.host.Directories["PoCRoot"] / self.host.netListConfig[str(pocEntity)]['CoreGenTclScript']
		prjFilePath =		tempCoreGenPath / (testbenchName + ".prj")
		exeFilePath =		tempCoreGenPath / (testbenchName + ".exe")

		print()
		print("return ...")
		return
		
#  c:\Xilinx\14.7\ISE_DS\ISE\bin\nt64\coregen.exe -r -b lcd_ChipScopeVIO.xco -p .
		
		# report the next steps in execution
		if (self.getVerbose()):
			print("  Commands to be run:")
			print("  1. Change working directory to temporary directory.")
			print("  2. Parse filelist and write CoreGen project file.")
			print("  3. Compile and Link source files to an executable simulation file.")
			print("  4. Simulate in tcl batch mode.")
			print("  ----------------------------------------")
		
		# change working directory to temporary CoreGen path
		self.printVerbose('  cd "%s"' % str(tempCoreGenPath))
		os.chdir(str(tempCoreGenPath))

		# parse project filelist
		regExpStr =	 r"\s*(?P<Keyword>(vhdl|xilinx))"				# Keywords: vhdl, xilinx
		regExpStr += r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"		#	VHDL library name
		regExpStr += r"\s+\"(?P<VHDLFile>.*?)\""						# VHDL filename without "-signs
		regExp = re.compile(regExpStr)

		self.printDebug("Reading filelist '%s'" % str(fileFilePath))
		CoreGenProjectFileContent = ""
		with fileFilePath.open('r') as prjFileHandle:
			for line in prjFileHandle:
				regExpMatch = regExp.match(line)
				
				if (regExpMatch is not None):
					if (regExpMatch.group('Keyword') == "vhdl"):
						vhdlFilePath = self.host.Directories["PoCRoot"] / regExpMatch.group('VHDLFile')
					elif (regExpMatch.group('Keyword') == "xilinx"):
						vhdlFilePath = self.host.Directories["ISEInstallation"] / "ISE/vhdl/src" / regExpMatch.group('VHDLFile')
					vhdlLibraryName = regExpMatch.group('VHDLLibrary')
					CoreGenProjectFileContent += "vhdl %s \"%s\"\n" % (vhdlLibraryName, str(vhdlFilePath))
		
		# write CoreGen project file
		self.printDebug("Writing CoreGen project file to '%s'" % str(prjFilePath))
		with prjFilePath.open('w') as configFileHandle:
			configFileHandle.write(CoreGenProjectFileContent)


		# running coreGen
		# ==========================================================================
		self.printNonQuite("  running coreGen...")
		# assemble coreGen command as list of parameters
		parameterList = [
			str(coreGenExecutablePath),
			('work.%s' % testbenchName),
			'--incremental',
			'-prj',	str(prjFilePath),
			'-o',		str(exeFilePath)
		]
		self.printDebug("call coreGen: %s" % str(parameterList))
		self.printVerbose('%s work.%s --incremental -prj "%s" -o "%s"' % (str(coreGenExecutablePath), testbenchName, str(prjFilePath), str(exeFilePath)))
		linkerLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
		if self.showLogs:
			print("coreGen log (coreGen)")
			print("--------------------------------------------------------------------------------")
			print(linkerLog)
			print()
		
		# running simulation
		self.printNonQuite("  running simulation...")
		parameterList = [str(exeFilePath), '-tclbatch', str(tclFilePath)]
		self.printDebug("call simulation: %s" % str(parameterList))
		self.printVerbose('%s -tclbatch "%s"' % (str(exeFilePath), str(tclFilePath)))
		simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
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
	