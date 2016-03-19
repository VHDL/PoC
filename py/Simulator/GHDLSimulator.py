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
from pathlib								import Path
from os											import linesep
from configparser						import NoSectionError
from colorama								import Fore as Foreground
import os
import re
import fileinput
import subprocess


from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Simulator.Base					import PoCSimulator 
from Simulator.Exceptions		import * 

# TODO: extract to higher/outer module
_VHDLTestbenchLibraryName = "test"

@unique
class Severity(Enum):
	Fatal =			30
	Error =			20
	Warning =		15
	Info =			10
	Quiet =			 5
	Normal =		 4
	Verbose =		 2
	Debug =			 1
	All =				 0
	
	def __eq__(self, other):		return self.value ==	other.value
	def __ne__(self, other):		return self.value !=	other.value
	def __lt__(self, other):		return self.value <		other.value
	def __le__(self, other):		return self.value <=	other.value
	def __gt__(self, other):		return self.value >		other.value
	def __ge__(self, other):		return self.value >=	other.value
	

class LogEntry:
	def __init__(self, severity, message):
		self._severity =	severity
		self._message =		message
	
	@property
	def Severity(self):
		return self._severity
	
	@property
	def Message(self):
		return self._message
	
	def __str__(self):
		if (self._severity is Severity.Fatal):			return "FATAL: " +		self._message
		elif (self._severity is Severity.Error):		return "ERROR: " +		self._message
		elif (self._severity is Severity.Warning):	return "WARNING: " +	self._message
		elif (self._severity is Severity.Info):			return "INFO: " +			self._message
		elif (self._severity is Severity.Quiet):		return 								self._message
		elif (self._severity is Severity.Normal):		return 								self._message
		elif (self._severity is Severity.Verbose):	return "VERBOSE: " +	self._message
		elif (self._severity is Severity.Debug):		return "DEBUG: " +		self._message

class Logger:
	def __init__(self, host, logLevel, printToStdOut=True):
		self._host =					host
		self._logLevel =			logLevel
		self._printToStdOut =	printToStdOut
		self._entries =				[]
	
	@property
	def LogLevel(self):
		return self._logLevel
	@LogLevel.setter
	def LogLevel(self, value):
		self._logLevel = value
	
	def Write(self, entry):
		if (entry.Severity >= self._logLevel):
			self._entries.append(entry)
			if self._printToStdOut:
				if (entry.Severity is Severity.Fatal):			print("{0}{1}{2}".format(Foreground.RED, entry.Message, Foreground.RESET))
				elif (entry.Severity is Severity.Error):		print("{0}{1}{2}".format(Foreground.LIGHTRED_EX, entry.Message, Foreground.RESET))
				elif (entry.Severity is Severity.Warning):	print("{0}{1}{2}".format(Foreground.LIGHTYELLOW_EX, entry.Message, Foreground.RESET))
				elif (entry.Severity is Severity.Info):			print("{0}{1}{2}".format(Foreground.CYAN, entry.Message, Foreground.RESET))
				elif (entry.Severity is Severity.Quiet):		print(entry.Message + "......")
				elif (entry.Severity is Severity.Normal):		print(entry.Message)
				elif (entry.Severity is Severity.Verbose):	print("{0}{1}{2}".format(Foreground.WHITE, entry.Message, Foreground.RESET))
				elif (entry.Severity is Severity.Debug):		print("{0}{1}{2}".format(Foreground.LIGHTBLACK_EX, entry.Message, Foreground.RESET))
	
	def WriteFatal(self, message):
		self.Write(LogEntry(Severity.Fatal, message))
	
	def WriteError(self, message):
		self.Write(LogEntry(Severity.Error, message))
	
	def WriteWarning(self, message):
		self.Write(LogEntry(Severity.Warning, message))
	
	def WriteInfo(self, message):
		self.Write(LogEntry(Severity.Info, message))
	
	def WriteQuiet(self, message):
		self.Write(LogEntry(Severity.Quiet, message))
	
	def WriteNormal(self, message):
		self.Write(LogEntry(Severity.Normal, message))
	
	def WriteVerbose(self, message):
		self.Write(LogEntry(Severity.Verbose, message))
	
	def WriteDebug(self, message):
		self.Write(LogEntry(Severity.Debug, message))
	
		
