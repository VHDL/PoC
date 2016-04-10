# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
#                   Martin Zabel
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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Simulator.CocotbSimulator")

# load dependencies
from configparser						import NoSectionError
from os											import chdir
import shutil

from colorama								import Fore as Foreground

# from Base.Exceptions				import PlatformNotSupportedException, NotConfiguredException
from Base.Project						import FileTypes, VHDLVersion, Environment, ToolChain, Tool
from Base.Simulator					import SimulatorException, Simulator as BaseSimulator, VHDLTestbenchLibraryName
from Parser.Parser					import ParserException
from PoC.Project						import Project as PoCProject, FileListFile
from ToolChains.GNU					import Make


class Simulator(BaseSimulator):
	__guiMode =					False

	def __init__(self, host, showLogs, showReport, guiMode):
		super().__init__(host, showLogs, showReport)

		self._guiMode =				guiMode

		self._entity =				None
		self._testbenchFQN =	None

		self._LogNormal("preparing simulation environment...")
		self._PrepareSimulationEnvironment()

	@property
	def TemporaryPath(self):
		return self._tempPath

	def _PrepareSimulationEnvironment(self):
		self._LogNormal("  preparing simulation environment...")
		
		# create temporary directory for Cocotb if not existent
		self._tempPath = self.Host.Directories["CocotbTemp"]
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for simulator files.")
			self._LogDebug("    Temporary directors: {0}".format(str(self._tempPath)))
			self._tempPath.mkdir(parents=True)

		# change working directory to temporary Cocotb path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0}\"".format(str(self._tempPath)))
		chdir(str(self._tempPath))

		# copy modelsim.ini from precompiled directory if exist
		simBuildPath = self._tempPath / "sim_build"
		try:
			simBuildPath.mkdir(parents=True)
		except FileExistsError:
			pass

		modelsimIniPath = self.Host.Directories["vSimPrecompiled"] / "modelsim.ini"
		if modelsimIniPath.exists():
			self._LogVerbose("  Copying modelsim.ini from precompiled to temporary directory.")
			self._LogDebug("    copy {0!s} {1!s}".format(modelsimIniPath, simBuildPath))
			shutil.copy(str(modelsimIniPath), str(simBuildPath))

	def PrepareSimulator(self):
		# create the Cocotb executable factory
		self._LogVerbose("  Preparing Cocotb simulator.")

	def RunAll(self, pocEntities, **kwargs):
		for pocEntity in pocEntities:
			self.Run(pocEntity, **kwargs)

	def Run(self, entity, board):
		self._entity =				entity
		self._testbenchFQN =	str(entity)										# TODO: implement FQN method on PoCEntity

		# check testbench database for the given testbench		
		self._LogQuiet("Testbench: {0}{1}{2}".format(Foreground.YELLOW, self._testbenchFQN, Foreground.RESET))
		if (not self.Host.PoCConfig.has_section(self._testbenchFQN)):
			raise SimulatorException("Testbench '{0}' not found.".format(self._testbenchFQN)) from NoSectionError(self._testbenchFQN)

		# setup all needed paths to execute fuse
		testbenchName =						self.Host.PoCConfig[self._testbenchFQN]['TestbenchModule']
		fileListFilePath =				self.Host.Directories["PoCRoot"] / self.Host.PoCConfig[self._testbenchFQN]['fileListFile']

		self._CreatePoCProject(testbenchName, board)
		self._AddFileListFile(fileListFilePath)

		self._Run()

	def _CreatePoCProject(self, testbenchName, board):
		# create a PoCProject and read all needed files
		self._LogDebug("    Create a PoC project '{0}'".format(str(testbenchName)))
		pocProject =									PoCProject(testbenchName)
		
		# configure the project
		pocProject.RootDirectory =		self.Host.Directories["PoCRoot"]
		pocProject.Environment =			Environment.Simulation
		pocProject.ToolChain =				ToolChain.Cocotb
		pocProject.Tool =							Tool.Cocotb_QuestaSim
		pocProject.VHDLVersion =			VHDLVersion.VHDL08
		pocProject.Board =						board

		self._pocProject =						pocProject

	def _AddFileListFile(self, fileListFilePath):
		self._LogDebug("    Reading filelist '{0}'".format(str(fileListFilePath)))
		# add the *.files file, parse and evaluate it
		try:
			fileListFile = self._pocProject.AddFile(FileListFile(fileListFilePath))
			fileListFile.Parse()
			fileListFile.CopyFilesToFileSet()
			fileListFile.CopyExternalLibraries()
			self._pocProject.ExtractVHDLLibrariesFromVHDLSourceFiles()
		except ParserException as ex:										raise SimulatorException("Error while parsing '{0}'.".format(str(fileListFilePath))) from ex
		
		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		if (len(fileListFile.Warnings) > 0):
			for warn in fileListFile.Warnings:
				self._LogWarning(warn)
			raise SimulatorException("Found critical warnings while parsing '{0}'".format(str(fileListFilePath)))

	def _Run(self):
		self._LogNormal("  running simulation...")
		cocotbTemplateFilePath = self.Host.Directories["PoCRoot"] / self.Host.PoCConfig[self._testbenchFQN]['CocotbMakefile']
		topLevel= self.Host.PoCConfig[self._testbenchFQN]['TopModule']
		cocotbModule = self.Host.PoCConfig[self._testbenchFQN]['CocotbModule']

		# create one VHDL line for each VHDL file
		vhdlSources = ""
		for file in self._pocProject.Files(fileType=FileTypes.VHDLSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Cannot add '{0!s}' to Cocotb Makefile.".format(file.Path)) from FileNotFoundError(str(file.Path))
			vhdlSources += str(file.Path) + " "

		# copy Cocotb (Python) files to temp directory
		self._LogVerbose("  Copying Cocotb (Python) files into temporary directory.")
		cocotbTempDir = str(self.Host.Directories["CocotbTemp"])
		for file in self._pocProject.Files(fileType=FileTypes.CocotbSourceFile):
			if (not file.Path.exists()):									raise SimulatorException("Cannot copy '{0!s}' to Cocotb temp directory.".format(file.Path)) from FileNotFoundError(str(file.Path))
			self._LogDebug("    copy {0!s} {1!s}".format(file.Path, cocotbTempDir))
			shutil.copy(str(file.Path), cocotbTempDir)

		# read/write Makefile template
		self._LogVerbose("  Generating Makefile...")
		self._LogDebug("    Reading Cocotb Makefile template file from '{0!s}'".format(cocotbTemplateFilePath))
		with cocotbTemplateFilePath.open('r') as fileHandle:
			cocotbMakefileContent = fileHandle.read()

		cocotbMakefileContent = cocotbMakefileContent.format(PoCRootDirectory=str(self.Host.Directories["PoCRoot"]), VHDLSources=vhdlSources,
																 TopLevel=topLevel, CocotbModule=cocotbModule)

		cocotbMakefilePath = self.Host.Directories["CocotbTemp"] / "Makefile"
		self._LogDebug("    Writing Cocotb Makefile to '{0!s}'".format(cocotbMakefilePath))
		with cocotbMakefilePath.open('w') as fileHandle:
			fileHandle.write(cocotbMakefileContent)

		# execute make
		make = Make(self.Host.Platform, logger=self.Host.Logger)
		if self._guiMode: make.Parameters[Make.SwitchGui] = 1
		make.Run()
