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
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
#
# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.aSimSimulator")

# load dependencies
from pathlib								import Path
from os											import chdir
from configparser						import NoSectionError
from colorama								import Fore as Foreground

from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Simulator.Exceptions		import *
from Simulator.Base					import PoCSimulator, Executable, VHDLTestbenchLibraryName 


class Simulator(PoCSimulator):
	__guiMode =				False

	def __init__(self, host, showLogs, showReport, vhdlStandard, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__vhdlStandard =	vhdlStandard
		self.__guiMode =			guiMode

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.Host.Directories["aSimTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

		# if (self._host.platform == "Windows"):
			# self.__executables['alib'] =		"vlib.exe"
			# self.__executables['acom'] =		"vcom.exe"
			# self.__executables['asim'] =		"vsim.exe"
		# elif (self._host.platform == "Linux"):
			# self.__executables['alib'] =		"vlib"
			# self.__executables['acom'] =		"vcom"
			# self.__executables['asim'] =		"vsim"

	def PrepareSimulator(self, binaryPath, version):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing GHDL simulator.")
		self._aSim =		AldecSimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)

	def RunAll(self, pocEntities, **kwargs):
		for pocEntity in pocEntities:
			self.Run(pocEntity, **kwargs)
		
	def Run(self, pocEntity, boardName=None, deviceName=None, vhdlVersion="93c", vhdlGenerics=None):
		self._pocEntity =			pocEntity
		self._testbenchFQN =	str(pocEntity)
		self._vhdlversion =		vhdlVersion
		self._vhdlGenerics =	vhdlGenerics

		# check testbench database for the given testbench		
		self._LogQuiet("Testbench: {0}{1}{2}".format(Foreground.YELLOW, self._testbenchFQN, Foreground.RESET))
		if (not self.Host.tbConfig.has_section(self._testbenchFQN)):
			raise SimulatorException("Testbench '{0}' not found.".format(self._testbenchFQN)) from NoSectionError(self._testbenchFQN)
			
		# setup all needed paths to execute fuse
		testbenchName =				self.Host.tbConfig[self._testbenchFQN]['TestbenchModule']
		fileListFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['fileListFile']

		self._CreatePoCProject(testbenchName, boardName, deviceName)
		self._AddFileListFile(fileListFilePath)
		
		
		

		# setup all needed paths to execute fuse
		aLibExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['alib']
		aComExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['acom']
		aSimExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['asim']
#		gtkwExecutablePath =	self.Host.Directories["GTKWBinary"] / self.__executables['gtkwave']
		
		if not self.Host.tbConfig.has_section(str(pocEntity)):
			from configparser import NoSectionError
			raise SimulatorException("Testbench '" + str(pocEntity) + "' not found.") from NoSectionError(str(pocEntity))
		
		testbenchName =				self.Host.tbConfig[str(pocEntity)]['TestbenchModule']
		fileListFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[str(pocEntity)]['fileListFile']
		tclBatchFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[str(pocEntity)]['aSimBatchScript']
		tclGUIFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[str(pocEntity)]['aSimGUIScript']
		tclWaveFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[str(pocEntity)]['aSimWaveScript']
		
#		vcdFilePath =					tempvSimPath / (testbenchName + ".vcd")
#		gtkwSaveFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[str(pocEntity)]['gtkwaveSaveFile']
		
		if (self.verbose):
			print("  Commands to be run:")
			print("  1. Change working directory to temporary directory")
			print("  2. Parse filelist file.")
			print("    a) For every file: Add the VHDL file to aSim's compile cache.")
			if (self.Host.Platform == "Windows"):
				print("  3. Compile and run simulation")
			elif (self.Host.Platform == "Linux"):
				print("  3. Compile simulation")
				print("  4. Run simulation")
			print("  ----------------------------------------")
		
		# change working directory to temporary iSim path
		self._LogVerbose('  cd "%s"' % str(tempaSimPath))
		os.chdir(str(tempaSimPath))

		# parse project filelist
		filesLineRegExpStr =	r"\s*(?P<Keyword>(vhdl(\-(87|93|02|08))?|altera|xilinx))"				# Keywords: vhdl[-nn], altera, xilinx
		filesLineRegExpStr +=	r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"		#	VHDL library name
		filesLineRegExpStr +=	r"\s+\"(?P<VHDLFile>.*?)\""						# VHDL filename without "-signs
		filesLineRegExp = re.compile(filesLineRegExpStr)

		self._LogDebug("Reading filelist '%s'" % str(fileListFilePath))
		self._LogNormal("  running analysis for every vhdl file...")
		
		# add empty line if logs are enabled
		if self.showLogs:		print()
		
		vhdlLibraries = []
		
		with fileListFilePath.open('r') as fileFileHandle:
			for line in fileFileHandle:
				filesLineRegExpMatch = filesLineRegExp.match(line)
		
				if (filesLineRegExpMatch is not None):
					if (filesLineRegExpMatch.group('Keyword') == "vhdl"):
						vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
						vhdlFilePath = self.Host.Directories["PoCRoot"] / vhdlFileName
					elif (filesLineRegExpMatch.group('Keyword')[0:5] == "vhdl-"):
						if (filesLineRegExpMatch.group('Keyword')[-2:] == self.__vhdlStandard):
							vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
							vhdlFilePath = self.Host.Directories["PoCRoot"] / vhdlFileName
						else:
							continue
					elif (filesLineRegExpMatch.group('Keyword') == "altera"):
						self._LogVerbose("    skipped Altera specific file: '%s'" % filesLineRegExpMatch.group('VHDLFile'))
					elif (filesLineRegExpMatch.group('Keyword') == "xilinx"):
#						self._LogVerbose("    skipped Xilinx specific file: '%s'" % filesLineRegExpMatch.group('VHDLFile'))
						# check if ISE or Vivado is configured
						if not self.Host.Directories.__contains__("XilinxPrimitiveSource"):
							raise NotConfiguredException("This testbench requires some Xilinx Primitves. Please configure Xilinx ISE or Vivado.")
						
						vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
						vhdlFilePath = self.Host.Directories["XilinxPrimitiveSource"] / vhdlFileName
					else:
						raise SimulatorException("Unknown keyword in *files file.")
						
					vhdlLibraryName = filesLineRegExpMatch.group('VHDLLibrary')
					
					if (not vhdlLibraries.__contains__(vhdlLibraryName)):
						# assemble alib command as list of parameters
						parameterList = [str(aLibExecutablePath), vhdlLibraryName]
						command = " ".join(parameterList)
						
						self._LogDebug("call alib: %s" % str(parameterList))
						self._LogVerbose("    command: %s" % command)
						
						try:
							aLibLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
							vhdlLibraries.append(vhdlLibraryName)

						except subprocess.CalledProcessError as ex:
								print("ERROR while executing alib: %s" % str(vhdlFilePath))
								print("Return Code: %i" % ex.returncode)
								print("--------------------------------------------------------------------------------")
								print(ex.output)
	
						if self.showLogs:
							if (aLibLog != ""):
								print("alib messages for : %s" % str(vhdlFilePath))
								print("--------------------------------------------------------------------------------")
								print(aLibLog)

					# 
					if (not vhdlFilePath.exists()):
						raise SimulatorException("Can not compile '" + vhdlFileName + "'.") from FileNotFoundError(str(vhdlFilePath))
					
					if (self.__vhdlStandard == "87"):
						vhdlStandard = "-87"
					elif (self.__vhdlStandard == "93"):
						vhdlStandard = "-93"
					elif (self.__vhdlStandard == "02"):
						vhdlStandard = "-2002"
					elif (self.__vhdlStandard == "08"):
						vhdlStandard = "-2008"
					
					# assemble acom command as list of parameters
					parameterList = [
						str(aComExecutablePath),
						'-O3',
						'-relax',
						'-l', 'acom.log',
						vhdlStandard,
						'-work', vhdlLibraryName,
						str(vhdlFilePath)
					]
					command = " ".join(parameterList)
					
					self._LogDebug("call acom: %s" % str(parameterList))
					self._LogVerbose("    command: %s" % command)
					
					try:
						aComLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
					except subprocess.CalledProcessError as ex:
							print("ERROR while executing acom: %s" % str(vhdlFilePath))
							print("Return Code: %i" % ex.returncode)
							print("--------------------------------------------------------------------------------")
							print(ex.output)

					if self.showLogs:
						if (aComLog != ""):
							print("acom messages for : %s" % str(vhdlFilePath))
							print("--------------------------------------------------------------------------------")
							print(aComLog)

		
		# running simulation
		# ==========================================================================
		simulatorLog = ""
		
		# run aSim simulation on Windows
		self._LogNormal("  running simulation...")
	
		parameterList = [
			str(aSimExecutablePath)#,
			# '-vopt',
			# '-t', '1fs',
		]

		# append RUNOPTS to save simulation results to *.vcd file
		if (self.__guiMode):
			parameterList += ['-title', testbenchName]
			
			if (tclWaveFilePath.exists()):
				self._LogDebug("Found waveform script: '%s'" % str(tclWaveFilePath))
				parameterList += ['-do', ('do {%s}; do {%s}' % (str(tclWaveFilePath), str(tclGUIFilePath)))]
			else:
				self._LogDebug("Didn't find waveform script: '%s'. Loading default commands." % str(tclWaveFilePath))
				parameterList += ['-do', ('add wave *; do {%s}' % str(tclGUIFilePath))]
		else:
			parameterList += [
				'-c',
				'-do', str(tclBatchFilePath)
			]
		
		# append testbench name
		parameterList += [
			'-work test', testbenchName
		]
		
		command = " ".join(parameterList)
	
		self._LogDebug("call asim: %s" % str(parameterList))
		self._LogVerbose("    command: %s" % command)
		
		try:
			simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing asim command: %s" % command)
			print("Return Code: %i" % ex.returncode)
			print("--------------------------------------------------------------------------------")
			print(ex.output)
#		
		if self.showLogs:
			if (simulatorLog != ""):
				print("asim messages for : %s" % str(vhdlFilePath))
				print("--------------------------------------------------------------------------------")
				print(simulatorLog)

		print()
		
		if (not self.__guiMode):
			try:
				result = self.checkSimulatorOutput(simulatorLog)
				
				if (result == True):
					print("Testbench '%s': PASSED" % testbenchName)
				else:
					print("Testbench '%s': FAILED" % testbenchName)
					
			except SimulatorException as ex:
				raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
		
# 		else:	# guiMode
# 			# run GTKWave GUI
# 			self._LogNormal("  launching GTKWave...")
# 		
# 			parameterList = [
# 				str(gtkwExecutablePath),
# 				('--dump=%s' % vcdFilePath)
# 			]
# 
# 			# if GTKWave savefile exists, load it's settings
# 			if gtkwSaveFilePath.exists():
# 				parameterList += ['--save', str(gtkwSaveFilePath)]
# 				
# 			command = " ".join(parameterList)
# 		
# 			self._LogDebug("call GTKWave: %s" % str(parameterList))
# 			self._LogVerbose("    command: %s" % command)
# 			try:
# 				gtkwLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
# 			except subprocess.CalledProcessError as ex:
# 				print("ERROR while executing GTKWave command: %s" % command)
# 				print("Return Code: %i" % ex.returncode)
# 				print("--------------------------------------------------------------------------------")
# 				print(ex.output)
# #		
# 			if self.showLogs:
# 				if (gtkwLog != ""):
# 					print("GTKWave messages:")
# 					print("--------------------------------------------------------------------------------")
# 					print(gtkwLog)
