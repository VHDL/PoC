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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Compiler.XSTCompiler")

# load dependencies
# import re
# import shutil
# import textwrap
from pathlib							import Path
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
		
		# create temporary directory for XST if not existent
		tempXstPath = self.Host.directories["XSTTemp"]
		if not (tempXstPath).exists():
			self._LogVerbose("Creating temporary directory for XST files.")
			self._LogDebug("Temporary directors: {0}".format(str(tempXstPath)))
			tempXstPath.mkdir(parents=True)

		# create output directory for CoreGen if not existent
		xstOutputPath = self.Host.directories["PoCNetList"] / deviceString
		if not (xstOutputPath).exists():
			self._LogVerbose("Creating temporary directory for XST files.")
			self._LogDebug("Temporary directors: {0}".format(str(xstOutputPath)))
			xstOutputPath.mkdir(parents=True)
			
		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.Host.netListConfig['SPECIAL'] = {}
		self.Host.netListConfig['SPECIAL']['Device'] =				deviceString
		self.Host.netListConfig['SPECIAL']['DeviceSeries'] =	device.series()
		self.Host.netListConfig['SPECIAL']['OutputDir']	=			tempXstPath.as_posix()
		
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
		xstExecutablePath =		self.Host.directories["ISEBinary"] / self.__executables['XST']
		
