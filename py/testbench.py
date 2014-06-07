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

import PoCBase
import PoCSimulator
import PoCISESimulator

import argparse
import configparser
import os
import pathlib
import platform
import re
import shutil
import string
import subprocess
import sys
import textwrap

class PoCTestbench(PoCBase.PoCBase):
	import configparser
	import shutil
	import subprocess
	
	__tbConfigFileName = "configuration.ini"
	__tbConfig = None
	
	def __init__(self, debug, verbose):
	def __init__(self, debug, verbose):
		super(self.__class__, self).__init__(debug, verbose)

		self.readTestbenchConfiguration()
		
	# read Testbench configuration	
	def readTestbenchConfiguration(self):
		# read Simulation configuration
		# ==========================================================================
		tbConfigFilePath = Directories["Root"] / ".." / self.pocStructure['DirectoryNames']['TestbenchFiles'] / self.__tbConfigFileName
		self.printDebug("Reading testbench configuration from '%s'" % str(tbConfigFilePath))
		if not tbConfigFilePath.exists():
			raise PoCNotConfiguredException("PoC testbench configuration file does not exist. (%s)" % str(tbConfigFilePath))
			
		self.__tbConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__tbConfig.optionxform = str
		self.__tbConfig.read([str(pocConfigFilePath), str(pocStructureFilePath), str(tbConfigFilePath)])
	
	

	


	def getNamespaceForPrefix(self, namespacePrefix):
		return self.__tbConfig['NamespacePrefixes'][namespacePrefix]
	
# main program
def main():
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	
	if (sys.version_info<(3,4,0)):
		print("ERROR: Used Python interpreter is to old: %s" % sys.version)
		print("Minimal required Python version is 3.4.0")
		return
	
	try:
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
		print("Exception: %s" % ex.__str__())

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
		
	except PoCBase.PoCNotConfiguredException as ex:
		print("ERROR: %s" % ex.message)
		print()
		print("Please run 'poc.[sh/cmd] --configure' in PoC root directory.")
		return
	
	except PoCSimulator.PoCSimulatorException as ex:
		print("ERROR: %s" % ex.message)
		print()
		return
	
# entry point
if __name__ == "__main__":
	main()
else:
	print("========================================================================")
	print("                  PoC Library - Testbench Service Tool                  ")
	print("========================================================================")
	print()
	print("This is no library file!")
