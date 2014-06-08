# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Main Module:  Entry point to the testbench tools in PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - runs automated testbenches,
#    - ...
#
# License:
# ==============================================================================
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

import PoC
import PoCSimulator
import PoCISESimulator

from pathlib import Path

import os

import shutil
import string

import sys


class PoCTestbench(PoC.PoCBase):
	__tbConfigFileName = "configuration.ini"
	tbConfig = None
	
	def __init__(self, debug, verbose):
		super(self.__class__, self).__init__(debug, verbose)

		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
		self.readTestbenchConfiguration()
		
	# read Testbench configuration	
	def readTestbenchConfiguration(self):
		import configparser
	
		# read Simulation configuration
		# ==========================================================================
		tbConfigFilePath = self.Directories["Root"] / ".." / self.pocStructure['DirectoryNames']['TestbenchFiles'] / self.__tbConfigFileName
		self.printDebug("Reading testbench configuration from '%s'" % str(tbConfigFilePath))
		if not tbConfigFilePath.exists():
			raise PoC.PoCNotConfiguredException("PoC testbench configuration file does not exist. (%s)" % str(tbConfigFilePath))
			
		self.tbConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.tbConfig.optionxform = str
		self.tbConfig.read([str(self.Files["PoCConfig"]), str(self.Files["PoCStructure"]), str(tbConfigFilePath)])
		self.Files["PoCTBConfig"]	= tbConfigFilePath
	
	def isimSimulation(self, module, showLogs):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx-ISE")) == 0):
			raise PoCNotConfiguredException("Xilinx ISE is not configured on this system.")
		
		# prepare some paths
		self.Directories["ISEInstallation"] = Path(self.pocConfig['Xilinx-ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] = Path(self.pocConfig['Xilinx-ISE']['BinaryDirectory'])
		
		# check if the appropriate environment is loaded
		from os import environ
		if (environ.get('XILINX') == None):
			raise PoC.PoCEnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")
#			settingsFilePath = self.Directories["ISEInstallation"]
#			if (self.platform == "Windows"):		settingsFilePath /= "settings64.bat"
#			elif (self.platform == "Linux"):		settingsFilePath /= "settings64.sh"

		entityToSimulate = PoC.PoCEntity(self, module)

		simulator = PoCISESimulator.PoCISESimulator(self, showLogs)
	
		simulator.run(entityToSimulate)


	def getNamespaceForPrefix(self, namespacePrefix):
		return self.tbConfig['NamespacePrefixes'][namespacePrefix]
	
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
				'''))

		# add arguments
		argParser.add_argument('-D', action='store_const', const=True, default=False, help='enable script wrapper debug mode')
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('-l', action='store_const', const=True, default=False, help='show logs')
		argParser.add_argument('--isim', action='store_const', const=True, default=False, help='use Xilinx ISE Simulator (iSim)')
		argParser.add_argument('--xsim', action='store_const', const=True, default=False, help='use Xilinx Vivado Simulator (xSim)')
		argParser.add_argument('--vsim', action='store_const', const=True, default=False, help='use Mentor Graphics ModelSim (vSim)')
		argParser.add_argument('--ghdl', action='store_const', const=True, default=False, help='use GHDL Simulator (ghdl)')
		argParser.add_argument("module", help="Specify the module which should be tested.")
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("FATAL: %s" % ex.__str__())
		print()
		return

	# create class instance and start processing
	try:
		test = PoCTestbench(args.d, args.v)
		
		if args.isim:
			test.isimSimulation(args.module, args.l)
		elif args.vsim:
			test.vsimSimulation(args.module, args.l)
		elif args.ghdl:
			test.ghdlSimulation(args.module, args.l)
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
		print("FATAL: %s" % ex.__str__())
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
	
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	print("This is no library file!")
	exit(1)