#		# read netlist settings from configuration file
#		ipCoreName =					self.Host.netListConfig[str(pocEntity)]['IPCoreName']
#		xcoInputFilePath =		self.Host.directories["PoCRoot"] / self.Host.netListConfig[str(pocEntity)]['XstFile']
#		cgcTemplateFilePath =	self.Host.directories["PoCNetList"] / "template.cgc"
#		cgpFilePath =					xstGenPath / "coregen.cgp"
#		cgcFilePath =					xstGenPath / "coregen.cgc"
#		xcoFilePath =					xstGenPath / xcoInputFilePath.name

		if not self.Host.netListConfig.has_section(str(pocEntity)):
			from configparser import NoSectionError
			raise CompilerException("IP-Core '" + str(pocEntity) + "' not found.") from NoSectionError(str(pocEntity))
		
		# read netlist settings from configuration file
		if (self.Host.netListConfig[str(pocEntity)]['Type'] != "XilinxSynthesis"):
			raise CompilerException("This entity is not configured for XST compilation.")
		
		topModuleName =				self.Host.netListConfig[str(pocEntity)]['TopModule']
		fileListFilePath =		self.Host.directories["PoCRoot"] / self.Host.netListConfig[str(pocEntity)]['FileListFile']
		xcfFilePath =					self.Host.directories["PoCRoot"] / self.Host.netListConfig[str(pocEntity)]['XSTConstraintsFile']
		filterFilePath =			self.Host.directories["PoCRoot"] / self.Host.netListConfig[str(pocEntity)]['XSTFilterFile']
		#xstOptionsFilePath =	self.Host.directories["XSTFiles"] / self.Host.netListConfig[str(pocEntity)]['XSTOptionsFile']
		xstTemplateFilePath =	self.Host.directories["XSTFiles"] / self.Host.netListConfig[str(pocEntity)]['XSTOptionsFile']
		xstFilePath =					tempXstPath / (topModuleName + ".xst")
		prjFilePath =					tempXstPath / (topModuleName + ".prj")
		reportFilePath =			tempXstPath / (topModuleName + ".log")

		#if (not xstOptionsFilePath.exists()):
		# read/write XST options file
		self._LogDebug("Reading Xilinx Compiler Tool option file from '{0}'".format(str(xstTemplateFilePath)))
		with xstTemplateFilePath.open('r') as xstFileHandle:
			xstFileContent = xstFileHandle.read()
			
		xstTemplateDictionary = {
			'prjFile' :													str(prjFilePath),
			'UseNewParser' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.UseNewParser'],
			'InputFormat' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.InputFormat'],
			'OutputFormat' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.OutputFormat'],
			'OutputName' :											topModuleName,
			'Part' :														str(device),
			'TopModuleName' :										topModuleName,
			'OptimizationMode' :								self.Host.netListConfig[str(pocEntity)]['XSTOption.OptimizationMode'],
			'OptimizationLevel' :								self.Host.netListConfig[str(pocEntity)]['XSTOption.OptimizationLevel'],
			'PowerReduction' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.PowerReduction'],
			'IgnoreSynthesisConstraintsFile' :	self.Host.netListConfig[str(pocEntity)]['XSTOption.IgnoreSynthesisConstraintsFile'],
			'SynthesisConstraintsFile' :				str(xcfFilePath),
			'KeepHierarchy' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.KeepHierarchy'],
			'NetListHierarchy' :								self.Host.netListConfig[str(pocEntity)]['XSTOption.NetListHierarchy'],
			'GenerateRTLView' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.GenerateRTLView'],
			'GlobalOptimization' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.Globaloptimization'],
			'ReadCores' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.ReadCores'],
			'SearchDirectories' :								'"{0}"' % str(xstOutputPath),
			'WriteTimingConstraints' :					self.Host.netListConfig[str(pocEntity)]['XSTOption.WriteTimingConstraints'],
			'CrossClockAnalysis' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.CrossClockAnalysis'],
			'HierarchySeparator' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.HierarchySeparator'],
			'BusDelimiter' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.BusDelimiter'],
			'Case' :														self.Host.netListConfig[str(pocEntity)]['XSTOption.Case'],
			'SliceUtilizationRatio' :						self.Host.netListConfig[str(pocEntity)]['XSTOption.SliceUtilizationRatio'],
			'BRAMUtilizationRatio' :						self.Host.netListConfig[str(pocEntity)]['XSTOption.BRAMUtilizationRatio'],
			'DSPUtilizationRatio' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.DSPUtilizationRatio'],
			'LUTCombining' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.LUTCombining'],
			'ReduceControlSets' :								self.Host.netListConfig[str(pocEntity)]['XSTOption.ReduceControlSets'],
			'Verilog2001' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.Verilog2001'],
			'FSMExtract' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.FSMExtract'],
			'FSMEncoding' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.FSMEncoding'],
			'FSMSafeImplementation' :						self.Host.netListConfig[str(pocEntity)]['XSTOption.FSMSafeImplementation'],
			'FSMStyle' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.FSMStyle'],
			'RAMExtract' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.RAMExtract'],
			'RAMStyle' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.RAMStyle'],
			'ROMExtract' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.ROMExtract'],
			'ROMStyle' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.ROMStyle'],
			'MUXExtract' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.MUXExtract'],
			'MUXStyle' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.MUXStyle'],
			'DecoderExtract' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.DecoderExtract'],
			'PriorityExtract' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.PriorityExtract'],
			'ShRegExtract' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.ShRegExtract'],
			'ShiftExtract' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.ShiftExtract'],
			'XorCollapse' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.XorCollapse'],
			'AutoBRAMPacking' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.AutoBRAMPacking'],
			'ResourceSharing' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.ResourceSharing'],
			'ASyncToSync' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.ASyncToSync'],
			'UseDSP48' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.UseDSP48'],
			'IOBuf' :														self.Host.netListConfig[str(pocEntity)]['XSTOption.IOBuf'],
			'MaxFanOut' :												self.Host.netListConfig[str(pocEntity)]['XSTOption.MaxFanOut'],
			'BufG' :														self.Host.netListConfig[str(pocEntity)]['XSTOption.BufG'],
			'RegisterDuplication' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.RegisterDuplication'],
			'RegisterBalancing' :								self.Host.netListConfig[str(pocEntity)]['XSTOption.RegisterBalancing'],
			'SlicePacking' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.SlicePacking'],
			'OptimizePrimitives' :							self.Host.netListConfig[str(pocEntity)]['XSTOption.OptimizePrimitives'],
			'UseClockEnable' :									self.Host.netListConfig[str(pocEntity)]['XSTOption.UseClockEnable'],
			'UseSyncSet' :											self.Host.netListConfig[str(pocEntity)]['XSTOption.UseSyncSet'],
			'UseSyncReset' :										self.Host.netListConfig[str(pocEntity)]['XSTOption.UseSyncReset'],
			'PackIORegistersIntoIOBs' :					self.Host.netListConfig[str(pocEntity)]['XSTOption.PackIORegistersIntoIOBs'],
			'EquivalentRegisterRemoval' :				self.Host.netListConfig[str(pocEntity)]['XSTOption.EquivalentRegisterRemoval'],
			'SliceUtilizationRatioMaxMargin' :	self.Host.netListConfig[str(pocEntity)]['XSTOption.SliceUtilizationRatioMaxMargin']
		}
		
		xstFileContent = xstFileContent.format(**xstTemplateDictionary)
		
		if (self.Host.netListConfig.has_option(str(pocEntity), 'XSTOption.Generics')):
			xstFileContent += "-generics { {0} }".format(self.Host.netListConfig[str(pocEntity)]['XSTOption.Generics'])

		self._LogDebug("Writing Xilinx Compiler Tool option file to '{0}'".format(str(xstFilePath)))
		with xstFilePath.open('w') as xstFileHandle:
			xstFileHandle.write(xstFileContent)
	
