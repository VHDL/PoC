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
	print("                  PoC Library - Python Class PoCISESimulator            ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)

import PoCSimulator

class PoCISESimulator(PoCSimulator.PoCSimulator):

	executables = {}

	def __init__(self, host, showLogs):
		super(self.__class__, self).__init__(host, showLogs)

		self.__executables = {
			'vhcomp' :	("vhpcomp.exe"	if (host.platform == "Windows") else "vhpcomp"),
			'fuse' :		("fuse.exe"			if (host.platform == "Windows") else "fuse")
		}
		
	def run(self, pocEntity):
		from pathlib import Path
		import os
		import subprocess
	
		print("Preparing simulation environment for '%s'" % str(pocEntity))
		
		# create temporary directory for isim if not existent
		print(dir(self))
		tempISimPath = self.host.Directories["iSimTemp"]
		if not (tempISimPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("Temporary directors: %s" % str(tempISimPath))
			tempISimPath.mkdir(parents=True)

		# setup all needed paths to execute fuse
		#vhpcompExecutablePath =	self.host.Directories["ISEBinary"] / self.__executables['vhpcomp']
		fuseExecutablePath =		self.host.Directories["ISEBinary"] / self.__executables['fuse']
		
		testbenchName = self.host.tbConfig[str(pocEntity)]['TestbenchModule']
		exeFilePath =  tempISimPath / (testbenchName + ".exe")
		prjFilePath =  Path(self.host.tbConfig[str(pocEntity)]['iSimProjectFile'])
		tclFilePath =  Path(self.host.tbConfig[str(pocEntity)]['iSimTclScript'])
			
		# report the next steps in execution
		if (self.getVerbose()):
			print("Commands to be run:")
			print("1. Change working directory to temporary directory")
			print("2. Compile and Link source files to an executable simulation file")
			print("3. Simulate in tcl batch mode")
			print("----------------------------------------")
		
			print('cd "%s"' % str(tempISimPath))
			print('%s work.%s --incremental -prj "%s" -o "%s"' % (str(fuseExecutablePath), testbenchName, str(prjFilePath), str(exeFilePath)))
			print('%s -tclbatch "%s"' % (str(exeFilePath), str(tclFilePath)))
			print()

		# change working directory to temporary iSim path
		os.chdir(str(tempISimPath))
		
		# copy project file into temporary iSim directory
		import shutil
		shutil.copy(str(prjFilePath), str(tempISimPath));

		# running fuse
		print("running fuse...")
		parameterList = [
			str(fuseExecutablePath),
			('work.%s' % testbenchName),
			'--incremental',
			'-prj',	str(tempISimPath / prjFilePath.name),
			'-o',		str(exeFilePath)
		]
		self.printDebug("call fuse: %s" % str(parameterList))
		linkerLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
		if self.showLogs:
			print("fuse log (fuse)")
			print("--------------------------------------------------------------------------------")
			print(linkerLog)
			print()
		
		# running simulation
		print("running simulation...")
		parameterList = [str(exeFilePath), '-tclbatch', str(tclFilePath)]
		self.printDebug("call fuse: %s" % str(parameterList))
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
	