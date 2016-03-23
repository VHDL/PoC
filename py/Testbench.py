# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 		Patrick Lehmann
# 
# Python Executable:	Entry point to the testbench tools in PoC repository.
# 
# Description:
# ------------------------------------
#	This is a python main module (executable) which:
#		- runs automated testbenches,
#		- ...
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

from argparse							import ArgumentParser, RawDescriptionHelpFormatter
import textwrap
from colorama							import Fore as Foreground
from colorama							import init as colorama_init
from pathlib							import Path
from os										import environ
from configparser					import Error as ConfigParser_Error

from lib.Functions				import Exit
from Base.Exceptions			import *
from Base.Logging					import Logger, Severity
from Base.PoCBase					import CommandLineProgram
from PoC.Entity						import *
from Parser.Parser				import ParserException
from Simulator						import *
from Simulator.Exceptions	import *

class Testbench(CommandLineProgram):
	headLine = "The PoC-Library - Testbench Service Tool"
	
	# configuration files
	__tbConfigFileName = "configuration.ini"
	
	def __init__(self, debug, verbose, quiet):
		if quiet:			severity = Severity.Quiet
		elif debug:		severity = Severity.Debug
		elif verbose:	severity = Severity.Verbose
		else:					severity = Severity.Normal
		
		logger =			Logger(self, severity, printToStdOut=True)
		super(self.__class__, self).__init__(logger=logger)

		if		(self.Platform == "Windows"):	pass
		elif	(self.Platform == "Linux"):		pass
		else:																						raise PlatformNotSupportedException(self.Platform)
		
		self._config =			None
		self.__ReadTestbenchConfiguration()
	
		
	# read Testbench configuration
	# ==========================================================================
	def __ReadTestbenchConfiguration(self):
		from configparser import ConfigParser, ExtendedInterpolation
	
		tbConfigFilePath = self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['TestbenchFiles'] / self.__tbConfigFileName
		self.Files["PoCTBConfig"] = tbConfigFilePath
		
		self._LogDebug("Reading testbench configuration from '{0}'".format(str(tbConfigFilePath)))
		if not tbConfigFilePath.exists():								raise NotConfiguredException("PoC testbench configuration file does not exist. ({0})".format(str(tbConfigFilePath)))
			
		self.tbConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.tbConfig.optionxform = str
		self.tbConfig.read([
			str(self.Files["PoCPrivateConfig"]),
			str(self.Files["PoCPublicConfig"]),
			str(self.Files["PoCTBConfig"])
		])
	
	def listSimulations(self, module):
		entityToList = Entity(self, module)
		
		print(str(entityToList))
		
		print(self.tbConfig.sections())
		print()
		print(self.tbConfig.options("PoC"))
		print()
		
		for sec in self.tbConfig.sections():
			if (sec[:4] == "PoC."):
				print(sec)
		
		return("return ...")
		return
	
	def __PrepareVendorLibraryPaths(self):
		# prepare vendor library path for Altera
		if (len(self.pocConfig.options("Altera.QuartusII")) != 0):	self.Directories["AlteraPrimitiveSource"] =	Path(self.pocConfig['Altera.QuartusII']['InstallationDirectory'])	/ "eda/sim_lib"
		# prepare vendor library path for Xilinx
		if (len(self.pocConfig.options("Xilinx.ISE")) != 0):				self.Directories["XilinxPrimitiveSource"] =	Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])				/ "ISE/vhdl/src"
		elif (len(self.pocConfig.options("Xilinx.Vivado")) != 0):		self.Directories["XilinxPrimitiveSource"] =	Path(self.pocConfig['Xilinx.Vivado']['InstallationDirectory'])		/ "data/vhdl/src"
	
	def aSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString):
		# check if Aldec tools are configure
		if (len(self.pocConfig.options("Aldec.ActiveHDL")) != 0):
			# prepare some paths
			self.Directories["ActiveHDLInstallation"] =	Path(self.pocConfig['Aldec.ActiveHDL']['InstallationDirectory'])
			self.Directories["ActiveHDLBinary"] =				Path(self.pocConfig['Aldec.ActiveHDL']['BinaryDirectory'])
			aSimVersion =																self.pocConfig['Aldec.ActiveHDL']['Version']
		elif (len(self.pocConfig.options("Lattice.ActiveHDL")) != 0):
			# prepare some paths
			self.Directories["ActiveHDLInstallation"] =	Path(self.pocConfig['Lattice.ActiveHDL']['InstallationDirectory'])
			self.Directories["ActiveHDLBinary"] =				Path(self.pocConfig['Lattice.ActiveHDL']['BinaryDirectory'])
			aSimVersion =																self.pocConfig['Lattice.ActiveHDL']['Version']
		# elif (len(self.pocConfig.options("Aldec.RivieraPRO")) != 0):
			# # prepare some paths
			# self.Directories["ActiveHDLInstallation"] =	Path(self.pocConfig['Aldec.RivieraPRO']['InstallationDirectory'])
			# self.Directories["ActiveHDLBinary"] =				Path(self.pocConfig['Aldec.RivieraPRO']['BinaryDirectory'])
			# aSimVersion =																self.pocConfig['Aldec.RivieraPRO']['Version']
		else:
			# raise NotConfiguredException("Neither Aldec's Active-HDL nor Riviera PRO nor Active-HDL Lattice Edition are configured on this system.")
			raise NotConfiguredException("Neither Aldec's Active-HDL nor Active-HDL Lattice Edition are configured on this system.")

		# prepare paths to vendor simulation libraries
		self.__PrepareVendorLibraryPaths()
		
		self.Directories["ActiveHDLTemp"] =			self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ActiveHDLSimulatorFiles']
		
		# create a simulator instance
		simulator = ActiveHDLSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		aSimBinaryPath =	self.Directories["ActiveHDLBinary"]
		simulator.PrepareSimulator(aSimBinaryPath, aSimVersion)
		
		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None):
			boardName =		boardString
			deviceName =	None
		elif (deviceString is not None):
			boardName =		"Custom"
			deviceName =	deviceString
		else:
			boardName =		"Custom"
			deviceName =	"Unknown"
		
		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion, vhdlGenerics=None)
		
	def ghdlSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString):
		# check if GHDL is configure
		if (len(self.pocConfig.options("GHDL")) == 0):	raise NotConfiguredException("GHDL is not configured on this system.")
		
		# prepare some paths
		self.Directories["GHDLTemp"] =					self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['GHDLSimulatorFiles']
		self.Directories["GHDLPrecompiled"] =		self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['PrecompiledFiles'] / self.pocConfig['PoC.DirectoryNames']['GHDLSimulatorFiles']
		self.Directories["GHDLInstallation"] =	Path(self.pocConfig['GHDL']['InstallationDirectory'])
		self.Directories["GHDLBinary"] =				Path(self.pocConfig['GHDL']['BinaryDirectory'])
		ghdlVersion =														self.pocConfig['GHDL']['Version']
		ghdlBackend =														self.pocConfig['GHDL']['Backend']

		# prepare paths to vendor simulation libraries
		self.__PrepareVendorLibraryPaths()

		# create a GHDLSimulator instance
		simulator = GHDLSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		ghdlBinaryPath =	self.Directories["GHDLBinary"]
		simulator.PrepareSimulator(ghdlBinaryPath, ghdlVersion, ghdlBackend)
		
		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None):
			boardName =		boardString
			deviceName =	None
		elif (deviceString is not None):
			boardName =		"Custom"
			deviceName =	deviceString
		else:
			boardName =		"Custom"
			deviceName =	"Unknown"
		
		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion, vhdlGenerics=None)
		
		if (guiMode == True):
			# prepare paths for GTKWave, if configured
			if (len(self.pocConfig.options("GTKWave")) != 0):		
				self.Directories["GTKWInstallation"] =	Path(self.pocConfig['GTKWave']['InstallationDirectory'])
				self.Directories["GTKWBinary"] =				Path(self.pocConfig['GTKWave']['BinaryDirectory'])
			else:
				raise NotConfiguredException("No GHDL compatible waveform viewer is configured on this system.")
			
			viewer = simulator.GetViewer()
			viewer.View(entityToSimulate)
	
	def iSimSimulation(self, module, showLogs, showReport, guiMode, deviceString, boardString):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.ISE")) == 0):	raise NotConfiguredException("Xilinx ISE is not configured on this system.")
		# check if the appropriate environment is loaded
		if (environ.get('XILINX') is None):										raise EnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")
		
		# prepare some paths
		self.Directories["iSimFiles"] =							self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['ISESimulatorFiles']
		self.Directories["iSimTemp"] =							self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ISESimulatorFiles']
		
		self.Directories["ISEInstallation"] = 			Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] =							Path(self.pocConfig['Xilinx.ISE']['BinaryDirectory'])
		self.Directories["XilinxPrimitiveSource"] =	Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory']) / "ISE/vhdl/src"
		iseVersion =																self.pocConfig['Xilinx.ISE']['Version']
		
		# create a ISESimulator instance
		simulator = ISESimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		iseBinaryPath =	self.Directories["ISEBinary"]
		simulator.PrepareSimulator(iseBinaryPath, iseVersion)
		
		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None):
			boardName =		boardString
			deviceName =	None
		elif (deviceString is not None):
			boardName =		"Custom"
			deviceName =	deviceString
		else:
			boardName =		"Custom"
			deviceName =	"Unknown"
		
		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlGenerics=None)

	def vSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString):
		# check if QuestaSim is configure
		if (len(self.pocConfig.options("Mentor.QuestaSim")) != 0):
			# prepare some paths
			self.Directories["vSimInstallation"] =	Path(self.pocConfig['Mentor.QuestaSim']['InstallationDirectory'])
			self.Directories["vSimBinary"] =				Path(self.pocConfig['Mentor.QuestaSim']['BinaryDirectory'])
			vSimVersion =														self.pocConfig['Mentor.QuestaSim']['Version']
		elif (len(self.pocConfig.options("Altera.ModelSim")) != 0):
			# prepare some paths
			self.Directories["vSimInstallation"] =	Path(self.pocConfig['Altera.ModelSim']['InstallationDirectory'])
			self.Directories["vSimBinary"] =				Path(self.pocConfig['Altera.ModelSim']['BinaryDirectory'])
			vSimVersion =														self.pocConfig['Altera.QuestaSim']['Version']
		else:																						raise NotConfiguredException("Neither Mentor Graphics QuestaSim nor ModelSim Altera-Edition are configured on this system.")

		self.Directories["vSimTemp"] =			self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ModelSimSimulatorFiles']
		
		# create a QuestaSimulator instance
		simulator = QuestaSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		vSimBinaryPath =	self.Directories["vSimBinary"]
		simulator.PrepareSimulator(vSimBinaryPath, vSimVersion)
		
		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None):
			boardName =		boardString
			deviceName =	None
		elif (deviceString is not None):
			boardName =		"Custom"
			deviceName =	deviceString
		else:
			boardName =		"Custom"
			deviceName =	"Unknown"
		
		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion, vhdlGenerics=None)

	def xSimSimulation(self, module, showLogs, showReport, vhdlVersion, guiMode, deviceString, boardString):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx.Vivado")) == 0):	raise NotConfiguredException("Xilinx Vivado is not configured on this system.")
		# check if the appropriate environment is loaded
		# if (environ.get('XILINX') is None):										raise EnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")

		# prepare some paths
		self.Directories["xSimTemp"] =							self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['VivadoSimulatorFiles']
		self.Directories["VivadoInstallation"] =		Path(self.pocConfig['Xilinx.Vivado']['InstallationDirectory'])
		self.Directories["VivadoBinary"] =					Path(self.pocConfig['Xilinx.Vivado']['BinaryDirectory'])
		self.Directories["XilinxPrimitiveSource"] =	Path(self.pocConfig['Xilinx.Vivado']['InstallationDirectory']) / "data/vhdl/src"
		vivadoVersion =															self.pocConfig['Xilinx.Vivado']['Version']
		
		# create a VivadoSimulator instance
		simulator = VivadoSimulator.Simulator(self, showLogs, showReport, guiMode)
		# prepare the simulator
		vivadoBinaryPath =	self.Directories["VivadoBinary"]
		simulator.PrepareSimulator(vivadoBinaryPath, vivadoVersion)
		
		# run a testbench
		entityToSimulate = Entity(self, module)
		if (boardString is not None):
			boardName =		boardString
			deviceName =	None
		elif (deviceString is not None):
			boardName =		"Custom"
			deviceName =	deviceString
		else:
			boardName =		"Custom"
			deviceName =	"Unknown"
		
		simulator.Run(entityToSimulate, boardName=boardName, deviceName=deviceName, vhdlVersion=vhdlVersion, vhdlGenerics=None)