#		else:		# xstFilePath exists
#			self._LogDebug("Copy XST options file from '{0}' to '{0}'".format((str(xstOptionsFilePath), str(xstFilePath)))
#			shutil.copy(str(xstOptionsFilePath), str(xstFilePath))
		
		# parse project filelist
		filesLineRegExpStr =	r"\s*(?P<Keyword>(vhdl(\-(87|93|02|08))?|verilog|xilinx))"		# Keywords: vhdl[-nn], verilog, xilinx
		filesLineRegExpStr += r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"									#	VHDL library name
		filesLineRegExpStr += r"\s+\"(?P<VHDLFile>.*?)\""														# VHDL filename without "-signs
		filesLineRegExp = re.compile(filesLineRegExpStr)

		self._LogDebug("Reading filelist '{0}'".format(str(fileListFilePath)))
		xstProjectFileContent = ""
		with fileListFilePath.open('r') as prjFileHandle:
			for line in prjFileHandle:
				filesLineRegExpMatch = filesLineRegExp.match(line)
				xstKeyWord = "vhdl"
				
				if (filesLineRegExpMatch is not None):
					if (filesLineRegExpMatch.group('Keyword') == "vhdl"):
						vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
						vhdlFilePath = self.Host.directories["PoCRoot"] / vhdlFileName
					elif (filesLineRegExpMatch.group('Keyword')[0:5] == "vhdl-"):
						if (filesLineRegExpMatch.group('Keyword')[-2:] == self.__vhdlStandard):
							vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
							vhdlFilePath = self.Host.directories["PoCRoot"] / vhdlFileName
					elif (filesLineRegExpMatch.group('Keyword') == "verilog"):
						vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
						vhdlFilePath = self.Host.directories["PoCRoot"] / vhdlFileName
						xstKeyWord = "verilog"
					elif (filesLineRegExpMatch.group('Keyword') == "xilinx"):
						vhdlFileName = filesLineRegExpMatch.group('VHDLFile')
						vhdlFilePath = self.Host.directories["XilinxPrimitiveSource"] / vhdlFileName
					
					vhdlLibraryName = filesLineRegExpMatch.group('VHDLLibrary')
					xstProjectFileContent += "{0} {0} \"{0}\"\n".format((xstKeyWord, vhdlLibraryName, str(vhdlFilePath)))
					
					if (not vhdlFilePath.exists()):
						raise CompilerException("Can not add '" + vhdlFileName + "' to project file.") from FileNotFoundError(str(vhdlFilePath))
		
		# write iSim project file
		self._LogDebug("Writing XST project file to '{0}'".format(str(prjFilePath)))
		with prjFilePath.open('w') as prjFileHandle:
			prjFileHandle.write(xstProjectFileContent)

		# change working directory to temporary XST path
		self._LogVerbose('    cd "{0}"' % str(tempXstPath))
		os.chdir(str(tempXstPath))
		
		# running XST
		# ==========================================================================
		self._LogNormal("  running XST...")
		# assemble XST command as list of parameters
		parameterList = [
			str(xstExecutablePath),
			'-intstyle', 'xflow',
			'-filter', str(filterFilePath),
			'-ifn', str(xstFilePath),
			'-ofn', str(reportFilePath)
		]
		self._LogDebug("call xst: {0}".format(str(parameterList)))
		self._LogVerbose("    {0} -intstyle xflow -filter \"{0}\" -ifn \"{0}\" -ofn \"{0}\"".format(str(xstExecutablePath), str(fileListFilePath), str(xstFilePath), str(reportFilePath)))
		if (self.dryRun == False):
			try:
				xstLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
				if self.showLogs:
					print("XST log file:")
					print("--------------------------------------------------------------------------------")
					print(xstLog)
					print()
			
			except subprocess.CalledProcessError as ex:
				print("ERROR while executing XST")
				print("Return Code: {0}".format(ex.returncode))
				print("--------------------------------------------------------------------------------")
				print(ex.output)
				return
			
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
	
	@property
	def TemporaryPath(self):
		return self._tempPath
	
	@property
	def outputPath(self):
		return self._outputPath

	def _PrepareCompilerEnvironment(self):
		self._LogNormal("  preparing compiler environment...")
		
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
		self._activeHDL =		ActiveHDLSimulatorExecutable(self.Host.Platform, binaryPath, version, logger=self.Logger)
	
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
		
