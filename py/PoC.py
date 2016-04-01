# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:         		 Patrick Lehmann
# 
# Python Main Module:  Entry point to the testbench tools in PoC repository.
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - runs automated testbenches,
#    - ...
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

from argparse									import RawDescriptionHelpFormatter
from colorama									import Fore as Foreground
from colorama									import init as colorama_init
from configparser							import NoOptionError, ConfigParser, ExtendedInterpolation
from configparser							import Error as ConfigParser_Error
from os												import environ
from pathlib									import Path
from sys											import argv as sys_argv
from textwrap									import dedent

from lib.Functions						import Exit
from lib.ArgParseAttributes		import *
from Base.Exceptions					import *
from Base.Logging							import Logger, Severity
from Parser.Parser						import ParserException
from Base.PoCBase							import CommandLineProgram
from PoC.Entity								import *
from PoC.Config								import *
from Simulator								import *
from Simulator.Exceptions			import *
from Compiler									import *
from Compiler.Exceptions			import *


# def HandleVerbosityOptions(func):
# 	def func_wrapper(self, args):
# 		self.ConfigureSyslog(args.quiet, args.verbose, args.debug)
# 		return func(self, args)
# 	return func_wrapper

class PoC(CommandLineProgram, ArgParseMixin):
	HeadLine =								"The PoC-Library - NetList Service Tool"
	__tbConfigFileName =			"configuration.ini"
	__netListConfigFileName =	"configuration.ini"

	@CommonSwitchArgumentAttribute("-D",							dest="DEBUG",		help="enable script wrapper debug mode")
	@CommonSwitchArgumentAttribute("-d", "--debug",		dest="debug",		help="enable debug mode")
	@CommonSwitchArgumentAttribute("-v", "--verbose",	dest="verbose",	help="print out detailed messages")
	@CommonSwitchArgumentAttribute("-q", "--quiet",		dest="quiet",		help="reduce messages to a minimum")
	def __init__(self, debug, verbose, quiet, dryRun):
		if quiet:				severity = Severity.Quiet
		elif debug:			severity = Severity.Debug
		elif verbose:		severity = Severity.Verbose
		else:						severity = Severity.Normal

		logger = Logger(self, severity, printToStdOut=True)
		super().__init__(logger=logger)

		if (self.Platform == "Windows"):	pass
		elif (self.Platform == "Linux"):	pass
		else:															raise PlatformNotSupportedException(self.Platform)

		self._dryRun = dryRun

		# self._config = None
		self.__ReadTestbenchConfiguration()
		self.__ReadNetlistConfiguration()

		# Call the constructor of the ArgParseMixin
		ArgParseMixin.__init__(self,
			# prog =	self.program,
			# usage =	"Usage?",			# override usage string
			description=dedent('''\
				This is the PoC-Library Service Tool.
				'''),
			epilog="Epidingsbums",
			formatter_class=RawDescriptionHelpFormatter,
			add_help=False)


	# read Testbench configuration
	# ==========================================================================
	def __ReadTestbenchConfiguration(self) :
		from configparser import ConfigParser, ExtendedInterpolation

		tbConfigFilePath = self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames'][
			'TestbenchFiles'] / self.__tbConfigFileName
		self.Files["PoCTBConfig"] = tbConfigFilePath

		self._LogDebug("Reading testbench configuration from '{0}'".format(str(tbConfigFilePath)))
		if not tbConfigFilePath.exists() :                raise NotConfiguredException(
			"PoC testbench configuration file does not exist. ({0})".format(str(tbConfigFilePath)))

		self.tbConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.tbConfig.optionxform = str
		self.tbConfig.read([
			str(self.Files["PoCPrivateConfig"]),
			str(self.Files["PoCPublicConfig"]),
			str(self.Files["PoCTBConfig"])
		])

	# read NetList configuration
	# ==========================================================================
	def __ReadNetlistConfiguration(self):
		self.Files["PoCNLConfig"] = self.Directories["PoCNetList"] / self.__netListConfigFileName
		netListConfigFilePath	= self.Files["PoCNLConfig"]
		
		self._LogDebug("Reading NetList configuration from '{0}'".format(str(netListConfigFilePath)))
		if not netListConfigFilePath.exists():	raise NotConfiguredException("PoC netlist configuration file does not exist. ({0})".format(str(netListConfigFilePath)))
			
		self.netListConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.netListConfig.optionxform = str
		self.netListConfig.read([
			str(self.Files['PoCPrivateConfig']),
			str(self.Files['PoCPublicConfig']),
			str(self.Files["PoCNLConfig"])
		])

	def PrintHeadline(self):
		# self._LogNormal(Foreground.MAGENTA + "=" * 80)
		self._LogNormal(Foreground.LIGHTMAGENTA_EX + "=" * 80)
		self._LogNormal("{: ^80s}".format(self.HeadLine))
		self._LogNormal("=" * 80 + Foreground.RESET)

	def Run(self):
		ArgParseMixin.Run(self)

	# ============================================================================
	# Common commands
	# ============================================================================
	# fallback handler if no command was recognized
	# ----------------------------------------------------------------------------
	@DefaultAttribute()
	# @HandleVerbosityOptions
	def HandleDefault(self, args) :
		self.PrintHeadline()
		self.MainParser.print_help()
		Exit.exit()

	# create the sub-parser for the "help" command
	# ----------------------------------------------------------------------------
	@CommandAttribute('help', help="help help")
	@ArgumentAttribute(metavar='<Command>', dest="Commands", type=str, nargs='*', help='todo help')
	# @HandleVerbosityOptions
	def HandleHelp(self, args) :
		self.PrintHeadline()
		if (len(args.Commands) == 0) :
			# self.__parsers["Help"].print_help()
			Exit.exit()
		elif (len(args.Commands) == 1) :
			if (args.Commands[0] == "help") :
				print("This is a recursion ...")
		Exit.exit()

	# ============================================================================
	# Simulation	commands
	# ============================================================================
	def __PrepareVendorLibraryPaths(self) :
		# prepare vendor library path for Altera
		if (len(self.pocConfig.options("Altera.QuartusII")) != 0) :  self.Directories["AlteraPrimitiveSource"] = Path(
				self.pocConfig['Altera.QuartusII']['InstallationDirectory']) / "eda/sim_lib"
		# prepare vendor library path for Xilinx
		if (len(self.pocConfig.options("Xilinx.ISE")) != 0) :
			self.Directories["XilinxPrimitiveSource"] = Path(
					self.pocConfig['Xilinx.ISE']['InstallationDirectory']) / "ISE/vhdl/src"
		elif (len(self.pocConfig.options("Xilinx.Vivado")) != 0) :
			self.Directories["XilinxPrimitiveSource"] = Path(
					self.pocConfig['Xilinx.Vivado']['InstallationDirectory']) / "data/vhdl/src"

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "asim" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Simulation commands")
	@CommandAttribute("asim", help="Simulate a PoC Entity with Aldec Active-HDL")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	@ArgumentAttribute('--std', metavar="<VHDLVersion>", dest="VHDLVersion", help="Simulate with VHDL-??")
	# @SwitchArgumentAttribute("-08", dest="VHDLVersion", help="Simulate with VHDL-2008.")
	@SwitchArgumentAttribute("-g", dest="GUIMode", help="show waveform in a GUI window.")
	# standard
	# @HandleVerbosityOptions
	def aSimSimulation(self, args) :
		self.PrintHeadline()
		self._aSimSimulation(args.FQN[0], args.logs, args.reports, args.VHDLVersion, args.GUIMode, args.DeviceName, args.BoardName)
		Exit.exit()

	def _aSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString) :
		# check if Aldec tools are configure
		if (len(self.pocConfig.options("Aldec.ActiveHDL")) != 0) :
			# prepare some paths
			self.Directories["ActiveHDLInstallation"] = Path(self.pocConfig['Aldec.ActiveHDL']['InstallationDirectory'])
			self.Directories["ActiveHDLBinary"] = Path(self.pocConfig['Aldec.ActiveHDL']['BinaryDirectory'])
			aSimVersion = self.pocConfig['Aldec.ActiveHDL']['Version']
		elif (len(self.pocConfig.options("Lattice.ActiveHDL")) != 0) :
			# prepare some paths
			self.Directories["ActiveHDLInstallation"] = Path(self.pocConfig['Lattice.ActiveHDL']['InstallationDirectory'])
			self.Directories["ActiveHDLBinary"] = Path(self.pocConfig['Lattice.ActiveHDL']['BinaryDirectory'])
			aSimVersion = self.pocConfig['Lattice.ActiveHDL']['Version']
		# elif (len(self.pocConfig.options("Aldec.RivieraPRO")) != 0):
		# # prepare some paths
		# self.Directories["ActiveHDLInstallation"] =	Path(self.pocConfig['Aldec.RivieraPRO']['InstallationDirectory'])
		# self.Directories["ActiveHDLBinary"] =				Path(self.pocConfig['Aldec.RivieraPRO']['BinaryDirectory'])
		# aSimVersion =																self.pocConfig['Aldec.RivieraPRO']['Version']
		else :
			# raise NotConfiguredException("Neither Aldec's Active-HDL nor Riviera PRO nor Active-HDL Lattice Edition are configured on this system.")
			raise NotConfiguredException(
				"Neither Aldec's Active-HDL nor Active-HDL Lattice Edition are configured on this system.")

		# prepare paths to vendor simulation libraries
		self.__PrepareVendorLibraryPaths()

		self.Directories["ActiveHDLTemp"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'ActiveHDLSimulatorFiles']

		# create a simulator instance
		simulator = ActiveHDLSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		aSimBinaryPath = self.Directories["ActiveHDLBinary"]
		simulator.PrepareSimulator(aSimBinaryPath, aSimVersion)

		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None) :
			boardName = boardString
			deviceName = None
		elif (deviceString is not None) :
			boardName = "Custom"
			deviceName = deviceString
		else :
			boardName = "Custom"
			deviceName = "Unknown"

		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion,
									vhdlGenerics=None)

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "ghdl" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Simulation commands")
	@CommandAttribute("ghdl", help="Simulate a PoC Entity with GHDL")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	@ArgumentAttribute('--std', metavar="<VHDLVersion>", dest="VHDLVersion", help="Simulate with VHDL-??")
	# @SwitchArgumentAttribute("-08", dest="VHDLVersion", help="Simulate with VHDL-2008.")
	@SwitchArgumentAttribute("-g", dest="GUIMode", help="show waveform in GTKWave.")
	# standard
	# @HandleVerbosityOptions
	def ghdlSimulation(self, args) :
		self.PrintHeadline()
		self._ghdlSimulation(args.FQN[0], args.logs, args.reports, args.VHDLVersion, args.GUIMode, args.DeviceName, args.BoardName)
		Exit.exit()

	def _ghdlSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString) :
		# check if GHDL is configure
		if (len(self.pocConfig.options("GHDL")) == 0) :  raise NotConfiguredException(
			"GHDL is not configured on this system.")

		# prepare some paths
		self.Directories["GHDLTemp"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'GHDLSimulatorFiles']
		self.Directories["GHDLPrecompiled"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'PrecompiledFiles'] / self.pocConfig['PoC.DirectoryNames']['GHDLSimulatorFiles']
		self.Directories["GHDLInstallation"] = Path(self.pocConfig['GHDL']['InstallationDirectory'])
		self.Directories["GHDLBinary"] = Path(self.pocConfig['GHDL']['BinaryDirectory'])
		ghdlVersion = self.pocConfig['GHDL']['Version']
		ghdlBackend = self.pocConfig['GHDL']['Backend']

		# prepare paths to vendor simulation libraries
		self.__PrepareVendorLibraryPaths()

		# create a GHDLSimulator instance
		simulator = GHDLSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		ghdlBinaryPath = self.Directories["GHDLBinary"]
		simulator.PrepareSimulator(ghdlBinaryPath, ghdlVersion, ghdlBackend)

		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None) :
			boardName = boardString
			deviceName = None
		elif (deviceString is not None) :
			boardName = "Custom"
			deviceName = deviceString
		else :
			boardName = "Custom"
			deviceName = "Unknown"

		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion,
									vhdlGenerics=None)

		if (guiMode == True) :
			# prepare paths for GTKWave, if configured
			if (len(self.pocConfig.options("GTKWave")) != 0) :
				self.Directories["GTKWInstallation"] = Path(self.pocConfig['GTKWave']['InstallationDirectory'])
				self.Directories["GTKWBinary"] = Path(self.pocConfig['GTKWave']['BinaryDirectory'])
			else :
				raise NotConfiguredException("No GHDL compatible waveform viewer is configured on this system.")

			viewer = simulator.GetViewer()
			viewer.View(entityToSimulate)

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "isim" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Simulation commands")
	@CommandAttribute("isim", help="Simulate a PoC Entity with Xilinx ISE Simulator (iSim)")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	@SwitchArgumentAttribute("-g", dest="GUIMode", help="show waveform in a GUI window.")
	# standard
	# @HandleVerbosityOptions
	def iSimSimulation(self, args) :
		self.PrintHeadline()
		self._iSimSimulation(args.FQN[0], args.logs, args.reports, args.GUIMode, args.DeviceName, args.BoardName)
		Exit.exit()

	def _iSimSimulation(self, module, showLogs, showReport, guiMode, deviceString, boardString) :
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.ISE")) == 0) :  raise NotConfiguredException(
			"Xilinx ISE is not configured on this system.")
		# check if the appropriate environment is loaded
		if (environ.get('XILINX') is None) :                    raise EnvironmentException(
			"Xilinx ISE environment is not loaded in this shell environment. ")

		# prepare some paths
		self.Directories["iSimFiles"] = self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames'][
			'ISESimulatorFiles']
		self.Directories["iSimTemp"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'ISESimulatorFiles']

		self.Directories["ISEInstallation"] = Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] = Path(self.pocConfig['Xilinx.ISE']['BinaryDirectory'])
		self.Directories["XilinxPrimitiveSource"] = Path(
				self.pocConfig['Xilinx.ISE']['InstallationDirectory']) / "ISE/vhdl/src"
		iseVersion = self.pocConfig['Xilinx.ISE']['Version']

		# create a ISESimulator instance
		simulator = ISESimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		iseBinaryPath = self.Directories["ISEBinary"]
		simulator.PrepareSimulator(iseBinaryPath, iseVersion)

		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None) :
			boardName = boardString
			deviceName = None
		elif (deviceString is not None) :
			boardName = "Custom"
			deviceName = deviceString
		else :
			boardName = "Custom"
			deviceName = "Unknown"

		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlGenerics=None)

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "vsim" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Simulation commands")
	@CommandAttribute("vsim", help="Simulate a PoC Entity with Mentor QuestaSim or ModelSim (vsim)")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	@ArgumentAttribute('--std', metavar="<VHDLVersion>", dest="VHDLVersion", help="Simulate with VHDL-??")
	# @SwitchArgumentAttribute("-08", dest="VHDLVersion", help="Simulate with VHDL-2008.")
	@SwitchArgumentAttribute("-g", dest="GUIMode", help="show waveform in a GUI window.")
	# standard
	# @HandleVerbosityOptions
	def vSimSimulation(self, args) :
		self.PrintHeadline()
		self._vSimSimulation(args.FQN[0], args.logs, args.reports, args.VHDLVersion, args.GUIMode, args.DeviceName, args.BoardName)
		Exit.exit()

	def _vSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString) :
		# check if QuestaSim is configure
		if (len(self.pocConfig.options("Mentor.QuestaSim")) != 0) :
			# prepare some paths
			self.Directories["vSimInstallation"] = Path(self.pocConfig['Mentor.QuestaSim']['InstallationDirectory'])
			self.Directories["vSimBinary"] = Path(self.pocConfig['Mentor.QuestaSim']['BinaryDirectory'])
			vSimVersion = self.pocConfig['Mentor.QuestaSim']['Version']
		elif (len(self.pocConfig.options("Altera.ModelSim")) != 0) :
			# prepare some paths
			self.Directories["vSimInstallation"] = Path(self.pocConfig['Altera.ModelSim']['InstallationDirectory'])
			self.Directories["vSimBinary"] = Path(self.pocConfig['Altera.ModelSim']['BinaryDirectory'])
			vSimVersion = self.pocConfig['Altera.QuestaSim']['Version']
		else :
			raise NotConfiguredException(
				"Neither Mentor Graphics QuestaSim nor ModelSim Altera-Edition are configured on this system.")

		self.Directories["vSimTemp"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'ModelSimSimulatorFiles']

		# create a QuestaSimulator instance
		simulator = QuestaSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		vSimBinaryPath = self.Directories["vSimBinary"]
		simulator.PrepareSimulator(vSimBinaryPath, vSimVersion)

		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None) :
			boardName = boardString
			deviceName = None
		elif (deviceString is not None) :
			boardName = "Custom"
			deviceName = deviceString
		else :
			boardName = "Custom"
			deviceName = "Unknown"

		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion, vhdlGenerics=None)

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "asim" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Simulation commands")
	@CommandAttribute("xsim", help="Simulate a PoC Entity with Xilinx Vivado Simulator (xSim)")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	@ArgumentAttribute('--std', metavar="<VHDLVersion>", dest="VHDLVersion", help="Simulate with VHDL-??")
	# @SwitchArgumentAttribute("-08", dest="VHDLVersion", help="Simulate with VHDL-2008.")
	@SwitchArgumentAttribute("-g", dest="GUIMode", help="show waveform in a GUI window.")
	# standard
	# @HandleVerbosityOptions
	def xSimSimulation(self, args) :
		self.PrintHeadline()
		self._xSimSimulation(args.FQN[0], args.logs, args.reports, args.VHDLVersion, args.GUIMode, args.DeviceName, args.BoardName)
		Exit.exit()

	def _xSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString) :
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.Vivado")) == 0) :  raise NotConfiguredException(
			"Xilinx Vivado is not configured on this system.")
		# check if the appropriate environment is loaded
		# if (environ.get('XILINX') is None):										raise EnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")

		# prepare some paths
		self.Directories["xSimTemp"] = self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames'][
			'VivadoSimulatorFiles']
		self.Directories["VivadoInstallation"] = Path(self.pocConfig['Xilinx.Vivado']['InstallationDirectory'])
		self.Directories["VivadoBinary"] = Path(self.pocConfig['Xilinx.Vivado']['BinaryDirectory'])
		self.Directories["XilinxPrimitiveSource"] = Path(
				self.pocConfig['Xilinx.Vivado']['InstallationDirectory']) / "data/vhdl/src"
		vivadoVersion = self.pocConfig['Xilinx.Vivado']['Version']

		# create a VivadoSimulator instance
		simulator = VivadoSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		vivadoBinaryPath = self.Directories["VivadoBinary"]
		simulator.PrepareSimulator(vivadoBinaryPath, vivadoVersion)

		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None) :
			boardName = boardString
			deviceName = None
		elif (deviceString is not None) :
			boardName = "Custom"
			deviceName = deviceString
		else :
			boardName = "Custom"
			deviceName = "Unknown"

		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion,
									vhdlGenerics=None)

	# ============================================================================
	# Synthesis	commands
	# ============================================================================
	# create the sub-parser for the "coregen" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Synthesis commands")
	@CommandAttribute("coregen", help="Generate an IP core with Xilinx ISE Core Generator")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	# @HandleVerbosityOptions
	def CoreGenCompilation(self, args) :
		self.PrintHeadline()
		self._CoreGenCompilation(args.FQN[0], args.logs, args.reports, args.DeviceName, args.BoardName)
		Exit.exit()

	def _CoreGenCompilation(self, entity, showLogs, showReport, deviceString=None, boardString=None):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.ISE")) == 0):	raise NotConfiguredException("Xilinx ISE is not configured on this system.")
		# check if the appropriate environment is loaded
		if (environ.get('XILINX') is None):										raise EnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")
		
		# prepare some paths
		self.Directories["CoreGenTemp"] =			self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ISECoreGeneratorFiles']
		self.Directories["ISEInstallation"] = Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] =				Path(self.pocConfig['Xilinx.ISE']['BinaryDirectory'])
		iseVersion =													self.pocConfig['Xilinx.ISE']['Version']

		if (boardString is not None):
			boardString = boardString.lower()
			boardSection = None
			for option in self.pocConfig['BOARDS']:
				if (option.lower() == boardString):
					boardSection = self.pocConfig['BOARDS'][option]
			if (boardSection is None):
				raise CompilerException("Unknown board '" + boardString + "'.") from NoOptionError(boardString, 'BOARDS')

			deviceString =	self.pocConfig[boardSection]['FPGA']
			device =				Device(deviceString)
		elif (deviceString is not None):
			device = Device(deviceString)
		else: raise BaseException("No board or device given.")

		entityToCompile = Entity(self, entity)

		compiler = XCOCompiler.Compiler(self, showLogs, showReport)
		compiler.dryRun = self._dryRun
		compiler.Run(entityToCompile, device)

	# ----------------------------------------------------------------------------
	# create the sub-parser for the "coregen" command
	# ----------------------------------------------------------------------------
	@CommandGroupAttribute("Synthesis commands")
	@CommandAttribute("xst", help="Compile a PoC IP core with Xilinx ISE XST to a netlist")
	@ArgumentAttribute(metavar="<PoC Entity>", dest="FQN", type=str, nargs='+', help="todo help")
	@ArgumentAttribute('--device', metavar="<DeviceName>", dest="DeviceName", help="todo")
	@ArgumentAttribute('--board', metavar="<BoardName>", dest="BoardName", help="todo")
	@SwitchArgumentAttribute("-l", dest="logs", help="show logs")
	@SwitchArgumentAttribute("-r", dest="reports", help="show reports")
	# @HandleVerbosityOptions
	def XstCompilation(self, args) :
		self.PrintHeadline()
		self._XstCompilation(args.FQN, args.logs, args.reports, args.DeviceName, args.BoardName)
		Exit.exit()

	def _XstCompilation(self, entity, showLogs, showReport, deviceString=None, boardString=None):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.ISE")) == 0):	raise NotConfiguredException("Xilinx ISE is not configured on this system.")
		# check if the appropriate environment is loaded
		if (environ.get('XILINX') is None):										raise EnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")
		
		# prepare some paths
		self.Directories["XSTFiles"] =				self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['ISESynthesisFiles']
		self.Directories["XSTTemp"] =					self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ISESynthesisFiles']
		self.Directories["ISEInstallation"] = Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] =				Path(self.pocConfig['Xilinx.ISE']['BinaryDirectory'])
		iseVersion =													self.pocConfig['Xilinx.ISE']['Version']

		if (boardString is not None) :
			boardString = boardString.lower()
			boardSection = None
			for option in self.pocConfig['BOARDS'] :
				if (option.lower() == boardString) :
					boardSection = self.pocConfig['BOARDS'][option]
			if (boardSection is None) :
				raise CompilerException("Unknown board '" + boardString + "'.") from NoOptionError(boardString, 'BOARDS')

			deviceString = self.pocConfig[boardSection]['FPGA']
			device = Device(deviceString)
		elif (deviceString is not None) :
			device = Device(deviceString)
		else :
			raise BaseException("No board or device given.")

		entityToCompile = Entity(self, entity)

		compiler = XSTCompiler.Compiler(self, showLogs, showReport)
		compiler.dryRun = self.dryRun
		compiler.Run(entityToCompile, device)


