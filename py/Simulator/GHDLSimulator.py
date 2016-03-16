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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.GHDLSimulator")

# load dependencies
from pathlib import Path
import fileinput
from os import linesep
import subprocess

from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Simulator.Base					import PoCSimulator 
from Simulator.Exceptions		import * 


class Simulator(PoCSimulator):
	__executables =		{}
	__vhdlStandard =	"93"
	__guiMode =				False

	def __init__(self, host, showLogs, showReport, vhdlStandard, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__vhdlStandard =	vhdlStandard
		self.__guiMode =			guiMode

		self.__initExecutables()
	
	def __initExecutables(self):
		if (self.host.platform == "Windows"):
			self.__executables['ghdl'] =		"ghdl.exe"
			self.__executables['gtkwave'] =	"gtkwave.exe"
		elif (self.host.platform == "Linux"):
			self.__executables['ghdl'] =		"ghdl"
			self.__executables['gtkwave'] =	"gtkwave"
		else:
			raise PlatformNotSupportedException(self.platform)
	
	def run(self, pocEntity):
		import os
		import re
		import subprocess
	
		self.printNonQuiet(str(pocEntity))
		self.printNonQuiet("  preparing simulation environment...")

		# create temporary directory for ghdl if not existent
		tempGHDLPath = self.host.directories["GHDLTemp"]
		if not (tempGHDLPath).exists():
			self.printVerbose("Creating temporary directory for simulator files.")
			self.printDebug("Temporary directors: %s" % str(tempGHDLPath))
			tempGHDLPath.mkdir(parents=True)

		if not self.host.tbConfig.has_section(str(pocEntity)):
			from configparser import NoSectionError
			raise SimulatorException("Testbench '" + str(pocEntity) + "' not found.") from NoSectionError(str(pocEntity))
			
		# setup all needed paths to execute fuse
		ghdlExecutablePath =	self.host.directories["GHDLBinary"] / self.__executables['ghdl']
		testbenchName =				self.host.tbConfig[str(pocEntity)]['TestbenchModule']
		waveformFileFormat =	self.host.tbConfig[str(pocEntity)]['ghdlWaveformFileFormat']
		fileListFilePath =		self.host.directories["PoCRoot"] / self.host.tbConfig[str(pocEntity)]['fileListFile']
		
		if (waveformFileFormat == "vcd"):
			waveformFilePath =	tempGHDLPath / (testbenchName + ".vcd")
		elif (waveformFileFormat == "vcdgz"):
			waveformFilePath =	tempGHDLPath / (testbenchName + ".vcd.gz")
		elif (waveformFileFormat == "fst"):
			waveformFilePath =	tempGHDLPath / (testbenchName + ".fst")
		elif (waveformFileFormat == "ghw"):
			waveformFilePath =	tempGHDLPath / (testbenchName + ".ghw")
		else:
			raise SimulatorException("Unknown waveform file format for GHDL.")
		
		if (self.__vhdlStandard == "93"):
			self.__vhdlStandard = "93c"
			self.__ieeeFlavor = "synopsys"
		elif (self.__vhdlStandard == "08"):
			self.__ieeeFlavor = "standard"
		
		# if (self.verbose):
			# print("  Commands to be run:")
			# print("  1. Change working directory to temporary directory")
			# print("  2. Parse filelist file.")
			# print("    a) For every file: Add the VHDL file to GHDL's compile cache.")
			# if (self.host.platform == "Windows"):
				# print("  3. Compile and run simulation")
			# elif (self.host.platform == "Linux"):
				# print("  3. Compile simulation")
				# print("  4. Run simulation")
			# print("  ----------------------------------------")
		
		# change working directory to temporary iSim path
		self.printVerbose('  cd "%s"' % str(tempGHDLPath))
		os.chdir(str(tempGHDLPath))

		self.printDebug("Reading filelist '%s'" % str(fileListFilePath))
		self.printNonQuiet("  running analysis for every vhdl file...")
		
		# add empty line if logs are enabled
		if self.showLogs:		print()

		# create a project
		pocProject =								PoCProject(testbenchName)
		# configure the project
		pocProject.RootDirectory =	self.host.directories["PoCRoot"]
		pocProject.Board =					"KC705"
		pocProject.Environment =		Environment.Simulation
		pocProject.ToolChain =			ToolChain.GHDL_GTKWave
		pocProject.Tool =						Tool.GHDL
		if (self.__vhdlStandard == "87"):			pocProject.VHDLVersion =		VHDLVersion.VHDL87
		elif (self.__vhdlStandard == "93"):		pocProject.VHDLVersion =		VHDLVersion.VHDL93
		elif (self.__vhdlStandard == "93c"):	pocProject.VHDLVersion =		VHDLVersion.VHDL93
		elif (self.__vhdlStandard == "02"):		pocProject.VHDLVersion =		VHDLVersion.VHDL02
		elif (self.__vhdlStandard == "08"):		pocProject.VHDLVersion =		VHDLVersion.VHDL08

		# add a *.files file
		fileListFile = pocProject.AddFile(FileListFile(fileListFilePath))
		fileListFile.Parse()
		fileListFile.CopyFilesToFileSet()
		print("=" * 160)
		print(pocProject.pprint())
		print("=" * 160)
		
		externalLibraries = ["osvvm"]
		
		ghdl = GHDLAnalyze(self.host.platform, ghdlExecutablePath)
		for extLibrary in externalLibraries:
			ghdl.AddLibraryReference(extLibrary)#.Path)
		ghdl.IEEEFlavor =		self.__ieeeFlavor
		ghdl.VHDLStandard =	self.__vhdlStandard
		
		for file in pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.FilePath.exists()):		raise SimulatorException("Can not analyse '" + vhdlFileName + "'.") from FileNotFoundError(str(file))
		
			vhdlLibraryName = "poc"
			
			ghdl.VHDLLibrary =	vhdlLibraryName
			ghdl.Analyze(file.FilePath)

		# running simulation
		# ==========================================================================
		simulatorLog = ""
		
		# # run GHDL simulation on Windows
		# if (self.host.platform == "Windows"):
		self.printNonQuiet("  elaborate simulation...")
		ghdl = GHDLElaborate(self.host.platform, ghdlExecutablePath)
		ghdl.Elaborate()
		
		self.printNonQuiet("  running simulation...")
		
		# create a GHDL object and configure it
		ghdl = GHDLRun(self.host.platform, ghdlExecutablePath)
		ghdl.VHDLStandard =	self.__vhdlStandard
		ghdl.VHDLLibrary =	vhdlLibraryName
		
		# reference external libraries
		for extLibrary in externalLibraries:
			ghdl.AddLibraryReference(extLibrary)#.Path)
		
		# configure RUNOPTS
		runOptions = []
		runOptions += [('--ieee-asserts={0}'.format("disable-at-0"))]		# enable, disable, disable-at-0
		# set dump format to save simulation results to *.vcd file
		if (self.__guiMode):
			if (waveformFileFormat == "vcd"):
				runOptions += [("--vcd={0}".format(str(waveformFilePath)))]
			elif (waveformFileFormat == "vcdgz"):
				runOptions += [("--vcdgz={0}".format(str(waveformFilePath)))]
			elif (waveformFileFormat == "fst"):
				runOptions += [("--fst={0}".format(str(waveformFilePath)))]
			elif (waveformFileFormat == "ghw"):
				runOptions += [("--wave={0}".format(str(waveformFilePath)))]
		
		ghdl.Run(testbenchName, runOptions)
				
		print("return ......................")
		return

		# run GHDL simulation on Linux
		if (self.host.platform == "Linux"):
			# preparing some variables for Linux
			exeFilePath =		tempGHDLPath / testbenchName.lower()
		
			# run elaboration
			self.printNonQuiet("  running elaboration...")
		
			parameterList = [
				str(ghdlExecutablePath),
				'-e', '--syn-binding',
				'-fpsl'
			]
			
			for path in externalLibraries:
				parameterList.append("-P{0}".format(path))
			
			parameterList += [
				('--ieee=%s' % self.__ieeeFlavor),
				('--std=%s' % self.__vhdlStandard),
				'--work=test',
				testbenchName
			]

			command = " ".join(parameterList)
		
			self.printDebug("call ghdl: %s" % str(parameterList))
			self.printVerbose("    command: %s" % command)
			try:
				elaborateLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
				# 
				if self.showLogs:
					if (elaborateLog != ""):
						print("ghdl elaborate messages:")
						print("-" * 80)
						print(elaborateLog)
						print("-" * 80)
				
			except subprocess.CalledProcessError as ex:
				print("ERROR while executing ghdl command: %s" % command)
				print("Return Code: %i" % ex.returncode)
				print("-" * 80)
				print(ex.output)
				print("-" * 80)
				
				return

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
			
				raise SimulatorException("Errors while GHDL analysis phase.")

	
			# run simulation
			self.printNonQuiet("  running simulation...")
		
			parameterList = [str(exeFilePath)]
			
			# append RUNOPTS
			parameterList += [('--ieee-asserts={0}'.format("disable-at-0"))]		# enable, disable, disable-at-0
			
			# set dump format to save simulation results to *.vcd file
			if (self.__guiMode):
				if (waveformFileFormat == "vcd"):
					parameterList += [("--vcd={0}".format(str(waveformFilePath)))]
				elif (waveformFileFormat == "vcdgz"):
					parameterList += [("--vcdgz={0}".format(str(waveformFilePath)))]
				elif (waveformFileFormat == "fst"):
					parameterList += [("--fst={0}".format(str(waveformFilePath)))]
				elif (waveformFileFormat == "ghw"):
					parameterList += [("--wave={0}".format(str(waveformFilePath)))]
				
			command = " ".join(parameterList)
		
			self.printDebug("call ghdl: %s" % str(parameterList))
			self.printVerbose("    command: %s" % command)
			try:
				simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
				
				# 
				if self.showLogs:
					if (simulatorLog != ""):
						print("ghdl messages for : %s" % str(vhdlFilePath))
						print("-" * 80)
						print(simulatorLog)
						print("-" * 80)
				
			except subprocess.CalledProcessError as ex:
				print("ERROR while executing ghdl command: %s" % command)
				print("Return Code: %i" % ex.returncode)
				print("-" * 80)
				print(ex.output)
				print("-" * 80)
				
				return

		print()
		
		if (not self.__guiMode):
			try:
				result = self.checkSimulatorOutput(simulatorLog)
				
				if (result is None):
					print("Testbench '{0}': NO ASSERTS PERFORMED".format(testbenchName))
				elif (result == True):
					print("Testbench '{0}': PASSED".format(testbenchName))
				else:
					print("Testbench '{0}': FAILED".format(testbenchName))
					
			except SimulatorException as ex:
				raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED|NO ASSERTS]' not found in simulator output.") from ex
		
		else:	# guiMode
			# run GTKWave GUI
			self.printNonQuiet("  launching GTKWave...")
			
			if (not waveformFilePath.exists()):
				raise SimulatorException("Waveform file not found.") from FileNotFoundError(str(waveformFilePath))

			gtkwExecutablePath =	self.host.directories["GTKWBinary"] / self.__executables['gtkwave']
			gtkwSaveFilePath =		self.host.directories["PoCRoot"] / self.host.tbConfig[str(pocEntity)]['gtkwSaveFile']
		
			parameterList = [
				str(gtkwExecutablePath),
				("--dump={0}".format(str(waveformFilePath)))
			]

			# if GTKWave savefile exists, load it's settings
			if gtkwSaveFilePath.exists():
				self.printDebug("Found waveform save file: '%s'" % str(gtkwSaveFilePath))
				parameterList += ['--save', str(gtkwSaveFilePath)]
			else:
				self.printDebug("Didn't find waveform save file: '%s'." % str(gtkwSaveFilePath))
			
			command = " ".join(parameterList)
		
			self.printDebug("call GTKWave: %s" % str(parameterList))
			self.printVerbose("    command: %s" % command)
			try:
				gtkwLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
				
				# 
				if self.showLogs:
					if (gtkwLog != ""):
						print("GTKWave messages:")
						print("-" * 80)
						print(gtkwLog)
						print("-" * 80)

				if gtkwSaveFilePath.exists():
					for line in fileinput.input(str(gtkwSaveFilePath), inplace = 1):
						if line.startswith(('[dumpfile', '[savefile')):
							continue
						print(line.rstrip(os.linesep))

			except subprocess.CalledProcessError as ex:
				print("ERROR while executing GTKWave command: %s" % command)
				print("Return Code: %i" % ex.returncode)
				print("-" * 80)
				print(ex.output)
				print("-" * 80)
				
				return

