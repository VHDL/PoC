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
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Compiler.XSTCompiler")

# load dependencies
import re								# used for output filtering
import shutil
from configparser							import NoSectionError
from pathlib									import Path

from Base.Exceptions					import NotConfiguredException, PlatformNotSupportedException
from Base.Project							import VHDLVersion, Environment, ToolChain, Tool
from Base.Compiler						import Compiler as BaseCompiler, CompilerException
from ToolChains.Xilinx.Xilinx	import XilinxProjectExportMixIn
from ToolChains.Xilinx.ISE		import ISE


class Compiler(BaseCompiler, XilinxProjectExportMixIn):
	_TOOL_CHAIN =	ToolChain.Xilinx_ISE
	_TOOL =				Tool.Xilinx_XST

	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)
		XilinxProjectExportMixIn.__init__(self)

		self._ise =		None

	def oldRun(self, pocEntity, device):
		self._entity =	pocEntity
		self._ipcoreFQN =	str(pocEntity)
		
		self._LogNormal(self._ipcoreFQN)
		self._LogNormal("  preparing compiler environment...")


		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.Host.PoCConfig['SPECIAL'] = {}
		self.Host.PoCConfig['SPECIAL']['Device'] =				deviceString
		self.Host.PoCConfig['SPECIAL']['DeviceSeries'] =	device.series()
		self.Host.PoCConfig['SPECIAL']['OutputDir']	=			self._tempPath.as_posix()

		# TODO: move to XstNetlist class
		# read netlist settings from configuration file
		if (self.Host.PoCConfig[self._ipcoreFQN]['Type'] != "XilinxSynthesis"):
			raise CompilerException("This entity is not configured for XST compilation.")



	
		# TODO: parse project filelist
		# TODO: write iSim project file



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
		# TODO: copy resulting files into PoC's netlist directory
		# TODO: replace in resulting files


	def _PrepareCompilerEnvironment(self):
		self._LogNormal("preparing synthesis environment...")
		self._tempPath =		self.Host.Directories["XstTemp"]
		self._outputPath =	self.Host.Directories["PoCNetList"] / str(self._device)
		super()._PrepareCompilerEnvironment()

	def PrepareCompiler(self, binaryPath, version):
		# create the GHDL executable factory
		self._LogVerbose("  Preparing Xilinx Synthesis Tool (XST).")
		self._ise =		ISE(self.Host.Platform, binaryPath, version, logger=self.Logger)

	def Run(self, entity, board, **_):
		self._entity =			entity
		# self._ipcoreFQN =		str(entity)  # TODO: implement FQN method on PoCEntity
		self._device =			board.Device

		# setup all needed paths to execute fuse
		netlist = entity.XstNetlist
		self._CreatePoCProject(netlist, board)
		self._AddFileListFile(netlist.FilesFile)
		self._AddRulesFiles(netlist.RulesFile)

		# check testbench database for the given testbench
		self._LogQuiet("IP-core: {0!s}".format(netlist.Parent))

		xcfFilePath =					self.Host.Directories["PoCRoot"] / self.Host.PoCConfig[netlist.ConfigSectionName]['XSTConstraintsFile']
		filterFilePath =			self.Host.Directories["PoCRoot"] / self.Host.PoCConfig[netlist.ConfigSectionName]['XSTFilterFile']
		#xstOptionsFilePath =	self.Host.Directories["XSTFiles"] / self.Host.NLConfig[		netlist.ConfigSectionName]['XSTOptionsFile']
		xstTemplateFilePath =	self.Host.Directories["XSTFiles"] / self.Host.PoCConfig[netlist.ConfigSectionName]['XSTOptionsFile']
		xstFilePath =					self._tempPath / (netlist.ModuleName + ".xst")
		prjFilePath =					self._tempPath / (netlist.ModuleName + ".prj")
		reportFilePath =			self._tempPath / (netlist.ModuleName + ".log")

		self._LogDebug("Writing XST project file to '{0!s}'".format(prjFilePath))
		self._WriteXilinxProjectFile(prjFilePath)

		self._LogDebug("Writing XST options file to '{0!s}'".format(xstFilePath))
		self._WriteXstOptionsFile(netlist,xstFilePath)

		self._RunPrepareCompile(netlist)
		self._RunPreCopy(netlist)
		self._RunPreReplace(netlist)
		self._RunCompile(netlist)
		self._RunPostCopy(netlist)
		self._RunPostReplace(netlist)

	def _RunPrepareCompile(self, netlist):
		pass

	def _RunCompile(self):
		xst = self._ise.GetXst()
		xst.Parameters[xst.SwitchIniStyle] =		"xflow"
		xst.Parameters[xst.SwitchXstFile] =			"ipcore.xst"
		xst.Parameters[xst.SwitchReportFile] =	"ipcore.xst.report"
		xst.Compile()

	def _WriteXstOptionsFile(self, netlist, xstFilePath):
		xstTemplateFilePath = self.Host.Directories["XSTFiles"] / self.Host.PoCConfig[netlist.ConfigSectionName]['XSTOptionsFile']
		if (not xstTemplateFilePath.exists()):		raise CompilerException("XST template files '{0!s}' not found.".format(xstTemplateFilePath)) from FileNotFoundError(str(xstTemplateFilePath))

		# read XST options file template
		self._LogDebug("  Reading Xilinx Compiler Tool option file from '{0!s}'".format(xstTemplateFilePath))
		with xstTemplateFilePath.open('r') as fileHandle:
			xstFileContent = fileHandle.read()

		xstTemplateDictionary = {
			'prjFile':                                                            str(prjFilePath),
			'UseNewParser': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.UseNewParser'],
			'InputFormat': self.Host.PoCConfig[netlist.ConfigSectionName]                   ['XSTOption.InputFormat'],
			'OutputFormat': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.OutputFormat'],
			'OutputName':                                                         netlist.TopLevel,
			'Part':                                                               str(self._device),
			'TopModuleName':                                                      netlist.TopLevel,
			'OptimizationMode': self.Host.PoCConfig[netlist.ConfigSectionName]              ['XSTOption.OptimizationMode'],
			'OptimizationLevel': self.Host.PoCConfig[netlist.ConfigSectionName]             ['XSTOption.OptimizationLevel'],
			'PowerReduction': self.Host.PoCConfig[netlist.ConfigSectionName]                ['XSTOption.PowerReduction'],
			'IgnoreSynthesisConstraintsFile': self.Host.PoCConfig[netlist.ConfigSectionName]['XSTOption.IgnoreSynthesisConstraintsFile'],
			'SynthesisConstraintsFile':                                           str(xcfFilePath),
			'KeepHierarchy': self.Host.PoCConfig[netlist.ConfigSectionName]                 ['XSTOption.KeepHierarchy'],
			'NetListHierarchy': self.Host.PoCConfig[netlist.ConfigSectionName]              ['XSTOption.NetListHierarchy'],
			'GenerateRTLView': self.Host.PoCConfig[netlist.ConfigSectionName]               ['XSTOption.GenerateRTLView'],
			'GlobalOptimization': self.Host.PoCConfig[netlist.ConfigSectionName]            ['XSTOption.Globaloptimization'],
			'ReadCores': self.Host.PoCConfig[netlist.ConfigSectionName]                     ['XSTOption.ReadCores'],
			'SearchDirectories':                                                  '"{0!s}"'.format(self._outputPath),
			'WriteTimingConstraints': self.Host.PoCConfig[netlist.ConfigSectionName]        ['XSTOption.WriteTimingConstraints'],
			'CrossClockAnalysis': self.Host.PoCConfig[netlist.ConfigSectionName]            ['XSTOption.CrossClockAnalysis'],
			'HierarchySeparator': self.Host.PoCConfig[netlist.ConfigSectionName]            ['XSTOption.HierarchySeparator'],
			'BusDelimiter': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.BusDelimiter'],
			'Case': self.Host.PoCConfig[netlist.ConfigSectionName]                          ['XSTOption.Case'],
			'SliceUtilizationRatio': self.Host.PoCConfig[netlist.ConfigSectionName]         ['XSTOption.SliceUtilizationRatio'],
			'BRAMUtilizationRatio': self.Host.PoCConfig[netlist.ConfigSectionName]          ['XSTOption.BRAMUtilizationRatio'],
			'DSPUtilizationRatio': self.Host.PoCConfig[netlist.ConfigSectionName]           ['XSTOption.DSPUtilizationRatio'],
			'LUTCombining': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.LUTCombining'],
			'ReduceControlSets': self.Host.PoCConfig[netlist.ConfigSectionName]             ['XSTOption.ReduceControlSets'],
			'Verilog2001': self.Host.PoCConfig[netlist.ConfigSectionName]                   ['XSTOption.Verilog2001'],
			'FSMExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                    ['XSTOption.FSMExtract'],
			'FSMEncoding': self.Host.PoCConfig[netlist.ConfigSectionName]                   ['XSTOption.FSMEncoding'],
			'FSMSafeImplementation': self.Host.PoCConfig[netlist.ConfigSectionName]         ['XSTOption.FSMSafeImplementation'],
			'FSMStyle': self.Host.PoCConfig[netlist.ConfigSectionName]                      ['XSTOption.FSMStyle'],
			'RAMExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                    ['XSTOption.RAMExtract'],
			'RAMStyle': self.Host.PoCConfig[netlist.ConfigSectionName]                      ['XSTOption.RAMStyle'],
			'ROMExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                    ['XSTOption.ROMExtract'],
			'ROMStyle': self.Host.PoCConfig[netlist.ConfigSectionName]                      ['XSTOption.ROMStyle'],
			'MUXExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                    ['XSTOption.MUXExtract'],
			'MUXStyle': self.Host.PoCConfig[netlist.ConfigSectionName]                      ['XSTOption.MUXStyle'],
			'DecoderExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                ['XSTOption.DecoderExtract'],
			'PriorityExtract': self.Host.PoCConfig[netlist.ConfigSectionName]               ['XSTOption.PriorityExtract'],
			'ShRegExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.ShRegExtract'],
			'ShiftExtract': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.ShiftExtract'],
			'XorCollapse': self.Host.PoCConfig[netlist.ConfigSectionName]                   ['XSTOption.XorCollapse'],
			'AutoBRAMPacking': self.Host.PoCConfig[netlist.ConfigSectionName]               ['XSTOption.AutoBRAMPacking'],
			'ResourceSharing': self.Host.PoCConfig[netlist.ConfigSectionName]               ['XSTOption.ResourceSharing'],
			'ASyncToSync': self.Host.PoCConfig[netlist.ConfigSectionName]                   ['XSTOption.ASyncToSync'],
			'UseDSP48': self.Host.PoCConfig[netlist.ConfigSectionName]                      ['XSTOption.UseDSP48'],
			'IOBuf': self.Host.PoCConfig[netlist.ConfigSectionName]                         ['XSTOption.IOBuf'],
			'MaxFanOut': self.Host.PoCConfig[netlist.ConfigSectionName]                     ['XSTOption.MaxFanOut'],
			'BufG': self.Host.PoCConfig[netlist.ConfigSectionName]                          ['XSTOption.BufG'],
			'RegisterDuplication': self.Host.PoCConfig[netlist.ConfigSectionName]           ['XSTOption.RegisterDuplication'],
			'RegisterBalancing': self.Host.PoCConfig[netlist.ConfigSectionName]             ['XSTOption.RegisterBalancing'],
			'SlicePacking': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.SlicePacking'],
			'OptimizePrimitives': self.Host.PoCConfig[netlist.ConfigSectionName]            ['XSTOption.OptimizePrimitives'],
			'UseClockEnable': self.Host.PoCConfig[netlist.ConfigSectionName]                ['XSTOption.UseClockEnable'],
			'UseSyncSet': self.Host.PoCConfig[netlist.ConfigSectionName]                    ['XSTOption.UseSyncSet'],
			'UseSyncReset': self.Host.PoCConfig[netlist.ConfigSectionName]                  ['XSTOption.UseSyncReset'],
			'PackIORegistersIntoIOBs': self.Host.PoCConfig[netlist.ConfigSectionName]       ['XSTOption.PackIORegistersIntoIOBs'],
			'EquivalentRegisterRemoval': self.Host.PoCConfig[netlist.ConfigSectionName]     ['XSTOption.EquivalentRegisterRemoval'],
			'SliceUtilizationRatioMaxMargin': self.Host.PoCConfig[netlist.ConfigSectionName]['XSTOption.SliceUtilizationRatioMaxMargin']
		}

		xstFileContent = xstFileContent.format(**xstTemplateDictionary)

		if (self.Host.PoCConfig.has_option(netlist.ConfigSectionName, 'XSTOption.Generics')):
			xstFileContent += "-generics {{ {0} }}".format(self.Host.PoCConfig[netlist.ConfigSectionName]['XSTOption.Generics'])

		self._LogDebug("Writing Xilinx Compiler Tool option file to '{0!s}'".format(xstFilePath))
		with xstFilePath.open('w') as fileHandle:
			fileHandle.write(xstFileContent)