# main program
def main():
	dryRun =	"-D" in sys_argv
	debug =		"-d" in sys_argv
	verbose =	"-v" in sys_argv
	quiet =		"-q" in sys_argv

	# configure Exit class
	Exit.quiet = quiet

	try:
		colorama_init()
		# handover to a class instance
		poc = PoC(debug, verbose, quiet, dryRun)
		poc.Run()
		Exit.exit()

	except (SimulatorException, CompilerException) as ex :
		print(Foreground.RED + "ERROR:" + Foreground.RESET + " {0}".format(ex.message))
		if isinstance(ex.__cause__, FileNotFoundError) :
			print("{0}  FileNotFound:{1} '{2}'".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
		elif isinstance(ex.__cause__, ParserException) :
			print("{0}  ParserException:{1} {2}".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
			if (ex.__cause__.__cause__ is not None) :
				print("{0}    {1}:{2} {3}".format(Foreground.LIGHTYELLOW_EX, ex.__cause__.__cause__.__class__.__name__,
																					Foreground.RESET, str(ex.__cause__.__cause__)))
		elif isinstance(ex.__cause__, ConfigParser_Error) :
			print("{0}  configparser.Error:{1} '{2}'".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
		print(Foreground.RESET)
		Exit.exit(1)

	except EnvironmentException as ex:					Exit.printEnvironmentException(ex)
	except NotConfiguredException as ex:				Exit.printNotConfiguredException(ex)
	except PlatformNotSupportedException as ex:	Exit.printPlatformNotSupportedException(ex)
	except BaseException as ex:									Exit.printBaseException(ex)
	except NotImplementedException as ex:				Exit.printNotImplementedException(ex)
	except Exception as ex:											Exit.printException(ex)

		# # add arguments
		# group1 = argParser.add_argument_group('Verbosity')
		# group1.add_argument('-D', 																											help='enable script wrapper debug mode',	action='store_const', const=True, default=False)
		# group1.add_argument('-d',																		dest="debug",				help='enable debug mode',									action='store_const', const=True, default=False)
		# group1.add_argument('-v',																		dest="verbose",			help='print out detailed messages',				action='store_const', const=True, default=False)
		# group1.add_argument('-q',																		dest="quiet",				help='run in quiet mode',									action='store_const', const=True, default=False)
		# group1.add_argument('-r',																		dest="showReport",	help='show report',												action='store_const', const=True, default=False)
		# group1.add_argument('-l',																		dest="showLog",			help='show logs',													action='store_const', const=True, default=False)
		# group2 = argParser.add_argument_group('Commands')
		# group21 = group2.add_mutually_exclusive_group(required=True)
		# group21.add_argument('-h', '--help',												dest="help",				help='show this help message and exit',		action='store_const', const=True, default=False)
		# group211 = group21.add_mutually_exclusive_group()
		# group211.add_argument(		 '--coregen',	metavar="<Entity>",	dest="coreGen",			help='use Xilinx IP-Core Generator (CoreGen)')
		# group211.add_argument(		 '--xst',			metavar="<Entity>",	dest="xst",					help='use Xilinx Compiler Tool (XST)')
		# group3 = group211.add_argument_group('Specify target platform')
		# group31 = group3.add_mutually_exclusive_group()
		# group31.add_argument('--device',				metavar="<Device>",	dest="device",			help='target device (e.g. XC5VLX50T-1FF1136)')
		# group31.add_argument('--board',					metavar="<Board>",	dest="board",				help='target board to infere the device (e.g. ML505)')

# entry point
if __name__ == "__main__":
	Exit.versionCheck((3,4,0))
	main()
else:
	Exit.printThisIsNoLibraryFile(PoC.HeadLine)
