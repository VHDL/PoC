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

import PoCSimulator

class PoCGHDLSimulator(PoCSimulator.PoCSimulator):


	def __init__(self, debug, verbose):
		super(self.__class__, self).__init__(debug, verbose)


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
			print('%s -a --syn-binding --work=PoC "%s"' % (str(ghdlExecutablePath), 'path/to/sourcefile.vhdl'))
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
					command = '%s -a --syn-binding --work=%s "%s"' % (str(ghdlExecutablePath), regExpMatch.group('Library'), str(pathlib.Path(regExpMatch.group('VHDLFile'))))
					self.printDebug('command: %s' % command)
					ghdlLog = subprocess.check_output([
						str(ghdlExecutablePath),
						'-a', '--syn-binding',
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
				'-r', '--syn-binding',
				'--work=work',
				testbenchName
				], stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
#		
			if showLogs:
				command = "%s -r --syn-binding --work=work %s" % (str(ghdlExecutablePath), testbenchName)
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
		matchPos = simulatorLog.find("SIMULATION RESULT = ")
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