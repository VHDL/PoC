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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.vSimSimulator")

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
from Base.Executable				import Executable, CommandLineArgumentList, ExecutableArgument, FlagArgument, StringArgument, TupleArgument, PathArgument
from Simulator.Exceptions		import * 
from Simulator.Base					import PoCSimulator, VHDLTestbenchLibraryName

class Simulator(PoCSimulator):
	__guiMode =				False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self._guiMode =				guiMode
		self._questa =				None

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.Host.Directories["vSimTemp"]
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
		self._LogVerbose("  Preparing Mentor simulator.")
		self._questa =		QuestaSimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)

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

		# create a QuestaVHDLCompiler instance
		vlib = self._questa.GetVHDLLibraryTool()
		vlib.Parameters[vlib.FlagVerbose] = True

		for lib in self._pocProject.VHDLLibraries:
			vlib.Parameters[vlib.SwitchVHDLLibrary] = lib.Name
			vlib.CreateLibrary()

		# create a QuestaVHDLCompiler instance
		vcom = self._questa.GetVHDLCompiler()
		vcom.Parameters[vcom.SwitchVHDLversion] =	self._vhdlversion
		vcom.Parameters[vcom.FlagVerbose] =				True
		vcom.Parameters[vcom.RangeCheck] =				True
		#acom.RangeCheck =		True

		# run vcom compile for each VHDL file
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not analyse '{0}'.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			vcom.Parameters[vcom.SwitchVHDLLibrary] =	file.VHDLLibraryName
			vcom.Parameters[vcom.ArgSourceFile] =			file.Path
			# set a per file log-file with '-l', 'vcom.log',
			vcom.Compile()

	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		tclBatchFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['vSimBatchScript']
		
		# create a QuestaSimulator instance
		vsim = self._questa.GetSimulator()
		vsim.Parameters[vsim.FlagOptimization] =			True
		vsim.Parameters[vsim.SwitchTimeResolution] =	"1fs"
		vsim.Parameters[vsim.FlagCommandLineMode] =		True
		vsim.Parameters[vsim.SwitchBatchCommand] =		"do {0}".format(str(tclBatchFilePath))
		vsim.Parameters[vsim.SwitchTopLevel] =				"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		vsim.Simulate()
		
	def _RunSimulationWithGUI(self, testbenchName):
		self._LogNormal("  running simulation...")
	
		tclGUIFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['vSimGUIScript']
		tclWaveFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['vSimWaveScript']

		# create a QuestaSimulator instance
		vsim = self._questa.GetSimulator()
		vsim.Parameters[vsim.FlagOptimization] =			True
		vsim.Parameters[vsim.SwitchTimeResolution] =	"1fs"
		vsim.Parameters[vsim.SwitchTitke] =						testbenchName
		vsim.Parameters[vsim.SwitchTopLevel] =				"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)

		if (tclWaveFilePath.exists()):
			self._LogDebug("Found waveform script: '{0}'".format(str(tclWaveFilePath)))
			vsim.Parameters[vsim.SwitchBatchCommand] =	"do {0}; do {0}".format(str(tclWaveFilePath), str(tclGUIFilePath))
		else:
			self._LogDebug("Didn't find waveform script: '{0}'. Loading default commands.".format(str(tclWaveFilePath)))
			vsim.Parameters[vsim.SwitchBatchCommand] =	"add wave *; do {0}".format(str(tclGUIFilePath))

		vsim.Simulate()

		# if (not self.__guiMode):
			# try:
				# result = self.checkSimulatorOutput(simulatorLog)
				
				# if (result == True):
					# print("Testbench '%s': PASSED" % testbenchName)
				# else:
					# print("Testbench '%s': FAILED" % testbenchName)
					
			# except SimulatorException as ex:
				# raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
		
class QuestaSimulatorExecutable:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self.__logger =							logger
	
	def GetVHDLCompiler(self):
		return QuestaVHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
	def GetSimulator(self):
		return QuestaSimulator(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
	def GetVHDLLibraryTool(self):
		return QuestaVHDLLibraryTool(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)

class QuestaVHDLCompiler(Executable, QuestaSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		QuestaSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vcom.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vcom"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class FlagVerbose(metaclass=FlagArgument):
		_name =		"-v"
		_value =	None
	
	class FlagRangeCheck(metaclass=FlagArgument):
		_name =		"-fexplicit"
		_value =	None
	
	class SwitchVHDLVersion(metaclass=StringArgument):
		_name =		"-"
		_value =	None
	
	class SwitchVHDLLibrary(metaclass=TupleArgument):
		_name =		"-work"
		_value =	None

	class ArgSourceFile(metaclass=PathArgument):
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		FlagVerbose,
		FlagRangeCheck,
		SwitchVHDLVersion,
		SwitchVHDLLibrary,
		ArgSourceFile
	)
	
# 		if (value == "87"):										self._defaultParameters.append("-87")
# 		elif (value == "93"):									self._defaultParameters.append("-93")
# 		elif (value == "02"):									self._defaultParameters.append("-2002")
# 		elif (value == "08"):									self._defaultParameters.append("-2008")
	
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

class QuestaSimulator(Executable, QuestaSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		QuestaSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vsim.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vsim"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class FlagVerbose(metaclass=FlagArgument):
		_name =		"-v"
		_value =	None

	class FlagOptimization(metaclass=FlagArgument):
		_name =		"-vopt"
		_value =	None

	class FlagCommandLineMode(metaclass=FlagArgument):
		_name =		"-c"
		_value =	None

	class SwitchTimeResolution(metaclass=TupleArgument):
		_name =		"-t"
		_value =	None

	class SwitchBatchCommand(metaclass=TupleArgument):
		_name =		"-do"
		_value =	None

	class SwitchTopLevel(metaclass=StringArgument):
		_name =		""
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		FlagVerbose,
		FlagOptimization,
		FlagCommandLineMode,
		SwitchTimeResolution,
		SwitchBatchCommand,
		SwitchTopLevel
	)

	# units = ("fs", "ps", "us", "ms", "sec", "min", "hr")


	def Simulate(self, testbenchName):
		parameterList = self._defaultParameters.copy()
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			vsimLog = self.StartProcess(parameterList)
			
			log = ""
			for line in vsimLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vsim messages for : {0}".format(testbenchName))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vsim: {0}".format(testbenchName))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class QuestaVHDLLibraryTool(Executable, QuestaSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		QuestaSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vlib.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vlib"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class FlagVerbose(metaclass=FlagArgument):
		_name =		"-v"
		_value =	None

	class SwitchLibraryName(metaclass=StringArgument):
		_name =		""
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		FlagVerbose,
		SwitchLibraryName
	)
	
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
	