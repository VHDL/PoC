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


	def __init__(self, debug, verbose):
		super(self.__class__, self).__init__(debug, verbose)

	
	def run(self, module, showLogs):
		if (len(self.__pocConfig.options("Xilinx-ISE")) == 0):
			print("Xilinx ISE is not configured on this system.")
			print("Run 'poc.py --configure' to configure your Xilinx ISE environment.")
			return

		iseInstallationDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['InstallationDirectory'])
		iseBinaryDirectoryPath = pathlib.Path(self.__pocConfig['Xilinx-ISE']['BinaryDirectory'])
			
		if (os.environ.get('XILINX') == None):
			settingsFilePath = iseInstallationDirectoryPath
			if (self.__platform == "Windows"):
				settingsFilePath /= "settings64.bat"
			elif (self.__platform == "Linux"):
				settingsFilePath /= "settings64.sh"
			else:
				print("ERROR: Platform not supported!")
				return

			print("ERROR: Xilinx ISE environment is not loaded in this shell.")				
			print("Run '%s' to load your Xilinx ISE environment." % str(settingsFilePath))
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

		vhpcompExecutablePath = iseBinaryDirectoryPath / ("vhpcomp.exe" if (self.__platform == "Windows") else "vhpcomp")
		fuseExecutablePath = iseBinaryDirectoryPath / ("fuse.exe" if (self.__platform == "Windows") else "fuse")
		
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
			print('%s work.%s --incremental -prj "%s" -o "%s"' % (str(fuseExecutablePath), testbenchName, str(prjFilePath), str(exeFilePath)))
			print('%s -tclbatch "%s"' % (str(exeFilePath), str(tclFilePath)))
			print()

#		settingsLog = subprocess.check_output([str(settingsFilePath)], stderr=subprocess.STDOUT, universal_newlines=True)
#		print(settingsLog)

		os.chdir(str(tempIsimPath))
		
		# copy project file into temporary directory
		shutil.copy(str(prjFilePath),str(tempIsimPath));

		# running fuse
		print("running fuse...")
		linkerLog = subprocess.check_output([
			str(fuseExecutablePath),
			('work.%s' % testbenchName),
			'--incremental',
			'-prj',
			str(tempIsimPath / prjFilePath.name),
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
		try:
			result = self.checkSimulatorOutput(simulatorLog)
			
			if (result == True):
				print("Testbench '%s': PASSED" % testbenchName)
			else:
				print("Testbench '%s': FAILED" % testbenchName)
				
		except PoCSimulatorException as ex:
			raise PoCTestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
	