class Executable:
	def __init__(self, platform, executablePath, defaultParameters=[]):
		self._platform = platform
		
		if isinstance(executablePath, str):
			executablePath = Path(executablePath)
		elif (not isinstance(executablePath, Path)):		raise ValueError("Parameter 'executablePath' is not of type str or Path.")
		
		self._executableName = ""
		
		# prepend the executable
		defaultParameters.insert(0, str(executablePath))
		
		self._logger =						None
		self._executablePath =		executablePath
		self._defaultParameters =	defaultParameters
	
	@property
	def Path(self):
		return self._executablePath
	
	@property
	def DefaultParameters(self):
		return self._defaultParameters
	
	@DefaultParameters.setter
	def DefaultParameters(self, value):
		self._defaultParameters = value
	
	def StartProcess(self, parameterList):
		print("Command: " + (" ".join(parameterList)))
		return subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
	
	def _LogError(self, message):
		if self._logger is not None:
			print("ERROR:" + message)
	
	def _LogWarning(self, message):
		if self._logger is not None:
			print("WARNING:" + message)
	
	def _LogInfo(self, message):
		if self._logger is not None:
			print("INFO:" + message)
	
	def _LogNormal(self, message):
		if self._logger is not None:
			print(message)
	
	def _LogVerbose(self, message):
		if self._logger is not None:
			print("VERBOSE:" + message)
	
	def _LogDebug(self, message):
		if self._logger is not None:
			print("DEBUG:" + message)
			
