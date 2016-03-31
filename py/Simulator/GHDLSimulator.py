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
from symbol import parameters
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.GHDLSimulator")

# load dependencies
from pathlib								import Path
from configparser						import NoSectionError
from colorama								import Fore as Foreground
from os											import chdir
import re								# used for output filtering
from subprocess							import CalledProcessError

from Base.Exceptions				import *
from Base.PoCConfig					import *
from Base.Project						import FileTypes
from Base.PoCProject				import *
from Base.Executable				import *
from Parser.Parser					import ParserException
from Simulator.Exceptions		import *
from Simulator.Base					import PoCSimulator, VHDLTestbenchLibraryName

class Simulator(PoCSimulator):
	_guiMode =										False

	def __init__(self, host, showLogs, showReport, guiMode):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self._guiMode =				guiMode
		self._tempPath =			None
		self._ghdl =					None

		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("preparing simulation environment...")
		# create temporary directory for GHDL if not existent
		self._tempPath = self.Host.Directories["GHDLTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directory: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)
			
		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

	def PrepareSimulator(self, binaryPath, version, backend):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing GHDL simulator.")
		self._ghdl =			GHDLExecutable(self.Host.Platform, binaryPath, version, backend, logger=self.Logger)

	def RunAll(self, pocEntities, **kwargs):
		for pocEntity in pocEntities:
			self.Run(pocEntity, **kwargs)
		
	def Run(self, pocEntity, boardName=None, deviceName=None, vhdlVersion="93c", vhdlGenerics=None):
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
		pocProject.RootDirectory =		self.Host.Directories["PoCRoot"]
		pocProject.Environment =			Environment.Simulation
		pocProject.ToolChain =				ToolChain.GHDL_GTKWave
		pocProject.Tool =							Tool.GHDL
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
		
	def _RunAnalysis(self):
		self._LogNormal("  running analysis for every vhdl file...")
		
		# create a GHDLAnalyzer instance
		ghdl = self._ghdl.GetGHDLAnalyze()
		ghdl.Parameters[ghdl.FlagVerbose] =						True
		ghdl.Parameters[ghdl.FlagExplicit] =					True
		ghdl.Parameters[ghdl.FlagRelaxedRules] =			True
		ghdl.Parameters[ghdl.FlagWarnBinding] =				True
		ghdl.Parameters[ghdl.FlagNoVitalChecks] =			True
		ghdl.Parameters[ghdl.FlagMultiByteComments] =	True
		ghdl.Parameters[ghdl.FlagSynBinding] =				True
		ghdl.Parameters[ghdl.FlagPSL] =								True

		if (self._vhdlVersion == VHDLVersion.VHDL87):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"87"
			ghdl.Parameters[ghdl.SwitchIEEEFlavor] =		"synopsys"
		elif (self._vhdlVersion == VHDLVersion.VHDL93):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"93"
			ghdl.Parameters[ghdl.SwitchIEEEFlavor] =		"synopsys"
		elif (self._vhdlVersion == VHDLVersion.VHDL02):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"02"
		elif (self._vhdlVersion == VHDLVersion.VHDL08):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"08"
		else:																					raise SimulatorException("VHDL version is not supported.")

		# add external library references
		ghdl.Parameters[ghdl.ArgListLibraryReferences] = [str(extLibrary.Path) for extLibrary in self._pocProject.ExternalVHDLLibraries]
		
		# run GHDL analysis for each VHDL file
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not analyse '{0}'.".format(str(file.Path))) from FileNotFoundError(str(file.Path))

			ghdl.Parameters[ghdl.SwitchVHDLLibrary] =			file.VHDLLibraryName
			ghdl.Parameters[ghdl.ArgSourceFile] =					file.Path
			ghdl.Analyze()

	# running simulation
	# ==========================================================================
	def _RunElaboration(self):
		self._LogNormal("  elaborate simulation...")
		
		# create a GHDLElaborate instance
		ghdl = self._ghdl.GetGHDLElaborate()
		ghdl.VHDLVersion =	self._vhdlVersion
		ghdl.VHDLLibrary =	VHDLTestbenchLibraryName

		# add external library references
		ghdl.Parameters[ghdl.ArgListLibraryReferences] = [str(extLibrary.Path) for extLibrary in self._pocProject.ExternalVHDLLibraries]


#		parameterList.append(topLevel)
#		if (topLevelArchitecture is not None):
#			parameterList.append(topLevelArchitecture)

		ghdl.Elaborate("arith_prng_tb")
	
	
	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
			
		# create a GHDLRun instance
		ghdl = self._ghdl.GetGHDLRun()
		ghdl.Parameters[ghdl.FlagVerbose] =						True
		ghdl.Parameters[ghdl.FlagExplicit] =					True
		ghdl.Parameters[ghdl.FlagRelaxedRules] =			True
		ghdl.Parameters[ghdl.FlagWarnBinding] =				True
		ghdl.Parameters[ghdl.FlagNoVitalChecks] =			True
		ghdl.Parameters[ghdl.FlagMultiByteComments] =	True
		ghdl.Parameters[ghdl.FlagSynBinding] =				True
		ghdl.Parameters[ghdl.FlagPSL] =								True
		ghdl.Parameters[ghdl.SwitchVHDLLibrary] =			VHDLTestbenchLibraryName
		ghdl.Parameters[ghdl.ArgTopLevel] =						testbenchName

		if (self._vhdlVersion == VHDLVersion.VHDL87):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"87"
			ghdl.Parameters[ghdl.SwitchIEEEFlavor] =		"synopsys"
		elif (self._vhdlVersion == VHDLVersion.VHDL93):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"93"
			ghdl.Parameters[ghdl.SwitchIEEEFlavor] =		"synopsys"
		elif (self._vhdlVersion == VHDLVersion.VHDL02):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"02"
		elif (self._vhdlVersion == VHDLVersion.VHDL08):
			ghdl.Parameters[ghdl.SwitchVHDLVersion] =		"08"
		else:																					raise SimulatorException("VHDL version is not supported.")

		# add external library references
		ghdl.Parameters[ghdl.ArgListLibraryReferences] = [str(extLibrary.Path) for extLibrary in self._pocProject.ExternalVHDLLibraries]

		# configure RUNOPTS
		ghdl.RunOptions[ghdl.SwitchIEEEAsserts] = "disable-at-0"		# enable, disable, disable-at-0
		# set dump format to save simulation results to *.vcd file
		if (self._guiMode):
			waveformFileFormat =	self.Host.tbConfig[self._testbenchFQN]['ghdlWaveformFileFormat']
			if (waveformFileFormat == "vcd"):
				waveformFilePath = self._tempPath / (testbenchName + ".vcd")
				ghdl.RunOptions[ghdl.SwitchVCDWaveform] =		waveformFilePath
			elif (waveformFileFormat == "vcdgz"):
				waveformFilePath = self._tempPath / (testbenchName + ".vcd.gz")
				ghdl.RunOptions[ghdl.SwitchVCDGZWaveform] =	waveformFilePath
			elif (waveformFileFormat == "fst"):
				waveformFilePath = self._tempPath / (testbenchName + ".fst")
				ghdl.RunOptions[ghdl.SwitchFSTWaveform] =		waveformFilePath
			elif (waveformFileFormat == "ghw"):
				waveformFilePath = self._tempPath / (testbenchName + ".ghw")
				ghdl.RunOptions[ghdl.SwitchGHDLWaveform] =	waveformFilePath
			else:																						raise SimulatorException("Unknown waveform file format for GHDL.")
		
		ghdl.Run()
		
	def _ExecuteSimulation(self, testbenchName):
		self._LogNormal("  launching simulation...")
			
		# create a GHDLRun instance
		ghdl = self._ghdl.GetGHDLRun()
		ghdl.VHDLVersion =	self._vhdlVersion
		ghdl.VHDLLibrary =	VHDLTestbenchLibraryName
		
		# configure RUNOPTS
		runOptions = []
		runOptions.append('--ieee-asserts={0}'.format("disable-at-0"))		# enable, disable, disable-at-0
		# set dump format to save simulation results to *.vcd file
		if (self._guiMode):
			waveformFileFormat =	self.Host.tbConfig[self._testbenchFQN]['ghdlWaveformFileFormat']
					
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
	
	def GetViewer(self):
		return self
	
	def View(self, pocEntity):
		self._LogNormal("  launching GTKWave...")
		
		testbenchName =				self.Host.tbConfig[self._testbenchFQN]['TestbenchModule']
		waveformFileFormat =	self.Host.tbConfig[self._testbenchFQN]['ghdlWaveformFileFormat']
					
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
		
		gtkwBinaryPath =		self.Host.Directories["GTKWBinary"]
		gtkwVersion =				self.Host.pocConfig['GTKWave']['Version']
		gtkw = GTKWave(self.Host.Platform, gtkwBinaryPath, gtkwVersion)
		
		gtkwSaveFilePath =	self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['gtkwSaveFile']

		
		# if GTKWave savefile exists, load it's settings
		if gtkwSaveFilePath.exists():
			self._LogDebug("    Found waveform save file: '{0}'".format(str(gtkwSaveFilePath)))
			gtkw.SaveFile = str(gtkwSaveFilePath)
		else:
			self._LogDebug("    Didn't find waveform save file: '{0}'".format(str(gtkwSaveFilePath)))
		
		# run GTKWave GUI
		gtkw.View(waveformFilePath)
		
		# clean-up *.gtkw files
		if gtkwSaveFilePath.exists():
			self._LogNormal("    cleaning up GTKWave save file...")
			removeKeys = ("[dumpfile]", "[savefile]")
			buffer = ""
			with gtkwSaveFilePath.open('r') as gtkwHandle:
				lineNumber = 0
				for lineNumber,line in enumerate(gtkwHandle):
					lineNumber += 1
					if (not line.startswith(removeKeys)):			buffer += line
					if (lineNumber > 10):											break
				for line in gtkwHandle:
					buffer += line
			with gtkwSaveFilePath.open('w') as gtkwHandle:
				gtkwHandle.write(buffer)
# 		
# 		# run GHDL simulation on Linux
# 		if (self.Host.Platform == "Linux"):
# 			# preparing some variables for Linux
# 			exeFilePath =		tempGHDLPath / testbenchName.lower()
# 		
# 			# run elaboration
# 			self._LogNormal("  running elaboration...")
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
# 			except SimulatorException as ex:
# 				raise TestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED|NO ASSERTS]' not found in simulator output.") from ex
# 		
# 		else:	# guiMode
# 			# run GTKWave GUI
# 			self._LogNormal("  launching GTKWave...")
# 			
# 			if (not waveformFilePath.exists()):
# 				raise SimulatorException("Waveform file not found.") from FileNotFoundError(str(waveformFilePath))
# 
# 			gtkwExecutablePath =	self.Host.Directories["GTKWBinary"] / self.__executables['gtkwave']
# 			gtkwSaveFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[testbenchFQN]['gtkwSaveFile']
# 		
# 			parameterList = [
# 				str(gtkwExecutablePath),
# 				("--dump={0}".format(str(waveformFilePath)))
# 			]
# 
# 			# if GTKWave savefile exists, load it's settings
# 			if gtkwSaveFilePath.exists():
# 				self._LogDebug("Found waveform save file: '%s'" % str(gtkwSaveFilePath))
# 				parameterList += ['--save', str(gtkwSaveFilePath)]
# 			else:
# 				self._LogDebug("Didn't find waveform save file: '%s'." % str(gtkwSaveFilePath))
#
# 				if gtkwSaveFilePath.exists():
# 					for line in fileinput.input(str(gtkwSaveFilePath), inplace = 1):
# 						if line.startswith(('[dumpfile', '[savefile')):
# 							continue
# 						print(line.rstrip(os.linesep))
#

class GHDLExecutable(Executable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, defaultParameters=[], logger=None):
		if (platform == "Windows"):			executablePath = binaryDirectoryPath/ "ghdl.exe"
		elif (platform == "Linux"):			executablePath = binaryDirectoryPath/ "ghdl"
		else:																						raise PlatformNotSupportedException(platform)
		super().__init__(platform, executablePath, defaultParameters, logger=logger)

		self.Parameters[self.Executable] = executablePath
		
		if (platform == "Windows"):
			if (backend not in ["mcode"]):								raise SimulatorException("GHDL for Windows does not support backend '{0}'.".format(backend))
		elif (platform == "Linux"):
			if (backend not in ["gcc", "llvm", "mcode"]):	raise SimulatorException("GHDL for Linux does not support backend '{0}'.".format(backend))
		
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._backend =							backend
		self._version =							version
		
	@property
	def BinaryDirectoryPath(self):
		return self._binaryDirectoryPath
	
	@property
	def Backend(self):
		return self._backend

	@property
	def Version(self):
		return self._version

	class Executable(metaclass=ExecutableArgument):
		pass

	class CmdAnalyze(metaclass=ShortFlagArgument):
		_name =		"a"

	class CmdElaborate(metaclass=ShortFlagArgument):
		_name =		"e"

	class CmdRun(metaclass=ShortFlagArgument):
		_name =		"r"

	class FlagVerbose(metaclass=ShortFlagArgument):
		_name =		"v"

	class FlagExplicit(metaclass=ShortFlagArgument):
		_name =		"fexplicit"

	class FlagRelaxedRules(metaclass=ShortFlagArgument):
		_name =		"frelaxed-rules"

	class FlagWarnBinding(metaclass=LongFlagArgument):
		_name =		"warn-binding"

	class FlagNoVitalChecks(metaclass=LongFlagArgument):
		_name =		"no-vital-checks"

	class FlagMultiByteComments(metaclass=LongFlagArgument):
		_name =		"mb-comments"

	class FlagSynBinding(metaclass=LongFlagArgument):
		_name =		"syn-binding"

	class FlagPSL(metaclass=ShortFlagArgument):
		_name =		"fpsl"

	class SwitchIEEEFlavor(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"ieee"

	class SwitchVHDLVersion(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"std"
	
	class SwitchVHDLLibrary(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"work"

	class ArgListLibraryReferences(metaclass=ValuedFlagListArgument):
		_pattern =	"-{0}{1}"
		_name =			"P"

	class ArgSourceFile(metaclass=PathArgument):
		pass

	class ArgTopLevel(metaclass=StringArgument):
		pass

	Parameters = CommandLineArgumentList(
		Executable,
		CmdAnalyze,
		CmdElaborate,
		CmdRun,
		FlagVerbose,
		FlagExplicit,
		FlagRelaxedRules,
		FlagWarnBinding,
		FlagNoVitalChecks,
		FlagMultiByteComments,
		FlagSynBinding,
		FlagPSL,
		SwitchIEEEFlavor,
		SwitchVHDLVersion,
		SwitchVHDLLibrary,
		ArgListLibraryReferences,
		ArgSourceFile,
		ArgTopLevel
	)

	class SwitchIEEEAsserts(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"ieee-asserts"

	class SwitchVCDWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"vcd"

	class SwitchVCDGZWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"vcdgz"

	class SwitchFastWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"fst"

	class SwitchGHDLWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"wave"

	RunOptions = CommandLineArgumentList(
		SwitchIEEEAsserts,
		SwitchVCDWaveform,
		SwitchVCDGZWaveform,
		SwitchFastWaveform,
		SwitchGHDLWaveform
	)
	
# 		if (value == "93"):
# 			value =  "93c"
# 			self.IEEEFlavor = "synopsys"
# 		elif (value == "08"):
# 			self.IEEEFlavor = "standard"

	def GetGHDLAnalyze(self):
		ghdl = GHDLAnalyze(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		ghdl.Parameters[ghdl.CmdAnalyze] = True
		return ghdl

	def GetGHDLElaborate(self):
		ghdl = GHDLElaborate(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		ghdl.Parameters[ghdl.CmdElaborate] = True
		return ghdl
	
	def GetGHDLRun(self):
		ghdl = GHDLRun(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		for param in ghdl.Parameters:
			if (param is not ghdl.Executable):
				ghdl.Parameters[param] = None
		ghdl.Parameters[ghdl.CmdRun] =			True
		return ghdl

class GHDLAnalyze(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, logger=logger)

		#self.Parameters[self.FlagExplicit] =					True
		#self.Parameters[self.FlagRelaxedRules] =			True
		#self.Parameters[self.FlagWarnBinding] =				True
		#self.Parameters[self.FlagNoVitalChecks] =			True
		#self.Parameters[self.FlagMultiByteComments] =	True
		#self.Parameters[self.FlagPSL] =								True
		#self.Parameters[self.FlagVerbose] =						True
	
	def Analyze(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				if ("ghdl1" not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl messages for : {0}".format("??????"))#str(filePath)))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing ghdl: {0}".format("??????"))#str(filePath)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
	
class GHDLElaborate(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, defaultParameters=["-e"], logger=logger)
	
	def Elaborate(self):
		if (self._backend == "mcode"):		return
		
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				if ("ghdl1" not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl elaboration messages for '{0}.{1}'".format("??????"))#self.VHDLLibrary, topLevel))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while elaborating '{0}.{1}'".format("??????"))#self.VHDLLibrary, topLevel))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)

class GHDLRun(GHDLExecutable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, defaultParameters=["-r"], logger=logger)
	
	def Run(self):
		parameterList = self.Parameters.ToArgumentList()
		parameterList += self.RunOptions.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		
		_indent = "    "
		try:
			ghdlLog = self.StartProcess(parameterList)
			
			log = ""
			for line in ghdlLog.split("\n")[:-1]:
				# if (testbenchName not in line):
					log += _indent + line + "\n"
			
			# if self.showLogs:
			if (log != ""):
				print(_indent + "ghdl run messages for '{0}.{1}'".format("??????", "??????"))#self.VHDLLibrary, testbenchName))
				print(_indent + "-" * 80)
				print(log[:-1])
				print(_indent + "-" * 80)
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while simulating '{0}.{1}'".format("??????", "??????"))#self.VHDLLibrary, testbenchName))
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
		except CalledProcessError as ex:
			print(_indent + Foreground.RED + "ERROR" + Foreground.RESET + " while executing GTKWave: {0}".format(str(dumpFile)))
			print(_indent + "Return Code: {0}".format(ex.returncode))
			print(_indent + "-" * 80)
			for line in ex.output.split("\n"):
				print(_indent + line)
			print(_indent + "-" * 80)
