# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
# 
# Python Class:			Base class for all PoC***Compilers
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

# entry point
from lib.Parser import ParserException

if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Class PoCCompiler")


from os import chdir

# load dependencies
from Base.Exceptions		import ExceptionBase
from Base.Logging				import ILogable
from Base.Project				import ToolChain, Tool, VHDLVersion, Environment
from PoC.Project				import Project as PoCProject, FileListFile


class CompilerException(ExceptionBase):
	pass

class Compiler(ILogable):
	_TOOL_CHAIN =	ToolChain.Any
	_TOOL =				Tool.Any

	def __init__(self, host, showLogs, showReport):
		if isinstance(host, ILogable):
			ILogable.__init__(self, host.Logger)
		else:
			ILogable.__init__(self, None)

		self.__host =				host
		self.__showLogs =		showLogs
		self.__showReport =	showReport
		self.__dryRun =			False

		self._vhdlVersion =	VHDLVersion.VHDL2008
		self._pocProject =	None

		self._tempPath =		None
		self._outputPath =	None

	# class properties
	# ============================================================================
	@property
	def Host(self):						return self.__host
	@property
	def ShowLogs(self):				return self.__showLogs
	@property
	def ShowReport(self):			return self.__showReport
	@property
	def TemporaryPath(self):	return self._tempPath
	@property
	def OutputPath(self):			return self._outputPath

	def _PrepareCompilerEnvironment(self):
		# create temporary directory for GHDL if not existent
		if (not (self._tempPath).exists()):
			self._LogVerbose("  Creating temporary directory for synthesizer files.")
			self._LogDebug("    Temporary directory: {0!s}".format(self._tempPath))
			self._tempPath.mkdir(parents=True)

		# change working directory to temporary iSim path
		self._LogVerbose("  Changing working directory to temporary directory.")
		self._LogDebug("    cd \"{0!s}\"".format(self._tempPath))
		chdir(str(self._tempPath))

		# create output directory for CoreGen if not existent
		if not (self._outputPath).exists() :
			self._LogVerbose("  Creating output directory for generated files.")
			self._LogDebug("    Output directory: {0!s}.".format(self._outputPath))
			self._outputPath.mkdir(parents=True)

	def _CreatePoCProject(self, testbench, board):
		# create a PoCProject and read all needed files
		self._LogDebug("    Create a PoC project '{0}'".format(testbench.ModuleName))
		pocProject = PoCProject(testbench.ModuleName)

		# configure the project
		pocProject.RootDirectory =	self.Host.Directories["PoCRoot"]
		pocProject.Environment =		Environment.Synthesis
		pocProject.ToolChain =			self._TOOL_CHAIN
		pocProject.Tool =						self._TOOL
		pocProject.VHDLVersion =		self._vhdlVersion
		pocProject.Board =					board

		self._pocProject =					pocProject

	def _AddFileListFile(self, fileListFilePath):
		self._LogDebug("    Reading filelist '{0!s}'".format(fileListFilePath))
		# add the *.files file, parse and evaluate it
		# if (not fileListFilePath.exists()):		raise SimulatorException("Files file '{0!s}' not found.".format(fileListFilePath)) from FileNotFoundError(str(fileListFilePath))

		try:
			fileListFile = self._pocProject.AddFile(FileListFile(fileListFilePath))
			fileListFile.Parse()
			fileListFile.CopyFilesToFileSet()
			fileListFile.CopyExternalLibraries()
			self._pocProject.ExtractVHDLLibrariesFromVHDLSourceFiles()
		except ParserException as ex:
			raise CompilerException("Error while parsing '{0!s}'.".format(fileListFilePath)) from ex

		self._LogDebug(self._pocProject.pprint(2))
		self._LogDebug("=" * 160)
		if (len(fileListFile.Warnings) > 0):
			for warn in fileListFile.Warnings:
				self._LogWarning(warn)
			raise CompilerException("Found critical warnings while parsing '{0!s}'".format(fileListFilePath))

	def RunAll(self, fqnList, **kwargs):
		for fqn in fqnList:
			entity = fqn.Entity
			# for entity in fqn.GetEntities():
			# try:
			self.Run(entity, **kwargs)
			# except SimulatorException:
			# 	pass

	def Run(self, entity, **kwargs):
		raise NotImplementedError("This method is abstract.")