class GHDLExecutable(Executable):
	def __init__(self, platform, executablePath, defaultParameters=[]):
		super().__init__(platform, executablePath, defaultParameters)
		
		if (self._platform == "Windows"):
			self._executableName =	"ghdl.exe"
			self._backend =					"mcode"
		elif (self._platform == "Linux"):
			self._executableName =	"ghdl"
			self._backend =					"llvm"
		
		self._flagExplicit =			False
		self._flagRelaxedRules =	False
		self._warnBinding =				False
		self._noVitalChecks =			False
		self._multiByteComments =	False
		self._synBinding =				False
		self._flagPSL =						False
		self._verbose =						False
		self._ieeeFlavor =				None
		self._vhdlStandard =			None
		self._vhdlLibrary =				None
	
	@property
	def FlagExplicit(self):
		return self._flagExplicit
	@FlagExplicit.setter
	def FlagExplicit(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._flagExplicit != value):
			self._flagExplicit = value
			if value:			self._defaultParameters.append("-fexplicit")
			else:					self._defaultParameters.remove("-fexplicit")
		
	@property
	def FlagRelaxedRules(self):
		return self._flagRelaxedRules
	@FlagRelaxedRules.setter
	def FlagRelaxedRules(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._flagRelaxedRules != value):
			self._flagRelaxedRules = value
			if value:			self._defaultParameters.append("-frelaxed-rules")
			else:					self._defaultParameters.remove("-frelaxed-rules")
		
	@property
	def WarnBinding(self):
		return self._warnBinding
	@WarnBinding.setter
	def WarnBinding(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._warnBinding != value):
			self._warnBinding = value
			if value:			self._defaultParameters.append("--warn-binding")
			else:					self._defaultParameters.remove("--warn-binding")
		
	@property
	def NoVitalChecks(self):
		return self._noVitalChecks
	@NoVitalChecks.setter
	def NoVitalChecks(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._noVitalChecks != value):
			self._noVitalChecks = value
			if value:			self._defaultParameters.append("--no-vital-checks")
			else:					self._defaultParameters.remove("--no-vital-checks")
		
	@property
	def MultiByteComments(self):
		return self._multiByteComments
	@MultiByteComments.setter
	def MultiByteComments(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._multiByteComments != value):
			self._multiByteComments = value
			if value:			self._defaultParameters.append("--mb-comments")
			else:					self._defaultParameters.remove("--mb-comments")
		
	@property
	def SynBinding(self):
		return self._synBinding
	@SynBinding.setter
	def SynBinding(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._synBinding != value):
			self._synBinding = value
			if value:			self._defaultParameters.append("--syn-binding")
			else:					self._defaultParameters.remove("--syn-binding")
		
	@property
	def FlagPSL(self):
		return self._flagPSL
	@FlagPSL.setter
	def FlagPSL(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._flagPSL != value):
			self._flagPSL = value
			if value:			self._defaultParameters.append("-fpsl")
			else:					self._defaultParameters.remove("-fpsl")
		
	@property
	def Verbose(self):
		return self._verbose
	@Verbose.setter
	def Verbose(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._verbose != value):
			self._verbose = value
			if value:			self._defaultParameters.append("-v")
			else:					self._defaultParameters.remove("-v")
	
	@property
	def IEEEFlavor(self):
		return self._ieeeFlavor
	@IEEEFlavor.setter
	def IEEEFlavor(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._ieeeFlavor is None):
			self._defaultParameters.append("--ieee={0}".format(value))
			self._ieeeFlavor = value
		elif (self._ieeeFlavor != value):
			self._defaultParameters.remove("--ieee={0}".format(self._ieeeFlavor))
			self._defaultParameters.append("--ieee={0}".format(value))
			self._ieeeFlavor = value
		
	@property
	def VHDLStandard(self):
		return self._vhdlStandard
	@VHDLStandard.setter
	def VHDLStandard(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._vhdlStandard is None):
			self._defaultParameters.append("--std={0}".format(value))
			self._vhdlStandard = value
		elif (self._vhdlStandard != value):
			self._defaultParameters.remove("--std={0}".format(self._vhdlStandard))
			self._defaultParameters.append("--std={0}".format(value))
			self._vhdlStandard = value
	
	@property
	def VHDLLibrary(self):
		return self._vhdlLibrary
	@VHDLLibrary.setter
	def VHDLLibrary(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._vhdlLibrary is None):
			self._defaultParameters.append("--work={0}".format(value))
			self._vhdlLibrary = value
		elif (self._vhdlLibrary != value):
			self._defaultParameters.remove("--work={0}".format(self._vhdlLibrary))
			self._defaultParameters.append("--work={0}".format(value))
			self._vhdlLibrary = value
	
	def AddLibraryReference(self, path):
		if isinstance(path, Path):		path = str(path)
		self._defaultParameters.append("-P{0}".format(path))
	
