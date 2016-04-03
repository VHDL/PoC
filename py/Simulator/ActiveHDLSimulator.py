# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
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
from configparser								import NoSectionError
from os													import chdir
from queue											import Queue

from Base.Executable						import *
from Base.Simulator							import Simulator as BaseSimulator, VHDLTestbenchLibraryName
from PoC.PoCProject							import *
from ToolChains.Aldec.ActiveHDL	import ActiveHDL, ActiveHDLException


class Simulator(BaseSimulator):
	__guiMode =				False

	def __init__(self, host, showLogs, showReport, guiMode):
		super().__init__(host, showLogs, showReport)

		self._guiMode =				guiMode
		self._activeHDL =			None

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
		self._activeHDL =		ActiveHDL(self.Host.Platform, binaryPath, version, logger=self.Logger)

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
			
		# setup all needed variables and paths
		testbenchName =				self.Host.tbConfig[self._testbenchFQN]['TestbenchModule']
		fileListFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['fileListFile']

		self._CreatePoCProject(testbenchName, boardName, deviceName)
		self._AddFileListFile(fileListFilePath)
		
		self._RunCompile()
		# self._RunOptimize()
		
		if (not self._guiMode):
			self._RunSimulation(testbenchName)
		else:
			raise SimulatorException("GUI mode is not supported for Active-HDL.")
			# self._RunSimulationWithGUI(testbenchName)
		
	def _CreatePoCProject(self, testbenchName, boardName=None, deviceName=None):
		# create a PoCProject and read all needed files
		self._LogDebug("    Create a PoC project '{0}'".format(str(testbenchName)))
		pocProject =									PoCProject(testbenchName)
		
		# configure the project
		pocProject.RootDirectory =		self.Host.Directories["PoCRoot"]
		pocProject.Environment =			Environment.Simulation
		pocProject.ToolChain =				ToolChain.Aldec_ActiveHDL
		pocProject.Tool =							Tool.Aldec_aSim
		pocProject.VHDLVersion =			self._vhdlVersion
		
		if (deviceName is None):			pocProject.Board =					boardName
		else:													pocProject.Device =					deviceName
		
		self._pocProject = pocProject
		
	def _AddFileListFile(self, fileListFilePath):
		self._LogDebug("    Reading filelist '{0}'".format(str(fileListFilePath)))
		# add the *.files file, parse and evaluate it
		fileListFile = self._pocProject.AddFile(FileListFile(fileListFilePath))
		fileListFile.Parse()
		fileListFile.CopyFilesToFileSet()
		fileListFile.CopyExternalLibraries()
		self._pocProject.ExtractVHDLLibrariesFromVHDLSourceFiles()
		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		
	def _RunCompile(self):
		self._LogNormal("  running VHDL compiler for every vhdl file...")
		
		# create a ActiveHDLVHDLCompiler instance
		alib = self._activeHDL.GetVHDLLibraryTool()

		for lib in self._pocProject.VHDLLibraries:
			alib.Parameters[alib.SwitchLibraryName] = lib.Name
			try:
				alib.CreateLibrary()
			except ActiveHDLException as ex:
				raise SimulatorException("Error creating VHDL library '{0}'.".format(lib.Name)) from ex
			if alib.HasErrors:
				raise SimulatorException("Error creating VHDL library '{0}'.".format(lib.Name))

		# create a ActiveHDLVHDLCompiler instance
		acom = self._activeHDL.GetVHDLCompiler()
		if (self._vhdlVersion == VHDLVersion.VHDL87):			acom.Parameters[acom.SwitchVHDLVersion] =	"87"
		elif (self._vhdlVersion == VHDLVersion.VHDL93):		acom.Parameters[acom.SwitchVHDLVersion] =	"93"
		elif (self._vhdlVersion == VHDLVersion.VHDL02):		acom.Parameters[acom.SwitchVHDLVersion] =	"2002"
		elif (self._vhdlVersion == VHDLVersion.VHDL08):		acom.Parameters[acom.SwitchVHDLVersion] =	"2008"

		# run acom compile for each VHDL file
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Can not analyse '{0}'.".format(str(file.Path))) from FileNotFoundError(str(file.Path))
			acom.Parameters[acom.SwitchVHDLLibrary] =	file.VHDLLibraryName
			acom.Parameters[acom.ArgSourceFile] =			file.Path
			# set a per file log-file with '-l', 'vcom.log',
			try:
				acom.Compile()
			except ActiveHDLException as ex:
				raise SimulatorException("Error while compiling '{0}'.".format(str(file.Path))) from ex
			if acom.HasErrors:
				raise SimulatorException("Error while compiling '{0}'.".format(str(file.Path)))


	def _RunSimulation(self, testbenchName):
		self._LogNormal("  running simulation...")
		
		tclBatchFilePath =		self.Host.Directories["PoCRoot"] / self.Host.tbConfig[self._testbenchFQN]['aSimBatchScript']
		
		# create a ActiveHDLSimulator instance
		aSim = self._activeHDL.GetSimulator()
		aSim.Parameters[aSim.SwitchBatchCommand] = "asim -lib {0} {1}; run -all; bye".format(VHDLTestbenchLibraryName, testbenchName)

		# aSim.Optimization =			True
		# aSim.TimeResolution =		"1fs"
		# aSim.ComanndLineMode =	True
		# aSim.BatchCommand =			"do {0}".format(str(tclBatchFilePath))
		# aSim.TopLevel =					"{0}.{1}".format(VHDLTestbenchLibraryName, testbenchName)
		try:
			aSim.Simulate()
		except ActiveHDLException as ex:
			raise SimulatorException("Error while simulating '{0}.{1}'.".format(VHDLTestbenchLibraryName, testbenchName)) from ex
		if aSim.HasErrors:
			raise SimulatorException("Error while simulating '{0}'.".format(VHDLTestbenchLibraryName, testbenchName))

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


