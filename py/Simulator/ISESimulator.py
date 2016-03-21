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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.ISESimulator")

# load dependencies
from pathlib import Path
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
	__guiMode =					False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__guiMode =					guiMode

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.Host.Directories["iSimTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

		# if (self._host.platform == "Windows"):
			# self.__executables['vhcomp'] =	"vhpcomp.exe"
			# self.__executables['fuse'] =		"fuse.exe"
		# elif (self._host.platform == "Linux"):
			# self.__executables['vhcomp'] =	"vhpcomp"
			# self.__executables['fuse'] =		"fuse"

	def PrepareSimulator(self, binaryPath, version):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing GHDL simulator.")
		self._ise = ISESimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)

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
		
		# self._RunCompile(testbenchName)
		self._RunLink(testbenchName)
		self._RunSimulation(testbenchName)
		
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
		elif (self._vhdlversion == "93c"):	pocProject.VHDLVersion =		VHDLVersion.VHDL93
		elif (self._vhdlversion == "02"):		pocProject.VHDLVersion =		VHDLVersion.VHDL02
		elif (self._vhdlversion == "08"):		pocProject.VHDLVersion =		VHDLVersion.VHDL08
		
		self._pocProject = pocProject
		
	def _AddFileListFile(self, fileListFilePath):
		self._LogDebug("    Reading filelist '{0}'".format(str(fileListFilePath)))
		# add the *.files file, parse and evaluate it
		try:
			fileListFile = self._pocProject.AddFile(FileListFile(fileListFilePath))
			fileListFile.Parse()
			fileListFile.CopyFilesToFileSet()
			fileListFile.CopyExternalLibraries()
			self._pocProject._ResolveVHDLLibraries()
		except ParserException as ex:										raise SimulatorException("Error while parsing '{0}'.".format(str(fileListFilePath))) from ex
		
		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		if (len(fileListFile.Warnings) > 0):
			for warn in fileListFile.Warnings:
				self._LogWarning(warn)
			raise SimulatorException("Found critical warnings while parsing '{0}'".format(str(fileListFilePath)))
		
	def _RunCompile(self, testbenchName):
		self._LogNormal("  compiling source files...")
		
		# create one VHDL line for each VHDL file
		xSimProjectFileContent = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not add '{0}' to xSim project file.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			xSimProjectFileContent += "vhdl {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))
						
		# write xSim project file
		prjFilePath = self._tempPath / (testbenchName + ".prj")
		self._LogDebug("Writing xSim project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(xSimProjectFileContent)
		
		# create a VivadoVHDLCompiler instance
		vhcomp = self._ise.GetVHDLCompiler()
		vhcomp.Compile(str(prjFilePath))
		
	def _RunLink(self, testbenchName):
		self._LogNormal("  running fuse...")
		
		exeFilePath =				self._tempPath / (testbenchName + ".exe")
	
		# create one VHDL line for each VHDL file
		xSimProjectFileContent = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not add '{0}' to xSim project file.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			xSimProjectFileContent += "vhdl {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))
						
		# write xSim project file
		prjFilePath = self._tempPath / (testbenchName + ".prj")
		self._LogDebug("Writing xSim project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(xSimProjectFileContent)
	
		# create a ISELinker instance
		fuse = self._ise.GetLinker()
		# fuse.Incremental =		True
		# fuse.TimeResolution = "1fs"
		# fuse.MultiThreading =	4
		# fuse.RangeCheck =			True
		# fuse.TopLevel =				"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		# fuse.Project =				str(prjFilePath)
		# fuse.Executable =			str(exeFilePath)
		
		parameterList = [
			('test.%s' % testbenchName),
			'--incremental',
			'--timeprecision_vhdl', '1fs',			# set minimum time precision to 1 fs
			'--mt', '4',												# enable multithread support
			'--rangecheck',
			'--prj',	str(prjFilePath),
			'-o',			str(exeFilePath)
		]
		fuse.Link(parameterList)
	
	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		iSimLogFilePath =		self._tempPath / (testbenchName + ".iSim.log")
		exeFilePath =				self._tempPath / (testbenchName + ".exe")
		tclBatchFilePath =	self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimBatchScript']
		tclGUIFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimGUIScript']
		wcfgFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimWaveformConfigFile']

		# create a ISESimulator instance
		iSim = self._ise.GetSimulator()
		# iSim.LogFile =				str(iSimLogFilePath)
		# iSim.TimeResolution = "1fs"
		# iSim.MultiThreading =	4
		# iSim.RangeCheck =			True
		# iSim.TopLevel =				"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		# iSim.Project =				str(prjFilePath)
		# iSim.Executable =			str(exeFilePath)
		
		parameterList = [
			'-log', str(iSimLogFilePath)
		]
		
		if (not self.__guiMode):
			parameterList += ['-tclbatch', str(tclBatchFilePath)]
		else:
			parameterList += [
				'-tclbatch', str(tclGUIFilePath),
				'-gui'
			]
		
		# if GTKWave savefile exists, load it's settings
		if wcfgFilePath.exists():
			self._LogDebug("    Found waveform config file: '{0}'".format(str(wcfgFilePath)))
			# gtkw.WaveformFile = str(wcfgFilePath)
			parameterList += ['-view', str(wcfgFilePath)]
		else:
			self._LogDebug("    Didn't find waveform config file: '{0}'".format(str(wcfgFilePath)))
		
		iSim.Simulate(parameterList)
		
		# print()
		# if (not self.__guiMode):
			# try:
				# result = self.checkSimulatorOutput(simulatorLog)
				
				# if (result == True):
					# print("Testbench '%s': PASSED" % testbenchName)
				# else:
					# print("Testbench '%s': FAILED" % testbenchName)
					
			# except SimulatorException as ex:
				# raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
	
class ISESimulatorExecutable:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self.__logger =							logger
	
	def GetVHDLCompiler(self):
		return ISEVHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
	def GetLinker(self):
		return ISELinker(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
	def GetSimulator(self):
		return ISESimulator(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
class ISEVHDLCompiler(Executable, ISESimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ISESimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vhcomp.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vhcomp"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self._verbose =						False
		self._rangecheck =				False
		self._vhdlVersion =				None
		self._vhdlLibrary =				None
	
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
	
	@property
	def RangeCheck(self):
		return self._rangecheck
	@RangeCheck.setter
	def RangeCheck(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._rangecheck != value):
			self._rangecheck = value
			if value:			self._defaultParameters.append("-rangecheck")
			else:					self._defaultParameters.remove("-rangecheck")
	
	def Compile(self, vhdlFile):
		parameterList = self._defaultParameters.copy()
		parameterList.append(vhdlFile)
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			vhcompLog = self.StartProcess(parameterList)
			
			log = ""
			for line in vhcompLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vlib messages for : {0}".format(str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vlib: {0}".format(str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
		
class ISELinker(Executable, ISESimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ISESimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "fuse.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "fuse"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self._verbose =						False
		self._rangecheck =				False
		self._vhdlVersion =				None
		self._vhdlLibrary =				None
	
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
	
	@property
	def RangeCheck(self):
		return self._rangecheck
	@RangeCheck.setter
	def RangeCheck(self, value):
		if (not isinstance(value, bool)):								raise ValueError("Parameter 'value' is not of type bool.")
		if (self._rangecheck != value):
			self._rangecheck = value
			if value:			self._defaultParameters.append("-rangecheck")
			else:					self._defaultParameters.remove("-rangecheck")
	
	def Link(self, paramList):
		parameterList = self._defaultParameters.copy()
		parameterList += paramList
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			fuseLog = self.StartProcess(parameterList)
			
			log = ""
			for line in fuseLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vlib messages for : {0}".format(str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vlib: {0}".format(str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class ISESimulator(Executable, ISESimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		ISESimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "isim.exe"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "isim"
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
	
	def Simulate(self, paramList):
		parameterList = self._defaultParameters.copy()
		parameterList += paramList
		
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			isimLog = self.StartProcess(parameterList)
			
			log = ""
			for line in isimLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "vsim messages for : {0}".format(str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vsim: {0}".format(str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)