class GHDLAnalyze(GHDLExecutable):
	def __init__(self, platform, executablePath):
		super().__init__(platform, executablePath, ["-a"])

		self.FlagExplicit =				True
		self.FlagRelaxedRules =		True
		self.WarnBinding =				True
		self.NoVitalChecks =			True
		self.MultiByteComments =	True
		self.SynBinding =					True
		self.FlagPSL =						True
		self.Verbose =						True
	
	
	def Analyze(self, filePath):
		parameterList = self._defaultParameters.copy()
		if isinstance(filePath, str):
			parameterList.append(filePath)
		elif isinstance(filePath, Path):
			parameterList.append(str(filePath))
		elif isinstance(filePath, (tuple, list)):
			for item in filePath:
				if isinstance(item, str):
					parameterList.append(item)
				elif isinstance(item, Path):
					parameterList.append(str(item))
				else:																				raise ValueError("Parameter 'filePath' is iterable, but contains not supported types.")
		else:																						raise ValueError("Parameter 'filePath' has a not supported type.")
			
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		try:
			ghdlLog = self.StartProcess(parameterList)

			# if self.showLogs:
			if (ghdlLog != ""):
				print("ghdl messages for : {0}".format(str(filePath)))
				print("-" * 80)
				print(ghdlLog)
				print("-" * 80)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing ghdl: {0}".format(str(filePath)))
			print("Return Code: {0}".format(ex.returncode))
			print("-" * 80)
			print(ex.output)
			print("-" * 80)
	
