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
from subprocess							import CalledProcessError

from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Base.Executable				import Executable, CommandLineArgumentList, ExecutableArgument, ShortFlagArgument, ShortValuedFlagArgument, ShortTupleArgument, PathArgument
from Simulator.Exceptions		import *
from Simulator.Base					import PoCSimulator, VHDLTestbenchLibraryName


class Simulator(PoCSimulator):
	__guiMode =					False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self._guiMode =				guiMode
		self._ise =						None

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
		self._ise = ISESimulatorExecutables(self.Host.Platform, binaryPath, version, logger=self.Logger)

	def RunAll(self, pocEntities, **kwargs):
		for pocEntity in pocEntities:
			self.Run(pocEntity, **kwargs)

	def Run(self, pocEntity, boardName=None, deviceName=None, vhdlVersion="93", vhdlGenerics=None):
		self._pocEntity =			pocEntity
		self._testbenchFQN =	str(pocEntity)										# TODO: implement FQN method on PoCEntity
		self._vhdlVersion =		VHDLVersion.parse(vhdlVersion)		# TODO: move conversion one level up
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
		pocProject.ToolChain =				ToolChain.Xilinx_ISE
		pocProject.Tool =							Tool.Xilinx_iSim
		pocProject.VHDLVersion =			self._vhdlVersion

		if (deviceName is None):			pocProject.Board =					boardName
		else:													pocProject.Device =					deviceName
		
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
		iSimProjectFileContent = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not add '{0}' to iSim project file.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			iSimProjectFileContent += "vhdl {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))

		# write iSim project file
		prjFilePath = self._tempPath / (testbenchName + ".prj")
		self._LogDebug("Writing iSim project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(iSimProjectFileContent)
		
		# create a VivadoVHDLCompiler instance
		vhcomp = self._ise.GetVHDLCompiler()
		vhcomp.Compile(str(prjFilePath))

	def _RunLink(self, testbenchName):
		self._LogNormal("  running fuse...")
		
		exeFilePath =				self._tempPath / (testbenchName + ".exe")

		# create one VHDL line for each VHDL file
		iSimProjectFileContent = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not add '{0}' to iSim project file.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			iSimProjectFileContent += "vhdl {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))

		# write iSim project file
		prjFilePath = self._tempPath / (testbenchName + ".prj")
		self._LogDebug("Writing iSim project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(iSimProjectFileContent)

		# create a ISELinker instance
		fuse = self._ise.GetLinker()
		fuse.Parameters[fuse.FlagIncremental] =				True
		fuse.Parameters[fuse.SwitchTimeResolution] =	"1fs"
		fuse.Parameters[fuse.SwitchMultiThreading] =	"4"
		fuse.Parameters[fuse.FlagRangeCheck] =				True
		fuse.Parameters[fuse.SwitchProjectFile] =			str(prjFilePath)
		fuse.Parameters[fuse.SwitchOutputFile] =			str(exeFilePath)
		fuse.Parameters[fuse.ArgTopLevel] =						"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		fuse.Link()
	
	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		iSimLogFilePath =		self._tempPath / (testbenchName + ".iSim.log")
		exeFilePath =				self._tempPath / (testbenchName + ".exe")
		tclBatchFilePath =	self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimBatchScript']
		tclGUIFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimGUIScript']
		wcfgFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimWaveformConfigFile']

		# create a ISESimulator instance
		iSim = ISESimulatorExecutable(exeFilePath, logger=self.Logger)
		iSim.Parameters[iSim.SwitchLogFile] =					str(iSimLogFilePath)

		if (not self._guiMode):
			iSim.Parameters[iSim.SwitchTclBatchFile] =	str(tclBatchFilePath)
		else:
			iSim.Parameters[iSim.SwitchTclBatchFile] =	str(tclGUIFilePath)
			iSim.Parameters[iSim.FlagGuiMode] =					True

			# if iSim save file exists, load it's settings
			if wcfgFilePath.exists():
				self._LogDebug("    Found waveform config file: '{0}'".format(str(wcfgFilePath)))
				iSim.Parameters[iSim.SwitchWaveformFile] =	str(wcfgFilePath)
			else:
				self._LogDebug("    Didn't find waveform config file: '{0}'".format(str(wcfgFilePath)))

		iSim.Simulate()

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
	
class ISESimulatorExecutables:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self.__logger =							logger
	
	def GetVHDLCompiler(self):
		raise NotImplementedException()
		# return ISEVHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
	def GetLinker(self):
		return ISELinker(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
# class ISEVHDLCompiler(Executable, ISESimulatorExecutable):
# 	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
# 		ISESimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
#
# 		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vhcomp.exe"
# 		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vhcomp"
# 		else:																						raise PlatformNotSupportedException(self._platform)
# 		super().__init__(platform, executablePath, defaultParameters, logger=logger)
#
# 	def Compile(self, vhdlFile):
# 		parameterList = self.Parameters.ToArgumentList()
#
# 		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
#
# 		_indent = "    "
# 		try:
# 			vhcompLog = self.StartProcess(parameterList)
#
# 			log = ""
# 			for line in vhcompLog.split("\n")[:-1]:
# 					log += _indent + line + "\n"
#
# 			# if self.showLogs:
# 			if (log != ""):
# 				print(_indent + "vlib messages for : {0}".format(str(vhdlFile)))
# 				print(_indent + "-" * 80)
# 				print(log[:-1])
# 				print(_indent + "-" * 80)
# 		except CalledProcessError as ex:
# 			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing vlib: {0}".format(str(vhdlFile)))
# 			print(_indent + "Return Code: {0}".format(ex.returncode))
# 			print(_indent + "-" * 80)
# 			for line in ex.output.split("\n"):
# 				print(_indent + line)
# 			print(_indent + "-" * 80)
		
class ISELinker(Executable, ISESimulatorExecutables):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		if (platform == "Windows"):		executablePath = binaryDirectoryPath / "fuse.exe"
		elif (platform == "Linux"):		executablePath = binaryDirectoryPath / "fuse"
		else:																						raise PlatformNotSupportedException(self._platform)
		Executable.__init__(self, platform, executablePath, defaultParameters, logger=logger)
		ISESimulatorExecutables.__init__(self, platform, binaryDirectoryPath, version, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):						pass

	class FlagIncremental(metaclass=ShortFlagArgument):
		_name =		"incremental"

	# FlagIncremental = ShortFlagArgument(_name="incremntal")

	class FlagRangeCheck(metaclass=ShortFlagArgument):
		_name =		"rangecheck"

	class SwitchMultiThreading(metaclass=ShortTupleArgument):
		_name =		"mt"

	class SwitchTimeResolution(metaclass=ShortTupleArgument):
		_name =		"timeprecision_vhdl"

	class SwitchProjectFile(metaclass=ShortTupleArgument):
		_name =		"prj"

	class SwitchOutputFile(metaclass=ShortTupleArgument):
		_name =		"o"

	class ArgTopLevel(metaclass=PathArgument):					pass

	Parameters = CommandLineArgumentList(
		Executable,
		FlagIncremental,
		FlagRangeCheck,
		SwitchMultiThreading,
		SwitchTimeResolution,
		SwitchProjectFile,
		SwitchOutputFile,
		ArgTopLevel
	)
	
	def Link(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			fuseLog = self.StartProcess(parameterList)
			
			log = ""
			for line in fuseLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "fuse messages for : {0}".format("????"))#str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing fuse: {0}".format("????"))#str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class ISESimulatorExecutable(Executable):
	def __init__(self, executablePath, logger=None):
		super().__init__("", executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):			pass

	class SwitchLogFile(metaclass=ShortTupleArgument):
		_name =		"log"

	class FlagGuiMode(metaclass=ShortFlagArgument):
		_name =		"gui"

	class SwitchTclBatchFile(metaclass=ShortTupleArgument):
		_name =		"tclbatch"

	class SwitchWaveformFile(metaclass=ShortTupleArgument):
		_name =		"view"

	Parameters = CommandLineArgumentList(
		Executable,
		SwitchLogFile,
		FlagGuiMode,
		SwitchTclBatchFile,
		SwitchWaveformFile
	)

	def Simulate(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			isimLog = self.StartProcess(parameterList)
			
			log = ""
			for line in isimLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "isim messages for : {0}".format("????"))#str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing isim: {0}".format("????"))#str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)