class ILogable:
	def __init__(self, logger=None):
		self._logger = logger

	def _LogFatal(self, message):
		if self._logger is not None:
			self._logger.WriteFatal(message)

	def _LogError(self, message):
		if self._logger is not None:
			self._logger.WriteError(message)
	
	def _LogWarning(self, message):
		if self._logger is not None:
			self._logger.WriteWarning(message)
	
	def _LogInfo(self, message):
		if self._logger is not None:
			self._logger.WriteInfo(message)
	
	def _LogQuiet(self, message):
		if self._logger is not None:
			self._logger.WriteQuiet(message)
	
	def _LogNormal(self, message):
		if self._logger is not None:
			self._logger.WriteNormal(message)
	
	def _LogVerbose(self, message):
		if self._logger is not None:
			self._logger.WriteVerbose(message)
	
	def _LogDebug(self, message):
		if self._logger is not None:
			self._logger.WriteDebug(message)


class Simulator(PoCSimulator, ILogable):
	_VHDLTestbenchLibraryName =		"test"
	_guiMode =										False

	def __init__(self, host, showLogs, showReport, guiMode, logger=None):
		super(self.__class__, self).__init__(host, showLogs, showReport)
		ILogable.__init__(self, logger)

		self._guiMode =				guiMode
		self._tempPath =			None

		self._PrepareSimulationEnvironment()
		self._PrepareSimulator()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.host.directories["GHDLTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("    Creating temporary directory for simulator files.")
			self._LogDebug("     Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("    cd \"{0}\"".format(str(self._tempPath)))
		os.chdir(str(self._tempPath))

	def _PrepareSimulator(self):
		ghdlBinaryPath =	self.host.directories["GHDLBinary"]
		ghdlVersion =			self.host.pocConfig['GHDL']['Version']
		ghdlBackend =			self.host.pocConfig['GHDL']['Backend']
		
		self._ghdl =			GHDLExecutable(self.host.platform, ghdlBinaryPath, ghdlVersion, ghdlBackend)

	def Run(self, pocEntity, vhdlVersion="93c", boardName=None, deviceName=None):
		self._pocEntity =			pocEntity
		self._testbenchFQN =	str(pocEntity)
		self._vhdlversion =		vhdlVersion

		# check testbench database for the given testbench		
		self._LogQuiet("Testbench: {0}{1}{2}".format(Foreground.YELLOW, self._testbenchFQN, Foreground.RESET))
		if (not self.host.tbConfig.has_section(self._testbenchFQN)):
			raise SimulatorException("Testbench '{0}' not found.".format(self._testbenchFQN)) from NoSectionError(self._testbenchFQN)
			
		# setup all needed paths to execute fuse
		testbenchName =				self.host.tbConfig[self._testbenchFQN]['TestbenchModule']
		fileListFilePath =		self.host.directories["PoCRoot"] / self.host.tbConfig[self._testbenchFQN]['fileListFile']

		self._CreatePoCProject(testbenchName, boardName, deviceName)
		self._AddFileListFile(fileListFilePath)
		
		if (self._ghdl.Backend == "gcc"):
			self._RunAnalysis()
			self._RunElaboration()
			self._RunSimulation(testbenchName)
		elif (self._ghdl.Backend == "llvm"):
			self._RunAnalysis()
			self._RunElaboration()
			self._RunSimulation(testbenchName)
		elif (self._ghdl.Backend == "mcode"):
			self._RunAnalysis()
			self._RunSimulation(testbenchName)
	
	def _CreatePoCProject(self, testbenchName, boardName=None, deviceName=None):
		# create a PoCProject and read all needed files
		self._LogDebug("    Create a PoC project '{0}'".format(str(testbenchName)))
		pocProject =									PoCProject(testbenchName)
		
		# configure the project
		pocProject.RootDirectory =		self.host.directories["PoCRoot"]
		pocProject.Environment =			Environment.Simulation
		pocProject.ToolChain =				ToolChain.GHDL_GTKWave
		pocProject.Tool =							Tool.GHDL
		
		if (deviceName is None):			pocProject.Board =					boardName
		else:													pocProject.Device =					deviceName
		
		if (self._vhdlversion == "87"):			pocProject.VHDLVersion =		VHDLVersion.VHDL87
		elif (self._vhdlversion == "93"):		pocProject.VHDLVersion =		VHDLVersion.VHDL93
		elif (self._vhdlversion == "93c"):	pocProject.VHDLVersion =		VHDLVersion.VHDL93
		elif (self._vhdlversion == "02"):		pocProject.VHDLVersion =		VHDLVersion.VHDL02
		elif (self._vhdlversion == "08"):		pocProject.VHDLVersion =		VHDLVersion.VHDL08
		
		self._pocProject = pocProject
		
	def _AddFileListFile(self, fileListFilePath):
		self._LogDebug("    Reading filelist '{0}'".format(str(fileListFilePath)))
		# add the *.files file, parse and evaluate it
		fileListFile = self._pocProject.AddFile(FileListFile(fileListFilePath))
		fileListFile.Parse()
		fileListFile.CopyFilesToFileSet()
		fileListFile.CopyExternalLibraries()
		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		
	def _RunAnalysis(self):
		self._LogNormal("  running analysis for every vhdl file...")
		
		# create a GHDLAnalyzer instance
		ghdl = self._ghdl.GetGHDLAnalyze()
		ghdl.VHDLVersion =	self._vhdlversion
		
		# add external library references
		for extLibrary in self._pocProject.ExternalVHDLLibraries:
			ghdl.AddLibraryReference(extLibrary.Path)
		
		# run GHDL analysis for each VHDL file
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not analyse '{0}'.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			
			ghdl.VHDLLibrary =	file.VHDLLibraryName
			ghdl.Analyze(file.Path)

	# running simulation
	# ==========================================================================
	def _RunElaboration(self):
		self._LogNormal("  elaborate simulation...")
		
		# create a GHDLElaborate instance
		ghdl = self._ghdl.GetGHDLElaborate()
		ghdl.VHDLVersion =	self._vhdlversion
		ghdl.VHDLLibrary = _VHDLTestbenchLibraryName
		ghdl.Elaborate("arith_prng_tb")
	
	
	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
			
		# create a GHDLRun instance
		ghdl = self._ghdl.GetGHDLRun()
		ghdl.VHDLVersion =	self._vhdlversion
		ghdl.VHDLLibrary =	_VHDLTestbenchLibraryName
			
		# add external library references
		for extLibrary in self._pocProject.ExternalVHDLLibraries:
			ghdl.AddLibraryReference(extLibrary.Path)
			
		# configure RUNOPTS
		runOptions = []
		runOptions.append('--ieee-asserts={0}'.format("disable-at-0"))		# enable, disable, disable-at-0
		# set dump format to save simulation results to *.vcd file
		if (self._guiMode):
			waveformFileFormat =	self.host.tbConfig[self._testbenchFQN]['ghdlWaveformFileFormat']
					
			if (waveformFileFormat == "vcd"):
				waveformFilePath = self._tempPath / (testbenchName + ".vcd")
				runOptions.append("--vcd={0}".format(str(waveformFilePath)))
			elif (waveformFileFormat == "vcdgz"):
				waveformFilePath = self._tempPath / (testbenchName + ".vcd.gz")
				runOptions.append("--vcdgz={0}".format(str(waveformFilePath)))
			elif (waveformFileFormat == "fst"):
				waveformFilePath = self._tempPath / (testbenchName + ".fst")
				runOptions.append("--fst={0}".format(str(waveformFilePath)))
			elif (waveformFileFormat == "ghw"):
				waveformFilePath = self._tempPath / (testbenchName + ".ghw")
				runOptions.append("--wave={0}".format(str(waveformFilePath)))
			else:																						raise SimulatorException("Unknown waveform file format for GHDL.")
		
		ghdl.Run(testbenchName, runOptions)
		
	def _ExecuteSimulation(self):
		pass

	def View(self, pocEntity):
		self.printNonQuiet("  launching GTKWave...")
		
		testbenchName =				self.host.tbConfig[self._testbenchFQN]['TestbenchModule']
		waveformFileFormat =	self.host.tbConfig[self._testbenchFQN]['ghdlWaveformFileFormat']
					
		if (waveformFileFormat == "vcd"):
			waveformFilePath = self._tempPath / (testbenchName + ".vcd")
		elif (waveformFileFormat == "vcdgz"):
			waveformFilePath = self._tempPath / (testbenchName + ".vcd.gz")
		elif (waveformFileFormat == "fst"):
			waveformFilePath = self._tempPath / (testbenchName + ".fst")
		elif (waveformFileFormat == "ghw"):
			waveformFilePath = self._tempPath / (testbenchName + ".ghw")
		else:																						raise SimulatorException("Unknown waveform file format for GHDL.")
		
		if (not waveformFilePath.exists()):							raise SimulatorException("Waveform file not found.") from FileNotFoundError(str(waveformFilePath))
			
		
		gtkwBinaryPath =		self.host.directories["GTKWBinary"]
		gtkwVersion =				self.host.pocConfig['GTKWave']['Version']
		gtkw = GTKWave(self.host.platform, gtkwBinaryPath, gtkwVersion)
		
		gtkwSaveFilePath =	self.host.directories["PoCRoot"] / self.host.tbConfig[self._testbenchFQN]['gtkwSaveFile']
		
		# if GTKWave savefile exists, load it's settings
		if gtkwSaveFilePath.exists():
			self.printDebug("Found waveform save file: '{0}'".format(str(gtkwSaveFilePath)))
			gtkw.SaveFile = str(gtkwSaveFilePath)
		else:
			self.printDebug("Didn't find waveform save file: '{0}'".format(str(gtkwSaveFilePath)))
		
		# run GTKWave GUI
		gtkw.View(waveformFilePath)
		
		
		
# 		
# 		# run GHDL simulation on Linux
# 		if (self.host.platform == "Linux"):
# 			# preparing some variables for Linux
# 			exeFilePath =		tempGHDLPath / testbenchName.lower()
# 		
# 			# run elaboration
# 			self.printNonQuiet("  running elaboration...")
# 		
# 			parameterList = [
# 				str(ghdlExecutablePath),
# 				'-e', '--syn-binding',
# 				'-fpsl'
# 			]
# 			
# 			for path in externalLibraries:
# 				parameterList.append("-P{0}".format(path))
# 			
# 			parameterList += [
# 				('--ieee=%s' % self.__ieeeFlavor),
# 				('--std=%s' % self.__vhdlStandard),
# 				'--work=test',
# 				testbenchName
# 			]
# 
# 			command = " ".join(parameterList)
# 		
# 			self.printDebug("call ghdl: %s" % str(parameterList))
# 			self.printVerbose("    command: %s" % command)
# 			try:
# 				elaborateLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
# 				# 
# 				if self.showLogs:
# 					if (elaborateLog != ""):
# 						print("ghdl elaborate messages:")
# 						print("-" * 80)
# 						print(elaborateLog)
# 						print("-" * 80)
# 				
# 			except subprocess.CalledProcessError as ex:
# 				print("ERROR while executing ghdl command: %s" % command)
# 				print("Return Code: %i" % ex.returncode)
# 				print("-" * 80)
# 				print(ex.output)
# 				print("-" * 80)
# 				
# 				return
# 
# 			# search log for fatal warnings
# 			analyzeErrors = []
# 			elaborateLogRegExpStr =	r"(?P<VHDLFile>.*?):(?P<LineNumber>\d+):\d+:warning: component instance \"(?P<ComponentName>[a-z]+)\" is not bound"
# 			elaborateLogRegExp = re.compile(elaborateLogRegExpStr)
# 
# 			for logLine in elaborateLog.splitlines():
# 				print("line: " + logLine)
# 				elaborateLogRegExpMatch = elaborateLogRegExp.match(logLine)
# 				if (elaborateLogRegExpMatch is not None):
# 					analyzeErrors.append({
# 						'Type' : "Unbound Component",
# 						'File' : elaborateLogRegExpMatch.group('VHDLFile'),
# 						'Line' : elaborateLogRegExpMatch.group('LineNumber'),
# 						'Component' : elaborateLogRegExpMatch.group('ComponentName')
# 					})
# 		
# 			if (len(analyzeErrors) != 0):
# 				print("  ERROR list:")
# 				for err in analyzeErrors:
# 					print("    %s: '%s' in file '%s' at line %s" % (err['Type'], err['Component'], err['File'], err['Line']))
# 			
# 				raise SimulatorException("Errors while GHDL analysis phase.")
# 
# 	
# 			# run simulation
# 			self.printNonQuiet("  running simulation...")
# 		
# 			parameterList = [str(exeFilePath)]
# 			
# 			# append RUNOPTS
# 			parameterList += [('--ieee-asserts={0}'.format("disable-at-0"))]		# enable, disable, disable-at-0
# 			
# 			# set dump format to save simulation results to *.vcd file
# 			if (self.__guiMode):
# 				if (waveformFileFormat == "vcd"):
# 					parameterList += [("--vcd={0}".format(str(waveformFilePath)))]
# 				elif (waveformFileFormat == "vcdgz"):
# 					parameterList += [("--vcdgz={0}".format(str(waveformFilePath)))]
# 				elif (waveformFileFormat == "fst"):
# 					parameterList += [("--fst={0}".format(str(waveformFilePath)))]
# 				elif (waveformFileFormat == "ghw"):
# 					parameterList += [("--wave={0}".format(str(waveformFilePath)))]
# 				
# 			command = " ".join(parameterList)
# 		
# 			self.printDebug("call ghdl: %s" % str(parameterList))
# 			self.printVerbose("    command: %s" % command)
# 			try:
# 				simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
# 				
# 				# 
# 				if self.showLogs:
# 					if (simulatorLog != ""):
# 						print("ghdl messages for : %s" % str(vhdlFilePath))
# 						print("-" * 80)
# 						print(simulatorLog)
# 						print("-" * 80)
# 				
# 			except subprocess.CalledProcessError as ex:
# 				print("ERROR while executing ghdl command: %s" % command)
# 				print("Return Code: %i" % ex.returncode)
# 				print("-" * 80)
# 				print(ex.output)
# 				print("-" * 80)
# 				
# 				return
# 
# 		print()
# 		
# 		if (not self.__guiMode):
# 			try:
# 				result = self.checkSimulatorOutput(simulatorLog)
# 				
# 				if (result is None):
# 					print("Testbench '{0}': NO ASSERTS PERFORMED".format(testbenchName))
# 				elif (result == True):
# 					print("Testbench '{0}': PASSED".format(testbenchName))
# 				else:
# 					print("Testbench '{0}': FAILED".format(testbenchName))
# 					
# 			except SimulatorException as ex:
# 				raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED|NO ASSERTS]' not found in simulator output.") from ex
# 		
# 		else:	# guiMode
# 			# run GTKWave GUI
# 			self.printNonQuiet("  launching GTKWave...")
# 			
# 			if (not waveformFilePath.exists()):
# 				raise SimulatorException("Waveform file not found.") from FileNotFoundError(str(waveformFilePath))
# 
# 			gtkwExecutablePath =	self.host.directories["GTKWBinary"] / self.__executables['gtkwave']
# 			gtkwSaveFilePath =		self.host.directories["PoCRoot"] / self.host.tbConfig[testbenchFQN]['gtkwSaveFile']
# 		
# 			parameterList = [
# 				str(gtkwExecutablePath),
# 				("--dump={0}".format(str(waveformFilePath)))
# 			]
# 
# 			# if GTKWave savefile exists, load it's settings
# 			if gtkwSaveFilePath.exists():
# 				self.printDebug("Found waveform save file: '%s'" % str(gtkwSaveFilePath))
# 				parameterList += ['--save', str(gtkwSaveFilePath)]
# 			else:
# 				self.printDebug("Didn't find waveform save file: '%s'." % str(gtkwSaveFilePath))
# 			
# 			command = " ".join(parameterList)
# 		
# 			self.printDebug("call GTKWave: %s" % str(parameterList))
# 			self.printVerbose("    command: %s" % command)
# 			try:
# 				gtkwLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
# 				
# 				# 
# 				if self.showLogs:
# 					if (gtkwLog != ""):
# 						print("GTKWave messages:")
# 						print("-" * 80)
# 						print(gtkwLog)
# 						print("-" * 80)
# 
# 				if gtkwSaveFilePath.exists():
# 					for line in fileinput.input(str(gtkwSaveFilePath), inplace = 1):
# 						if line.startswith(('[dumpfile', '[savefile')):
# 							continue
# 						print(line.rstrip(os.linesep))
# 
# 			except subprocess.CalledProcessError as ex:
# 				print("ERROR while executing GTKWave command: %s" % command)
# 				print("Return Code: %i" % ex.returncode)
# 				print("-" * 80)
# 				print(ex.output)
# 				print("-" * 80)
# 				
# 				return

class Executable(ILogable):
	def __init__(self, platform, executablePath, defaultParameters=[], logger=None):
		ILogable.__init__(self, logger)
		
		self._platform = platform
		
		if isinstance(executablePath, str):							executablePath = Path(executablePath)
		elif (not isinstance(executablePath, Path)):		raise ValueError("Parameter 'executablePath' is not of type str or Path.")
		
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
		return subprocess.check_output(parameterList, stderr=subprocess.STDOUT, shell=False, universal_newlines=True)
	
class GHDLExecutable(Executable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, defaultParameters=[]):
		if (platform == "Windows"):			executablePath = binaryDirectoryPath/ "ghdl.exe"
		elif (platform == "Linux"):			executablePath = binaryDirectoryPath/ "ghdl"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters)
		
		if (platform == "Windows"):
			if (backend not in ["mcode"]):								raise SimulatorException("GHDL for Windows does not support backend '{0}'.".format(backend))
		elif (platform == "Linux"):
			if (backend not in ["gcc", "llvm", "mcode"]):	raise SimulatorException("GHDL for Linux does not support backend '{0}'.".format(backend))
		
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._backend =							backend
		self._version =							version
		
		self._flagExplicit =			False
		self._flagRelaxedRules =	False
		self._warnBinding =				False
		self._noVitalChecks =			False
		self._multiByteComments =	False
		self._synBinding =				False
		self._flagPSL =						False
		self._verbose =						False
		self._ieeeFlavor =				None
		self._vhdlVersion =				None
		self._vhdlLibrary =				None
	
	@property
	def BinaryDirectoryPath(self):
		return self._binaryDirectoryPath
	
	@property
	def Backend(self):
		return self._backend

	@property
	def Version(self):
		return self._version
	
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
	def VHDLVersion(self):
		return self._vhdlVersion
	@VHDLVersion.setter
	def VHDLVersion(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		
		if (value == "93"):
			value =  "93c"
			self.IEEEFlavor = "synopsys"
		elif (value == "08"):
			self.IEEEFlavor = "standard"
		
		if (self._vhdlVersion is None):
			self._defaultParameters.append("--std={0}".format(value))
			self._vhdlVersion = value
		elif (self._vhdlVersion != value):
			self._defaultParameters.remove("--std={0}".format(self._vhdlVersion))
			self._defaultParameters.append("--std={0}".format(value))
			self._vhdlVersion = value
	
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
	
	def GetGHDLAnalyze(self):
		return GHDLAnalyze(self._platform, self._binaryDirectoryPath, self._version, self._backend)
	
	def GetGHDLElaborate(self):
		return GHDLElaborate(self._platform, self._binaryDirectoryPath, self._version, self._backend)
	
	def GetGHDLRun(self):
		return GHDLRun(self._platform, self._binaryDirectoryPath, self._version, self._backend)
	
class GHDLAnalyze(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend):
		super().__init__(platform, binaryDirectoryPath, version, backend, ["-a"])

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
		if isinstance(filePath, str):			parameterList.append(filePath)
		elif isinstance(filePath, Path):	parameterList.append(str(filePath))
		elif isinstance(filePath, (tuple, list)):
			for item in filePath:
				if isinstance(item, str):			parameterList.append(item)
				elif isinstance(item, Path):	parameterList.append(str(item))
				else:																				raise ValueError("Parameter 'filePath' is iterable, but contains an unsupported types.")
		else:																						raise ValueError("Parameter 'filePath' has an unsupported type.")
			
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
#		print("    call ghdl: {0}".format(str(parameterList)))
#		print("      command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				if ("ghdl1" not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl messages for : {0}".format(str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except subprocess.CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing ghdl: {0}".format(str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
	
class GHDLElaborate(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend):
		super().__init__(platform, binaryDirectoryPath, version, backend, ["-e"])
	
	def Elaborate(self, topLevel, topLevelArchitecture=None):
		if (self._backend == "mcode"):		return
		
		parameterList = self._defaultParameters.copy()
		parameterList.append(topLevel)
		if (topLevelArchitecture is not None):
			parameterList.append(topLevelArchitecture)
		
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
#		print("    call ghdl: {0}".format(str(parameterList)))
#		print("      command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				if ("ghdl1" not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl elaboration messages for '{0}.{1}'".format(self.VHDLLibrary, topLevel))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except subprocess.CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while elaborating '{0}.{1}'".format(self.VHDLLibrary, topLevel))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class GHDLRun(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend):
		super().__init__(platform, binaryDirectoryPath, version, backend, ["-r"])
	
	def Run(self, testbenchName, runOptions):
		self.SynBinding =					True
		self.FlagPSL =						True
		self.Verbose =						True
		
		parameterList =		self._defaultParameters.copy()
		parameterList.append(testbenchName)
		parameterList +=	runOptions
			
		self._LogDebug("call ghdl: {0}".format(str(parameterList)))
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				if (testbenchName not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl run messages for '{0}.{1}'".format(self.VHDLLibrary, testbenchName))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except subprocess.CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while simulating '{0}.{1}'".format(self.VHDLLibrary, testbenchName))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class GTKWave(Executable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[]):
		if (platform == "Windows"):			executablePath = binaryDirectoryPath/ "gtkwave.exe"
		elif (platform == "Linux"):			executablePath = binaryDirectoryPath/ "gtkwave"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters)
		
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =			version
		
		self._dumpFile =		None
		self._saveFile =		None
	
	@property
	def BinaryDirectoryPath(self):
		return self._binaryDirectoryPath
	
	@property
	def Version(self):
		return self._version
	
	@property
	def DumpFile(self):
		return self._dumpFile
	@DumpFile.setter
	def DumpFile(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._dumpFile is None):
			self._defaultParameters.append("--dump={0}".format(value))
			self._dumpFile = value
		elif (self._dumpFile != value):
			self._defaultParameters.remove("--dump={0}".format(self._dumpFile))
			self._defaultParameters.append("--dump={0}".format(value))
			self._dumpFile = value
		
	@property
	def SaveFile(self):
		return self._saveFile
	@SaveFile.setter
	def SaveFile(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._saveFile is None):
			self._defaultParameters.append("--save={0}".format(value))
			self._saveFile = value
		elif (self._saveFile != value):
			self._defaultParameters.remove("--save={0}".format(self._saveFile))
			self._defaultParameters.append("--save={0}".format(value))
			self._saveFile = value
		
	def View(self, dumpFile):
		if isinstance(dumpFile, str):			self.DumpFile = dumpFile
		elif isinstance(dumpFile, Path):	self.DumpFile = str(dumpFile)
		else:																						raise ValueError("Parameter 'dumpFile' has an unsupported type.")
		
		self._LogDebug("call gtkwave: {0}".format(str(self._defaultParameters)))
		self._LogVerbose("    command: {0}".format(" ".join(self._defaultParameters)))
		
		_indent = "    "
		try:
			gtkwLog = self.StartProcess(self._defaultParameters)
			
			log = ""
			for line in gtkwLog.split("\n"):
				if (("ghdl1" not in line) and (line != "")):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "GTKWave messages for : {0}".format(str(dumpFile)))
				print(_indent + "-" * 80)
				print(log)
				print(_indent + "-" * 80)
		except subprocess.CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing GTKWave: {0}".format(str(dumpFile)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
