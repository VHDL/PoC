# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 	Patrick Lehmann
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
# Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
from pathlib							import Path
# import re
# import shutil
# import textwrap
from os										import environ
from configparser					import NoOptionError, ConfigParser, ExtendedInterpolation

from Base.Exceptions import *
from Compiler.Base import PoCCompiler 
from Compiler.Exceptions import *


class Compiler(PoCCompiler):
	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

	def RunAll(self, pocEntities, **kwargs):
		for pocEntity in pocEntities:
			self.Run(pocEntity, **kwargs)
		
	def Run(self, pocEntity, device):
		self._LogNormal(str(pocEntity))
		self._LogNormal("  preparing compiler environment...")

		# TODO: improve / resolve board to device
		deviceString = str(device).upper()
		deviceSection = "Device." + deviceString
		
		# create temporary directory for CoreGen if not existent
		tempCoreGenPath = self.Host.directories["CoreGenTemp"]
		if not (tempCoreGenPath).exists():
			self._LogVerbose("    Creating temporary directory for core generator files.")
			self._LogDebug("    Temporary directory: {0}.".format(tempCoreGenPath))
			tempCoreGenPath.mkdir(parents=True)

		# create output directory for CoreGen if not existent
		coreGenOutputPath = self.Host.directories["PoCNetList"] / deviceString
		if not (coreGenOutputPath).exists():
			self._LogVerbose("    Creating output directory for core generator files.")
			self._LogDebug("    Output directory: {0}.".format(coreGenOutputPath))
			coreGenOutputPath.mkdir(parents=True)
			
		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.Host.netListConfig['SPECIAL'] = {}
		self.Host.netListConfig['SPECIAL']['Device'] =		deviceString
		self.Host.netListConfig['SPECIAL']['OutputDir'] =	tempCoreGenPath.as_posix()
		
		if not self.Host.netListConfig.has_section(str(pocEntity)):
			raise CompilerException("IP-Core '{0}' not found.".format(str(pocEntity))) from NoSectionError(str(pocEntity))
		
		# read pre-copy tasks
		preCopyTasks = []
		preCopyFileList = self.Host.netListConfig[str(pocEntity)]['PreCopy']
		if (len(preCopyFileList) != 0):
			self._LogDebug("PreCopyTasks: \n  " + ("\n  ".join(preCopyFileList.split("\n"))))
			
			preCopyRegExpStr	 = r"^\s*(?P<SourceFilename>.*?)"			# Source filename
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
		
		# read (post) copy tasks
		copyTasks = []
		copyFileList = self.Host.netListConfig[str(pocEntity)]['Copy']
		if (len(copyFileList) != 0):
			self._LogDebug("CopyTasks: \n  " + ("\n  ".join(copyFileList.split("\n"))))
			
			copyRegExpStr	 = r"^\s*(?P<SourceFilename>.*?)"			# Source filename
			copyRegExpStr += r"\s->\s"													#	Delimiter signs
			copyRegExpStr += r"(?P<DestFilename>.*?)$"					#	Destination filename
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
		
		# read replacement tasks
		replaceTasks = []
		replaceFileList = self.Host.netListConfig[str(pocEntity)]['Replace']
		if (len(replaceFileList) != 0):
			self._LogDebug("ReplacementTasks: \n  " + ("\n  ".join(replaceFileList.split("\n"))))

			replaceRegExpStr =	r"^\s*(?P<Filename>.*?)\s+:"			# Filename
			replaceRegExpStr += r"(?P<Options>[dim]{0,3}):\s+"			#	RegExp options
			replaceRegExpStr += r"\"(?P<Search>.*?)\"\s+->\s+"		#	Search regexp
			replaceRegExpStr += r"\"(?P<Replace>.*?)\"$"					# Replace regexp
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
		
		# setup all needed paths to execute coreGen
		coreGenExecutablePath =		self.Host.directories["ISEBinary"] / self.__executables['CoreGen']
		
		# read netlist settings from configuration file
		ipCoreName =					self.Host.netListConfig[str(pocEntity)]['IPCoreName']
		xcoInputFilePath =		self.Host.directories["PoCRoot"] / self.Host.netListConfig[str(pocEntity)]['CoreGeneratorFile']
		cgcTemplateFilePath =	self.Host.directories["PoCNetList"] / "template.cgc"
		cgpFilePath =					tempCoreGenPath / "coregen.cgp"
		cgcFilePath =					tempCoreGenPath / "coregen.cgc"
		xcoFilePath =					tempCoreGenPath / xcoInputFilePath.name

		# report the next steps in execution
