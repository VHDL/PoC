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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.ActiveHDLSimulator")

# load dependencies
from pathlib								import Path
from os											import chdir
from configparser						import NoSectionError
from colorama								import Fore as Foreground
from subprocess							import CalledProcessError

from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Simulator.Exceptions		import * 
from Simulator.Base					import PoCSimulator, Executable, VHDLTestbenchLibraryName

class Simulator(PoCSimulator):
	__guiMode =				False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__guiMode =			guiMode

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.Host.Directories["ActiveHDLTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

	def PrepareSimulator(self, binaryPath, version):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing Active-HDL simulator.")
		self._activeHDL =		ActiveHDLSimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)

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
		
		self._RunCompile()
		# self._RunOptimize()
		
		if (not self.__guiMode):
			self._RunSimulation(testbenchName)
		else:
			self._RunSimulationWithGUI(testbenchName)
		
	def _CreatePoCProject(self, testbenchName, boardName=None, deviceName=None):
		# create a PoCProject and read all needed files
		self._LogDebug("    Create a PoC project '{0}'".format(str(testbenchName)))
		pocProject =									PoCProject(testbenchName)
		
		# configure the project
		pocProject.RootDirectory =		self.Host.Directories["PoCRoot"]
		pocProject.Environment =			Environment.Simulation
		pocProject.ToolChain =				ToolChain.GHDL_GTKWave
		pocProject.Tool =							Tool.GHDL
		
		if (deviceName is None):			pocProject.Board =					boardName
		else:													pocProject.Device =					deviceName
		
		if (self._vhdlversion == "87"):			pocProject.VHDLVersion =		VHDLVersion.VHDL87
		elif (self._vhdlversion == "93"):		pocProject.VHDLVersion =		VHDLVersion.VHDL93
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
		self._pocProject._ResolveVHDLLibraries()
		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		
	def _RunCompile(self):
		self._LogNormal("  running VHDL compiler for every vhdl file...")
		
		# create a ActiveHDLVHDLCompiler instance
		vlib = self._activeHDL.GetVHDLLibraryTool()
		
		for lib in self._pocProject.VHDLLibraries:
			vlib.CreateLibrary(lib.Name)
					
		# create a ActiveHDLVHDLCompiler instance
		acom = self._activeHDL.GetVHDLCompiler()
		acom.VHDLVersion =	self._vhdlversion
		acom.RangeCheck =		True
		
		# run vcom compiler for each VHDL file
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not analyse '{0}'.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			
			acom.VHDLLibrary =	file.VHDLLibraryName
			# set a per file log-file with '-l', 'vcom.log',
			acom.Compile(str(file.Path))
	
	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		tclBatchFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['aSimBatchScript']
		
		# create a ActiveHDLSimulator instance
		aSim = self._activeHDL.GetSimulator()
		# aSim.Optimization =			True
		# aSim.TimeResolution =		"1fs"
		# aSim.ComanndLineMode =	True
		# aSim.BatchCommand =			"do {0}".format(str(tclBatchFilePath))
		# aSim.TopLevel =					"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		
		parameter = "asim -lib {0} {1}\nrun -all\nbye".format(VHDLTestbenchLibraryName, testbenchName)
		
		aSim.Simulate(parameter)
		
	def _RunSimulationWithGUI(self, testbenchName):
		self._LogNormal("  running simulation...")
	
		tclGUIFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['aSimGUIScript']
		tclWaveFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['aSimWaveScript']
		
		# create a ActiveHDLSimulator instance
		aSim = self._activeHDL.GetSimulator()
		aSim.Optimization =		True
		aSim.TimeResolution =	"1fs"
		aSim.Title =					testbenchName
	
		if (tclWaveFilePath.exists()):
			self._LogDebug("Found waveform script: '{0}'".format(str(tclWaveFilePath)))
			aSim.BatchCommand =	"do {0}; do {0}".format(str(tclWaveFilePath), str(tclGUIFilePath))
		else:
			self._LogDebug("Didn't find waveform script: '{0}'. Loading default commands.".format(str(tclWaveFilePath)))
			aSim.BatchCommand =	"add wave *; do {0}".format(str(tclGUIFilePath))

		aSim.TopLevel =		"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		aSim.Simulate()

		# if (not self.__guiMode):
			# try:
				# result = self.checkSimulatorOutput(simulatorLog)
				
				# if (result == True):
					# print("Testbench '%s': PASSED" % testbenchName)
				# else:
					# print("Testbench '%s': FAILED" % testbenchName)
					
			# except SimulatorException as ex:
				# raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
		