# main program
def main():
	colorama_init()

	# print(Foreground.MAGENTA + "=" * 80)
	print(Foreground.LIGHTMAGENTA_EX + "=" * 80)
	print("{: ^80s}".format(Testbench.headLine))
	print("=" * 80)
	print(Foreground.RESET)
	
	try:
		# create a commandline argument parser
		argParser = ArgumentParser(
			formatter_class = RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC-Library Testbench Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																							help='enable script wrapper debug mode',	action='store_const', const=True, default=False)
		group1.add_argument('-d',														dest="debug",				help='enable debug mode',									action='store_const', const=True, default=False)
		group1.add_argument('-v',														dest="verbose",			help='print out detailed messages',				action='store_const', const=True, default=False)
		group1.add_argument('-q',														dest="quiet",				help='run in quiet mode',									action='store_const', const=True, default=False)
		group1.add_argument('-r',														dest="showReport",	help='show report',												action='store_const', const=True, default=False)
		group1.add_argument('-l',														dest="showLog",			help='show logs',													action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',								dest="help",				help='show this help message and exit',		action='store_const', const=True, default=False)
		group211 = group21.add_mutually_exclusive_group()
		group211.add_argument('--list',	metavar="<Entity>",	dest="list",				help='list available testbenches')
		group211.add_argument('--asim',	metavar="<Entity>",	dest="asim",				help='use Aldec Simulator (asim)')
		group211.add_argument('--ghdl',	metavar="<Entity>",	dest="ghdl",				help='use GHDL Simulator (ghdl)')
		group211.add_argument('--vsim',	metavar="<Entity>",	dest="vsim",				help='use Mentor Graphics Simulator (vsim)')
		group211.add_argument('--isim',	metavar="<Entity>",	dest="isim",				help='use Xilinx ISE Simulator (isim)')
		group211.add_argument('--xsim',	metavar="<Entity>",	dest="xsim",				help='use Xilinx Vivado Simulator (xsim)')
		group3 = group211.add_argument_group('Specify target platform')
		group31 = group3.add_mutually_exclusive_group()
		group31.add_argument('--device',				metavar="<Device>",	dest="device",			help='target device (e.g. XC5VLX50T-1FF1136)')
		group31.add_argument('--board',					metavar="<Board>",	dest="board",				help='target board to infere the device (e.g. ML505)')
		group4 = argParser.add_argument_group('Options')
		group4.add_argument('--std',	metavar="<version>",	dest="std",					help='set VHDL standard [87,93,02,08]; default=93')
#		group4.add_argument('-i', '--interactive',					dest="interactive",	help='start simulation in interactive mode',	action='store_const', const=True, default=False)
		group4.add_argument('-g', '--gui',									dest="gui",					help='start simulation in gui mode',					action='store_const', const=True, default=False)

		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		Exit.printException(ex)

	# create class instance and start processing
	try:
		test = Testbench(args.debug, args.verbose, args.quiet)
		
		if (args.help == True):
			argParser.print_help()
			print()
			return
		elif (args.list is not None):
			test.listSimulations(args.list)
		elif (args.asim is not None):
			if ((args.std is not None) and (args.std in ["87", "93", "02", "08"])):
				vhdlVersion =	args.std
			else:
				vhdlVersion =	"93"
			
			aSimGUIMode =			args.gui
			
			test.aSimSimulation(args.asim, args.showLog, args.showReport, vhdlVersion, aSimGUIMode, deviceString=args.device, boardString=args.board)
		elif (args.ghdl is not None):
			if ((args.std is not None) and (args.std in ["87", "93", "02", "08"])):
				vhdlVersion =	args.std
			else:
				vhdlVersion =	"93"
			
			ghdlGUIMode =			args.gui
			
			test.ghdlSimulation(args.ghdl, args.showLog, args.showReport, vhdlVersion, ghdlGUIMode, deviceString=args.device, boardString=args.board)
		elif (args.isim is not None):
			iSimGUIMode =			args.gui
			
			test.iSimSimulation(args.isim, args.showLog, args.showReport, iSimGUIMode, deviceString=args.device, boardString=args.board)
		elif (args.vsim is not None):
			if ((args.std is not None) and (args.std in ["87", "93", "02", "08"])):
				vhdlVersion =	args.std
			else:
				vhdlVersion =	"93"
			
			vSimGUIMode =			args.gui
			
			test.vSimSimulation(args.vsim, args.showLog, args.showReport, vhdlVersion, vSimGUIMode, deviceString=args.device, boardString=args.board)
		elif (args.xsim is not None):
			if ((args.std is not None) and (args.std in ["93", "08"])):
				vhdlVersion =	args.std
			else:
				vhdlVersion =	"93"
			xSimGUIMode =			args.gui
			
			test.xSimSimulation(args.xsim, args.showLog, args.showReport, vhdlVersion, xSimGUIMode, deviceString=args.device, boardString=args.board)
		else:
			argParser.print_help()
	
	except SimulatorException as ex:
		print(Foreground.RED + "ERROR:" + Foreground.RESET + " {0}".format(ex.message))
		if isinstance(ex.__cause__, FileNotFoundError):
			print("{0}  FileNotFound:{1} '{2}'".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
		elif isinstance(ex.__cause__, ParserException):
			print("{0}  ParserException:{1} {2}".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
			if (ex.__cause__.__cause__ is not None):
				print("{0}    {1}:{2} {3}".format(Foreground.LIGHTYELLOW_EX, ex.__cause__.__cause__.__class__.__name__, Foreground.RESET, str(ex.__cause__.__cause__)))
		elif isinstance(ex.__cause__, ConfigParser_Error):
			print("{0}  configparser.Error:{1} '{2}'".format(Foreground.LIGHTYELLOW_EX, Foreground.RESET, str(ex.__cause__)))
		print(Foreground.RESET + Back.RESET + Style.RESET_ALL)
		exit(1)

	except EnvironmentException as ex:					Exit.printEnvironmentException(ex)
	except NotConfiguredException as ex:				Exit.printNotConfiguredException(ex)
	except PlatformNotSupportedException as ex:	Exit.printPlatformNotSupportedException(ex)
	except BaseException as ex:									Exit.printBaseException(ex)
	except NotImplementedException as ex:				Exit.printNotImplementedException(ex)
	except Exception as ex:											Exit.printException(ex)
			
# entry point
if __name__ == "__main__":
	Exit.versionCheck((3,4,0))
	main()
else:
	Exit.printThisIsNoLibraryFile(Testbench.headLine)
