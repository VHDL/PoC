# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Executable:	Entry point to the testbench tools in PoC repository.
# 
# Authors:				 		Patrick Lehmann
# 
# Description:
# ------------------------------------
#	This is a python main module (executable) which:
#		- runs automated testbenches,
#		- ...
#
# License:
# ==============================================================================
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

from pathlib import Path

import PoC
import PoCSimulator
import PoCISESimulator
import PoCVivadoSimulator
import PoCQuestaSimulator
import PoCGHDLSimulator


class PoCTestbench(PoC.PoCBase):
	__tbConfigFileName = "configuration.ini"
	tbConfig = None
	
	def __init__(self, debug, verbose, quiet):
		super(self.__class__, self).__init__(debug, verbose, quiet)

		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
		self.readTestbenchConfiguration()
		
	# read Testbench configuration
	# ==========================================================================
	def readTestbenchConfiguration(self):
		from configparser import ConfigParser, ExtendedInterpolation
	
		self.files["PoCTBConfig"] = self.directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['TestbenchFiles'] / self.__tbConfigFileName
		tbConfigFilePath = self.files["PoCTBConfig"]
		
		self.printDebug("Reading testbench configuration from '%s'" % str(tbConfigFilePath))
		if not tbConfigFilePath.exists():
			raise PoC.PoCNotConfiguredException("PoC testbench configuration file does not exist. (%s)" % str(tbConfigFilePath))
			
		self.tbConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.tbConfig.optionxform = str
		self.tbConfig.read([str(self.files["PoCPrivateConfig"]), str(self.files["PoCPublicConfig"]), str(tbConfigFilePath)])
	
	def listSimulations(self, module):
		entityToList = PoC.PoCEntity(self, module)
		
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
	
	def isimSimulation(self, module, showLogs, showReport):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx-ISE")) == 0):
			raise PoCNotConfiguredException("Xilinx ISE is not configured on this system.")
		
		# prepare some paths
		self.directories["ISEInstallation"] = Path(self.pocConfig['Xilinx-ISE']['InstallationDirectory'])
		self.directories["ISEBinary"] =				Path(self.pocConfig['Xilinx-ISE']['BinaryDirectory'])
		
		# check if the appropriate environment is loaded
		from os import environ
		if (environ.get('XILINX') == None):
			raise PoC.PoCEnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCISESimulator.PoCISESimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)

	def xsimSimulation(self, module, showLogs, showReport):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx-Vivado")) == 0):
			raise PoCNotConfiguredException("Xilinx Vivado is not configured on this system.")

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCVivadoSimulator.PoCVivadoSimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)

	def vsimSimulation(self, module, showLogs, showReport):
		# check if ISE is configure
		if (len(self.pocConfig.options("Questa")) == 0):
			raise PoCNotConfiguredException("Mentor Graphics Questa is not configured on this system.")

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCQuestaSimulator.PoCQuestaSimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)
		
	def ghdlSimulation(self, module, showLogs, showReport):
		# check if GHDL is configure
		if (len(self.pocConfig.options("GHDL")) == 0):
			raise PoCNotConfiguredException("GHDL is not configured on this system.")
		
		# prepare some paths
		self.directories["GHDLInstallation"] =	Path(self.pocConfig['GHDL']['InstallationDirectory'])
		self.directories["GHDLBinary"] =				Path(self.pocConfig['GHDL']['BinaryDirectory'])
		
		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCGHDLSimulator.PoCGHDLSimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)

	def xsimSimulation(self, module, showLogs, showReport):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx-Vivado")) == 0):
			raise PoCNotConfiguredException("Xilinx Vivado is not configured on this system.")

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCVivadoSimulator.PoCVivadoSimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)
	
	
		# check if ISE is configure
		if (len(self.pocConfig.options("GHDL")) == 0):
			raise PoCNotConfiguredException("GHDL is not configured on this system.")

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCGHDLSimulator.PoCGHDLSimulator(self, showLogs, showReport)
		simulator.run(entityToSimulate)
		

# main program
def main():
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	
	try:
		import argparse
		import textwrap
		
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Testbench Service Tool.
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
		group21.add_argument('--list',	metavar="<Entity>",	dest="list",				help='list available testbenches')
		group21.add_argument('--isim',	metavar="<Entity>",	dest="isim",				help='use Xilinx ISE Simulator (isim)')
		group21.add_argument('--xsim',	metavar="<Entity>",	dest="xsim",				help='use Xilinx Vivado Simulator (xsim)')
		group21.add_argument('--vsim',	metavar="<Entity>",	dest="vsim",				help='use Mentor Graphics Simulator (vsim)')
		group21.add_argument('--ghdl',	metavar="<Entity>",	dest="ghdl",				help='use GHDL Simulator (ghdl)')

		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		from traceback import print_tb
		print("FATAL: %s" % ex.__str__())
		print("-" * 80)
		print_tb(ex.__traceback__)
		print("-" * 80)
		print()
		return

	# create class instance and start processing
	try:
		test = PoCTestbench(args.debug, args.verbose, args.quiet)
		
		if (args.help == True):
			argParser.print_help()
			return
		elif (args.list is not None):
			test.listSimulations(args.list)
		elif (args.isim is not None):
			test.isimSimulation(args.isim, args.showLog, args.showReport)
		elif (args.xsim is not None):
			test.xsimSimulation(args.xsim, args.showLog, args.showReport)
		elif (args.vsim is not None):
			test.vsimSimulation(args.vsim, args.showLog, args.showReport)
		elif (args.ghdl is not None):
			test.ghdlSimulation(args.ghdl, args.showLog, args.showReport)
		else:
			argParser.print_help()
	
	except PoCSimulator.PoCSimulatorException as ex:
		print("ERROR: %s" % ex.message)
		print()
		return
		
	except PoC.PoCEnvironmentException as ex:
		print("ERROR: %s" % ex.message)
		print()
		print("Please run this script with it's provided wrapper or manually load the required environment before executing this script.")
		return
	
	except PoC.PoCNotConfiguredException as ex:
		print("ERROR: %s" % ex.message)
		print()
		print("Please run 'poc.[sh/cmd] --configure' in PoC root directory.")
		return
	
	except PoC.PoCPlatformNotSupportedException as ex:
		print("ERROR: Unknown platform '%s'" % ex.message)
		print()
		return
	
	except PoC.PoCException as ex:
		print("ERROR: %s" % ex.message)
		print()
		return
	
	except PoC.NotImplementedException as ex:
		print("ERROR: %s" % ex.message)
		print()
		return

	except Exception as ex:
		from traceback import print_tb
		print("FATAL: %s" % ex.__str__())
		print("-" * 80)
		print_tb(ex.__traceback__)
		print("-" * 80)
		print()
		return
	
# entry point
if __name__ == "__main__":
	from sys import version_info
	
	if (version_info<(3,4,0)):
		print("ERROR: Used Python interpreter is to old: %s" % version_info)
		print("Minimal required Python version is 3.4.0")
		exit(1)
			
	main()
else:
	from sys import exit
	
	print("=" * 80)
	print("{: ^80s}".format("PoC Library - Testbench Service Tool"))
	print("=" * 80)
	print()
	print("This is no library file!")
	exit(1)