class ActiveHDLSimulatorExecutable:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self.__logger =							logger
	
	def GetVHDLCompiler(self):
		return ActiveHDLVHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
	def GetSimulator(self):
		return ActiveHDLSimulator(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
	def GetVHDLLibraryTool(self):
		return ActiveHDLVHDLLibraryTool(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)

class ActiveHDLVHDLCompiler(Executable, ActiveHDLSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ActiveHDLSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vcom.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vcom"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self._verbose =						False
		self._rangecheck =				True
		self._vhdlVersion =				None
		self._vhdlLibrary =				None
	
	# -reorder                      enables automatic file ordering
  # -O[0 | 1 | 2 | 3]             set optimization level
	# -93                                conform to VHDL 1076-1993
  # -2002                              conform to VHDL 1076-2002 (default)
  # -2008                              conform to VHDL 1076-2008
	# -relax                             allow 32-bit integer literals
  # -incr                              switching compiler to fast incremental mode
	
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
	def VHDLVersion(self):
		return self._vhdlVersion
	@VHDLVersion.setter
	def VHDLVersion(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		elif ((self._vhdlVersion is not None) and (self._vhdlVersion != value)):
			if (self._vhdlVersion == "87"):			self._defaultParameters.remove("-87")
			elif (self._vhdlVersion == "93"):		self._defaultParameters.remove("-93")
			elif (self._vhdlVersion == "02"):		self._defaultParameters.remove("-2002")
			elif (self._vhdlVersion == "08"):		self._defaultParameters.remove("-2008")
		
		if (value == "87"):										self._defaultParameters.append("-87")
		elif (value == "93"):									self._defaultParameters.append("-93")
		elif (value == "02"):									self._defaultParameters.append("-2002")
		elif (value == "08"):									self._defaultParameters.append("-2008")
		else:																					raise SimulatorException("Parameter 'value' has an unsupported value.")
		self._vhdlVersion = value
	
	@property
	def VHDLLibrary(self):
		return self._vhdlLibrary
	@VHDLLibrary.setter
	def VHDLLibrary(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._vhdlLibrary is None):
			self._defaultParameters.append("-work")
			self._defaultParameters.append(value)
			self._vhdlLibrary = value
		elif (self._vhdlLibrary != value):
			i = self._defaultParameters.index(self._vhdlLibrary)
			self._defaultParameters[i] = value
			self._vhdlLibrary = value
	
	@property
	def RangeCheck(self):
		return self._rangecheck
	@RangeCheck.setter
	def RangeCheck(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._rangecheck != value):
			self._rangecheck = value
			if value:			self._defaultParameters.remove("--norangecheck")
			else:					self._defaultParameters.append("--norangecheck")
	
	def Compile(self, vhdlFile):
		parameterList = self._defaultParameters.copy()
		parameterList.append(vhdlFile)
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			vcomLog = self.StartProcess(parameterList)
			
			log = ""
			for line in vcomLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vlib messages for : {0}".format(str(vhdlFile)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vlib: {0}".format(str(vhdlFile)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class ActiveHDLSimulator(Executable, ActiveHDLSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ActiveHDLSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vsimsa.bat"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vsimsa"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self._verbose =						None
		self._optimize =					None
		self._comanndLineMode =		None
		self._timeResolution =		None
		self._batchCommand =			None
		self._topLevel =					None
	
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
	def Optimization(self):
		return self._optimize
	@Optimization.setter
	def Optimization(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._optimize != value):
			self._optimize = value
			if value:			self._defaultParameters.append("-vopt")
			else:					self._defaultParameters.remove("-vopt")
	
	@property
	def TimeResolution(self):
		return self._timeResolution
	@TimeResolution.setter
	def TimeResolution(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		units = ("fs", "ps", "us", "ms", "sec", "min", "hr")
		if (not value.endswith(units)):									raise ValueError("Parameter 'value' must contain a time unit.")
		if (self._timeResolution is None):
			self._defaultParameters.append("-t")
			self._defaultParameters.append(value)
			
	@property
	def ComanndLineMode(self):
		return self._comanndLineMode
	@ComanndLineMode.setter
	def ComanndLineMode(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._comanndLineMode != value):
			self._comanndLineMode = value
			if value:			self._defaultParameters.append("-c")
			else:					self._defaultParameters.remove("-c")
	
	@property
	def BatchCommand(self):
		return self._batchCommand
	@BatchCommand.setter
	def BatchCommand(self, value):
		if (not isinstance(value, str)):																raise ValueError("Parameter 'value' is not of type str.")
		self._defaultParameters.append("-do")
		self._defaultParameters.append(value)
	
	@property
	def TopLevel(self):
		return self._topLevel
	@TopLevel.setter
	def TopLevel(self, value):
		if (not isinstance(value, str)):																raise ValueError("Parameter 'value' is not of type str.")
		self._defaultParameters.append(value)
	
	def Simulate(self, parameter):
		parameterList = self._defaultParameters.copy()
		
		parameterList.append(parameter)
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			aSimLog = self.StartProcess(parameterList)
			
			log = ""
			for line in aSimLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vsimsa messages for : {0}".format(str(parameterList)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vsimsa: {0}".format(str(parameterList)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class ActiveHDLVHDLLibraryTool(Executable, ActiveHDLSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ActiveHDLSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vlib.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vlib"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self._verbose =						False
	
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
	
	def CreateLibrary(self, vhdlLibraryName):
		parameterList = self._defaultParameters.copy()
		parameterList.append(vhdlLibraryName)
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			vlibLog = self.StartProcess(parameterList)
			
			log = ""
			for line in vlibLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vlib messages for : {0}".format(vhdlLibraryName))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vlib: {0}".format(vhdlLibraryName))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
	

		# if (self._host.platform == "Windows"):
			# self.__executables['alib'] =		"vlib.exe"
			# self.__executables['acom'] =		"vcom.exe"
			# self.__executables['asim'] =		"aSim.exe"
		# elif (self._host.platform == "Linux"):
			# self.__executables['alib'] =		"vlib"
			# self.__executables['acom'] =		"vcom"
			# self.__executables['asim'] =		"aSim"

		# # setup all needed paths to execute fuse
		# aLibExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['alib']
		# aComExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['acom']
		# aSimExecutablePath =	self.Host.Directories["aSimBinary"] / self.__executables['asim']
					
					# # assemble acom command as list of parameters
					# parameterList = [
						# str(aComExecutablePath),
						# '-O3',
						# '-relax',
						# '-l', 'acom.log',
						# vhdlStandard,
						# '-work', vhdlLibraryName,
						# str(vhdlFilePath)
					# ]
		# parameterList = [
			# str(aSimExecutablePath)#,
			# # '-vopt',
			# # '-t', '1fs',
		# ]

		# # append RUNOPTS to save simulation results to *.vcd file
		# if (self.__guiMode):
			# parameterList += ['-title', testbenchName]
			
			# if (tclWaveFilePath.exists()):
				# self._LogDebug("Found waveform script: '%s'" % str(tclWaveFilePath))
				# parameterList += ['-do', ('do {%s}; do {%s}' % (str(tclWaveFilePath), str(tclGUIFilePath)))]
			# else:
				# self._LogDebug("Didn't find waveform script: '%s'. Loading default commands." % str(tclWaveFilePath))
				# parameterList += ['-do', ('add wave *; do {%s}' % str(tclGUIFilePath))]
		# else:
			# parameterList += [
				# '-c',
				# '-do', str(tclBatchFilePath)
			# ]
		
		# # append testbench name
		# parameterList += [
			# '-work test', testbenchName
		# ]
		