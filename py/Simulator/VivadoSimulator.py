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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.VivadoSimulator")

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
from Base.Executable				import Executable, CommandLineArgumentList, ExecutableArgument, ShortFlagArgument, ShortValuedFlagArgument, ShortTupleArgument, PathArgument, StringArgument
from Simulator.Exceptions		import *
from Simulator.Base					import PoCSimulator, VHDLTestbenchLibraryName 


class Simulator(PoCSimulator):
	__guiMode =					False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self._guiMode =				guiMode
		self._vivado =				None

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for ghdl if not existent
		self._tempPath = self.Host.Directories["xSimTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

		# if (self._host.platform == "Windows"):
			# self.__executables['xElab'] =		"xelab.bat"
			# self.__executables['xSim'] =		"xsim.bat"
		# elif (self._host.platform == "Linux"):
			# self.__executables['xElab'] =		"xelab"
			# self.__executables['xSim'] =		"xsim"
	
	def PrepareSimulator(self, binaryPath, version):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing GHDL simulator.")
		self._vivado = VivadoSimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)

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
		pocProject.ToolChain =				ToolChain.Xilinx_Vivado
		pocProject.Tool =							Tool.Xilinx_xSim
		pocProject.VHDLVersion =			self._vhdlVersion

		if (deviceName is None):			pocProject.Board =					boardName
		else:													pocProject.Device =					deviceName

		self._pocProject =				pocProject
		
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
		xvhcomp = self._vivado.GetVHDLCompiler()
		xvhcomp.Compile(str(prjFilePath))
		
	def _RunLink(self, testbenchName):
		self._LogNormal("  running xelab...")
		
		xelabLogFilePath =	self._tempPath / (testbenchName + ".xelab.log")
	
		# create one VHDL line for each VHDL file
		xSimProjectFileContent = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not add '{0}' to xSim project file.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			if (self._vhdlVersion == VHDLVersion.VHDL2008):
				xSimProjectFileContent += "vhdl2008 {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))
			else:
				xSimProjectFileContent += "vhdl {0} \"{1}\"\n".format(file.VHDLLibraryName, str(file.Path))

		# write xSim project file
		prjFilePath = self._tempPath / (testbenchName + ".prj")
		self._LogDebug("Writing xSim project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(xSimProjectFileContent)
	
		# create a VivadoLinker instance
		xelab = self._vivado.GetLinker()
		xelab.Parameters[xelab.SwitchTimeResolution] =	"1fs"	# set minimum time precision to 1 fs
		xelab.Parameters[xelab.SwitchMultiThreading] =	"off"	#"4"		# enable multithreading support
		xelab.Parameters[xelab.FlagRangeCheck] =				True

		# xelab.Parameters[xelab.SwitchOptimization] =		"2"
		xelab.Parameters[xelab.SwitchDebug] =						"typical"
		xelab.Parameters[xelab.SwitchSnapshot] =				testbenchName

		# if (self._vhdlVersion == VHDLVersion.VHDL2008):
		# 	xelab.Parameters[xelab.SwitchVHDL2008] =			True

		# if (self.verbose):
		xelab.Parameters[xelab.SwitchVerbose] =					"1"	#"0"
		xelab.Parameters[xelab.SwitchProjectFile] =			str(prjFilePath)
		xelab.Parameters[xelab.SwitchLogFile] =					str(xelabLogFilePath)
		xelab.Parameters[xelab.ArgTopLevel] =						"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		xelab.Link()

	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		xSimLogFilePath =		self._tempPath / (testbenchName + ".xSim.log")
		tclBatchFilePath =	self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimBatchScript']
		tclGUIFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimGUIScript']
		wcfgFilePath =			self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['iSimWaveformConfigFile']

		# create a VivadoSimulator instance
		xSim = self._vivado.GetSimulator()
		xSim.Parameters[xSim.SwitchLogFile] =					str(xSimLogFilePath)

		if (not self._guiMode):
			xSim.Parameters[xSim.SwitchTclBatchFile] =	str(tclBatchFilePath)
		else:
			xSim.Parameters[xSim.SwitchTclBatchFile] =	str(tclGUIFilePath)
			xSim.Parameters[xSim.FlagGuiMode] =					True

			# if xSim save file exists, load it's settings
			if wcfgFilePath.exists():
				self._LogDebug("    Found waveform config file: '{0}'".format(str(wcfgFilePath)))
				xSim.Parameters[xSim.SwitchWaveformFile] =	str(wcfgFilePath)
			else:
				self._LogDebug("    Didn't find waveform config file: '{0}'".format(str(wcfgFilePath)))

		xSim.Simulate()

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
	
		
class VivadoSimulatorExecutable:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self.__logger =							logger
	
	def GetVHDLCompiler(self):
		return VivadoVHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
	def GetLinker(self):
		return VivadoLinker(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
	
	def GetSimulator(self):
		return VivadoSimulator(self._platform, self._binaryDirectoryPath, self._version, logger=self.__logger)
		
class VivadoVHDLCompiler(Executable, VivadoSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		VivadoSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "xvhcomp.bat"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "xvhcomp"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)


	
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
		
class VivadoLinker(Executable, VivadoSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		VivadoSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "xelab.bat"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "xelab"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class FlagRangeCheck(metaclass=ShortFlagArgument):
		_name =		"rangecheck"
		_value =	None

	class SwitchMultiThreading(metaclass=ShortTupleArgument):
		_name =		"mt"
		_value =	None

	class SwitchVerbose(metaclass=ShortTupleArgument):
		_name =		"verbose"
		_value =	None

	class SwitchDebug(metaclass=ShortTupleArgument):
		_name =		"debug"
		_value =	None

	# class SwitchVHDL2008(metaclass=ShortFlagArgument):
	# 	_name =		"vhdl2008"
	# 	_value =	None

	class SwitchOptimization(metaclass=ShortValuedFlagArgument):
		_name =		"O"
		_value =	None

	class SwitchTimeResolution(metaclass=ShortTupleArgument):
		_name =		"timeprecision_vhdl"
		_value =	None

	class SwitchProjectFile(metaclass=ShortTupleArgument):
		_name =		"prj"
		_value =	None

	class SwitchLogFile(metaclass=ShortTupleArgument):
		_name =		"log"
		_value =	None

	class SwitchSnapshot(metaclass=StringArgument):
		_value =	None

	class ArgTopLevel(metaclass=PathArgument):
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		FlagRangeCheck,
		SwitchMultiThreading,
		SwitchTimeResolution,
		SwitchVerbose,
		SwitchDebug,
		# SwitchVHDL2008,
		SwitchOptimization,
		SwitchProjectFile,
		SwitchLogFile,
		SwitchSnapshot,
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
				print(_indent + "xelab messages for : {0}".format("????"))#str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing xelab: {0}".format("????"))#str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class VivadoSimulator(Executable, VivadoSimulatorExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[], logger=None):
		VivadoSimulatorExecutable.__init__(self, platform, binaryDirectoryPath, version, logger=logger)
		
		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "xsim.bat"
		elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "xsim"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class SwitchLogFile(metaclass=ShortTupleArgument):
		_name =		"-log"
		_value =	None

	class FlagGuiMode(metaclass=ShortFlagArgument):
		_name =		"-gui"
		_value =	None

	class SwitchTclBatchFile(metaclass=ShortTupleArgument):
		_name =		"-tclbatch"
		_value =	None

	class SwitchWaveformFile(metaclass=ShortTupleArgument):
		_name =		"-view"
		_value =	None

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
			xSimLog = self.StartProcess(parameterList)
			
			log = ""
			for line in xSimLog.split("\n")[:-1]:
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "xsim messages for : {0}".format("????"))#str("????"))#filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing xsim: {0}".format("????"))#str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
