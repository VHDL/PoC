# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
# 
# Python Class:			This PoCXCOCompiler compiles xco IPCores to netlists
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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Class Compiler(PoCCompiler)")

# load dependencies
import re								# used for output filtering
import shutil
from colorama								import Fore as Foreground
from configparser						import NoSectionError
from os											import chdir
from pathlib								import Path
from textwrap								import dedent

from Base.Exceptions				import NotConfiguredException, PlatformNotSupportedException
from Base.Project						import FileTypes, VHDLVersion, Environment, ToolChain, Tool
from Base.Compiler					import Compiler as BaseCompiler, CompilerException
from PoC.Project						import Project as PoCProject, FileListFile
from ToolChains.Xilinx.ISE	import ISE


class Compiler(BaseCompiler):
	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self._entity =				None
		self._netlistFQN =		""
		self._board =					None
		self._tempPath =			None
		self._outputPath =		None
		self._ise =						None

		self._PrepareCompilerEnvironment()

	def _PrepareCompilerEnvironment(self):
		self._LogNormal("preparing synthesis environment...")
		self._tempPath =		self.Host.Directories["CoreGenTemp"]
		self._outputPath =	self.Host.Directories["PoCNetList"] / str(self._board.Device)
		super()._PrepareCompilerEnvironment()

		
	def Run(self, entity, board, **_):
		self._entity =				entity
		self._netlistFQN =		str(entity)  # TODO: implement FQN method on PoCEntity
		self._board =					board
		
		# check testbench database for the given testbench		
		self._LogQuiet("IP-core: {0}{1}{2}".format(Foreground.YELLOW, self._netlistFQN, Foreground.RESET))

		# setup all needed paths to execute fuse
		netlist = entity.Netlist
		self._CreatePoCProject(netlist, board)
		self._AddFileListFile(netlist.FilesFile)

		self._RunPrepareCompile(netlist)
		self._RunPreCopy(netlist)
		self._RunCompile(netlist)
		self._RunPostCopy(netlist)
		self._RunPostReplace(netlist)

	def _RunPrepareCompile(self, netlist):
		self._LogNormal("  preparing compiler environment for IP-core '????' ...")

		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.Host.netListConfig['SPECIAL'] =							{}
		self.Host.netListConfig['SPECIAL']['Device'] =		str(self._board)
		self.Host.netListConfig['SPECIAL']['OutputDir'] =	self._tempPath.as_posix()

	def _RunPreCopy(self, netlist):
		# read pre-copy tasks
		preCopyTasks = []
		preCopyFileList = self.Host.netListConfig[self._netlistFQN]['PreCopy.Rule']
		if (len(preCopyFileList) != 0):
			self._LogDebug("PreCopyTasks: \n  " + ("\n  ".join(preCopyFileList.split("\n"))))

			preCopyRegExpStr	= r"^\s*(?P<SourceFilename>.*?)"			# Source filename
			preCopyRegExpStr += r"\s->\s"													#	Delimiter signs
			preCopyRegExpStr += r"(?P<DestFilename>.*?)$"					#	Destination filename
			preCopyRegExp = re.compile(preCopyRegExpStr)

			for item in preCopyFileList.split("\n"):
				preCopyRegExpMatch = preCopyRegExp.match(item)
				if (preCopyRegExpMatch is not None):
					preCopyTasks.append((
						Path(preCopyRegExpMatch.group('SourceFilename')),
						Path(preCopyRegExpMatch.group('DestFilename'))
					))
				else:
					raise CompilerException("Error in pre-copy rule '{0}'".format(item))

		# run pre-copy tasks
		self._LogNormal('  copy further input files into output directory...')
		for task in preCopyTasks:
			(fromPath, toPath) = task
			if not fromPath.exists(): raise CompilerException("Can not pre-copy '{0}' to destination.".format(str(fromPath))) from FileNotFoundError(str(fromPath))

			toDirectoryPath = toPath.parent
			if not toDirectoryPath.exists():
				toDirectoryPath.mkdir(parents=True)

			self._LogVerbose("  pre-copying '{0}'.".format(fromPath))
			shutil.copy(str(fromPath), str(toPath))

	def _RunCompile(self, netlist):
		# read netlist settings from configuration file
		ipCoreName = self.Host.netListConfig[self._netlistFQN]['IPCoreName']
		xcoInputFilePath = self.Host.Directories["PoCRoot"] / self.Host.netListConfig[self._netlistFQN]['CoreGeneratorFile']
		cgcTemplateFilePath = self.Host.Directories["PoCNetList"] / "template.cgc"
		cgpFilePath = self._tempPath / "coregen.cgp"
		cgcFilePath = self._tempPath / "coregen.cgc"
		xcoFilePath = self._tempPath / xcoInputFilePath.name

		if (self.Host.Platform == "Windows"):
			WorkingDirectory = ".\\temp\\"
		else:
			WorkingDirectory = "./temp/"

		# write CoreGenerator project file
		cgProjectFileContent = dedent('''\
			SET addpads = false
			SET asysymbol = false
			SET busformat = BusFormatAngleBracketNotRipped
			SET createndf = false
			SET designentry = VHDL
			SET device = {Device}
			SET devicefamily = {DeviceFamily}
			SET flowvendor = Other
			SET formalverification = false
			SET foundationsym = false
			SET implementationfiletype = Ngc
			SET package = {Package}
			SET removerpms = false
			SET simulationfiles = Behavioral
			SET speedgrade = {SpeedGrade}
			SET verilogsim = false
			SET vhdlsim = true
			SET workingdirectory = {WorkingDirectory}
			'''.format(
			Device=self._board.shortName(),
			DeviceFamily=self._board.familyName(),
			Package=(str(self._board.package) + str(self._board.pinCount)),
			SpeedGrade=self._board.speedGrade,
			WorkingDirectory=WorkingDirectory
		))

		self._LogDebug("Writing CoreGen project file to '{0}'.".format(cgpFilePath))
		with cgpFilePath.open('w') as cgpFileHandle:
			cgpFileHandle.write(cgProjectFileContent)

		# write CoreGenerator content? file
		self._LogDebug("Reading CoreGen content file to '{0}'.".format(cgcTemplateFilePath))
		with cgcTemplateFilePath.open('r') as cgcFileHandle:
			cgContentFileContent = cgcFileHandle.read()

		cgContentFileContent = cgContentFileContent.format(
			name="lcd_ChipScopeVIO",
			device=self._board.shortName(),
			devicefamily=self._board.familyName(),
			package=(str(self._board.package) + str(self._board.pinCount)),
			speedgrade=self._board.speedGrade
		)

		self._LogDebug("Writing CoreGen content file to '{0}'.".format(cgcFilePath))
		with cgcFilePath.open('w') as cgcFileHandle:
			cgcFileHandle.write(cgContentFileContent)

		# copy xco file into temporary directory
		self._LogDebug("Copy CoreGen xco file to '{0}'.".format(xcoFilePath))
		self._LogVerbose("    cp {0} {1}".format(str(xcoInputFilePath), str(self._tempPath)))
		shutil.copy(str(xcoInputFilePath), str(xcoFilePath), follow_symlinks=True)

		# change working directory to temporary CoreGen path
		self._LogVerbose('    cd {0}'.format(str(self._tempPath)))
		chdir(str(self._tempPath))

		# running CoreGen
		# ==========================================================================
		self._LogNormal("  running CoreGen...")
		binaryPath =	self.Host.Directories["ISEBinary"]
		iseVersion =			self.Host.pocConfig['Xilinx.ISE']['Version']
		coreGen = ISE.GetCoreGenerator(self.Host.Platform, binaryPath, iseVersion, logger=self.Logger)
		coreGen.Parameters[coreGen.SwitchProjectFile] =	"."		# use current directory and the default project name
		coreGen.Parameters[coreGen.SwitchBatchFile] =		str(xcoFilePath)
		coreGen.Parameters[coreGen.FlagRegenerate] =		True
		coreGen.Generate()

	def _RunPostCopy(self, netlist):
		# read (post) copy tasks
		copyTasks = []
		copyFileList = self.Host.netListConfig[self._netlistFQN]['PostCopy.Rule']
		if (len(copyFileList) != 0):
			self._LogDebug("CopyTasks: \n  " + ("\n  ".join(copyFileList.split("\n"))))

			copyRegExpStr = r"^\s*(?P<SourceFilename>.*?)"  # Source filename
			copyRegExpStr += r"\s->\s"  # Delimiter signs
			copyRegExpStr += r"(?P<DestFilename>.*?)$"  # Destination filename
			copyRegExp = re.compile(copyRegExpStr)

			for item in copyFileList.split("\n"):
				copyRegExpMatch = copyRegExp.match(item)
				if (copyRegExpMatch is not None):
					copyTasks.append((
						Path(copyRegExpMatch.group('SourceFilename')),
						Path(copyRegExpMatch.group('DestFilename'))
					))
				else:
					raise CompilerException("Error in copy rule '{0}'".format(item))

		# copy resulting files into PoC's netlist directory
		self._LogNormal('  copy result files into output directory...')
		for task in copyTasks:
			(fromPath, toPath) = task
			if not fromPath.exists(): raise CompilerException(
				"Can not copy '{0}' to destination.".format(str(fromPath))) from FileNotFoundError(str(fromPath))

			toDirectoryPath = toPath.parent
			if not toDirectoryPath.exists():
				toDirectoryPath.mkdir(parents=True)

			self._LogVerbose("  copying '{0}'.".format(fromPath))
			shutil.copy(str(fromPath), str(toPath))

	def _RunPostReplace(self, netlist):
		# read replacement tasks
		replaceTasks = []
		replaceFileList = self.Host.netListConfig[self._netlistFQN]['PostReplace.Rule']
		if (len(replaceFileList) != 0):
			self._LogDebug("ReplacementTasks: \n  " + ("\n  ".join(replaceFileList.split("\n"))))

			replaceRegExpStr = r"^\s*(?P<Filename>.*?)\s+:"  # Filename
			replaceRegExpStr += r"(?P<Options>[dim]{0,3}):\s+"  # RegExp options
			replaceRegExpStr += r"\"(?P<Search>.*?)\"\s+->\s+"  # Search regexp
			replaceRegExpStr += r"\"(?P<Replace>.*?)\"$"  # Replace regexp
			replaceRegExp = re.compile(replaceRegExpStr)

			for item in replaceFileList.split("\n"):
				replaceRegExpMatch = replaceRegExp.match(item)

				if (replaceRegExpMatch is not None):
					replaceTasks.append((
						Path(replaceRegExpMatch.group('Filename')),
						replaceRegExpMatch.group('Options'),
						replaceRegExpMatch.group('Search'),
						replaceRegExpMatch.group('Replace')
					))
				else:
					raise CompilerException("Error in replace rule '{0}'.".format(item))

		# replace in resulting files
		self._LogNormal('  replace in result files...')
		for task in replaceTasks:
			(fromPath, options, search, replace) = task
			if not fromPath.exists(): raise CompilerException("Can not replace in file '{0}' to destination.".format(str(fromPath))) from FileNotFoundError(str(fromPath))
			
			self._LogVerbose("  replace in file '{0}': search for '{1}' -> replace by '{2}'.".format(str(fromPath), search, replace))
			
			regExpFlags = 0
			if ('i' in options):		regExpFlags |= re.IGNORECASE
			if ('m' in options):		regExpFlags |= re.MULTILINE
			if ('d' in options):		regExpFlags |= re.DOTALL
			
			regExp = re.compile(search, regExpFlags)
			
			with fromPath.open('r') as fileHandle:
				FileContent = fileHandle.read()
			
			NewContent = re.sub(regExp, replace, FileContent)
			
			with fromPath.open('w') as fileHandle:
				fileHandle.write(NewContent)
		