class GHDLElaborate(GHDLExecutable):
	def __init__(self, platform, executablePath):
		super().__init__(platform, executablePath, ["-e"])
	
	def Elaborate(self):
		if (self._backend == "mcode"):		return
		
		parameterList = self._defaultParameters.copy()
			
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		try:
			ghdlLog = self.StartProcess(parameterList)

			# if self.showLogs:
			if (ghdlLog != ""):
				print("ghdl messages for : {0}".format("?????"))	#str(filePath)))
				print("-" * 80)
				print(ghdlLog)
				print("-" * 80)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing ghdl: {0}".format("?????"))	#str(filePath)))
			print("Return Code: {0}".format(ex.returncode))
			print("-" * 80)
			print(ex.output)
			print("-" * 80)
	
class GHDLRun(GHDLExecutable):
	def __init__(self, platform, executablePath):
		super().__init__(platform, executablePath, ["-r"])

	def Run(self, testbenchName, runOptions):
	
	
		self.SynBinding =					True
		self.FlagPSL =						True
		self.Verbose =						True
		
		parameterList =		self._defaultParameters.copy()
		parameterList.append(testbenchName)
		parameterList +=	runOptions
			
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		try:
			ghdlLog = self.StartProcess(parameterList)

			# if self.showLogs:
			if (ghdlLog != ""):
				print("ghdl messages for : {0}".format("?????"))	#str(filePath)))
				print("-" * 80)
				print(ghdlLog)
				print("-" * 80)
		except subprocess.CalledProcessError as ex:
			print("ERROR while executing ghdl: {0}".format("?????"))	#str(filePath)))
			print("Return Code: {0}".format(ex.returncode))
			print("-" * 80)
			print(ex.output)
			print("-" * 80)