#		if (self.getVerbose()):
#			print("  Commands to be run:")
#			print("  1. Write CoreGen project file into temporary directory.")
#			print("  2. Write CoreGen content file into temporary directory.")
#			print("  3. Copy IPCore's *.xco file into temporary directory.")
#			print("  4. Change working directory to temporary directory.")
#			print("  5. Run Xilinx Core Generator (coregen).")
#			print("  6. Copy resulting files into output directory.")
#			print("  ----------------------------------------")
		
		if (self.Host.platform == "Windows"):
			WorkingDirectory = ".\\temp\\"
		else:
			WorkingDirectory = "./temp/"
		
		# write CoreGenerator project file
		cgProjectFileContent = textwrap.dedent('''\
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
				Device=device.shortName(),
				DeviceFamily=device.familyName(),
				Package=(str(device.package) + str(device.pinCount)),
				SpeedGrade=device.speedGrade,
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
			device=device.shortName(),
			devicefamily=device.familyName(),
			package=(str(device.package) + str(device.pinCount)),
			speedgrade=device.speedGrade
		)

		self._LogDebug("Writing CoreGen content file to '{0}'.".format(cgcFilePath))
		with cgcFilePath.open('w') as cgcFileHandle:
			cgcFileHandle.write(cgContentFileContent)
		
		# copy xco file into temporary directory
		self._LogDebug("Copy CoreGen xco file to '{0}'.".format(xcoFilePath))
		self._LogVerbose("    cp {0} {1}".format(str(xcoInputFilePath), str(tempCoreGenPath)))
		shutil.copy(str(xcoInputFilePath), str(xcoFilePath), follow_symlinks=True)
		
		# change working directory to temporary CoreGen path
		self._LogVerbose('    cd {0}'.format(str(tempCoreGenPath)))
		os.chdir(str(tempCoreGenPath))
		
		# running CoreGen
		# ==========================================================================
		self._LogNormal("  running CoreGen...")
		# assemble CoreGen command as list of parameters
		parameterList = [
			str(coreGenExecutablePath),
			'-r',
			'-b', str(xcoFilePath),
			'-p', '.'
		]
		self._LogDebug("call coreGen: {0}.".format(parameterList))
		self._LogVerbose('    {0} -r -b "{1}" -p .'.format(str(coreGenExecutablePath), str(xcoFilePath)))
		if (self.dryRun == False):
			coreGenLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
			if self.showLogs:
				print("Core Generator log (CoreGen)")
				print("--------------------------------------------------------------------------------")
				print(coreGenLog)
				print()
		
		# copy resulting files into PoC's netlist directory
		self._LogNormal('  copy result files into output directory...')
		for task in copyTasks:
			(fromPath, toPath) = task
			if not fromPath.exists(): raise CompilerException("Can not copy '{0}' to destination.".format(str(fromPath))) from FileNotFoundError(str(fromPath))
			
			toDirectoryPath = toPath.parent
			if not toDirectoryPath.exists():
				toDirectoryPath.mkdir(parents=True)
		
			self._LogVerbose("  copying '{0}'.".format(fromPath))
			shutil.copy(str(fromPath), str(toPath))
		
		# replace in resulting files
		self._LogNormal('  replace in result files...')
		for task in replaceTasks:
			(fromPath, options, search, replace) = task
			if not fromPath.exists(): raise CompilerException("Can not replace in file '{0}' to destination.".format(str(fromPath))) from FileNotFoundError(str(fromPath))
			
			self._LogVerbose("  replace in file '{0}': search for '{1}' -> replace by '{2}'.".format(str(fromPath), search, replace))
			
			regExpFlags	 = 0
			if ('i' in options):
				regExpFlags |= re.IGNORECASE
			if ('m' in options):
				regExpFlags |= re.MULTILINE
			if ('d' in options):
				regExpFlags |= re.DOTALL
			
			regExp = re.compile(search, regExpFlags)
			
			with fromPath.open('r') as fileHandle:
				FileContent = fileHandle.read()
			
			NewContent = re.sub(regExp, replace, FileContent)
			
			with fromPath.open('w') as fileHandle:
				fileHandle.write(NewContent)
		
