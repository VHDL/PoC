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
#import os
#import pathlib
#import platform
#import re
#import string
import sys

#import shutil
#import subprocess

class PoCNetList(PoCBase.PoCBase):
	__netListConfigFileName = "configuration.ini"
	__netListConfig = None
	
	def __init__(self, debug, verbose):
		super(self.__class__, self).__init__(debug, verbose)

		self.readNetListConfiguration()
		
	# read NetList configuration	
	def readNetListConfiguration(self):
		import configparser
		
		netListConfigFilePath = self.Directories["Root"] / ".." / self.pocStructure['DirectoryNames']['NetListFiles'] / self.__netListConfigFileName
		self.printDebug("Reading netList configuration from '%s'" % str(netListConfigFilePath))
		if not netListConfigFilePath.exists():
			raise PoCNotConfiguredException("PoC netlist configuration file does not exist. (%s)" % str(netListConfigFilePath))
			
		self.__netListConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.__netListConfig.optionxform = str
		self.__netListConfig.read([str(netListConfigFilePath)])
		

	
# main program
def main():
	print("========================================================================")
	print("                  PoC Library - NetList Service Tool                    ")
	print("========================================================================")
	print()
	
	if (sys.version_info<(3,4,0)):
		print("ERROR: Used Python interpreter is to old: %s" % sys.version)
		print("Minimal required Python version is 3.4.0")
		return
	
	try:
		import argparse
		import textwrap
		
		# create a command line argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library NetList Service Tool.
				'''))

		# add arguments
		argParser.add_argument('-D', action='store_const', const=True, default=False, help='enable script wrapper debug mode')
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('-l', action='store_const', const=True, default=False, help='show logs')
		argParser.add_argument('--coregen', action='store_const', const=True, default=False, help='use Xilinx IP-Core Generator (CoreGen)')
		argParser.add_argument("module", help="Specify the module which should be tested.")
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("Exception: %s" % ex.__str__())

		
	try:
		netlist = PoCNetList(args.d, args.v)
	
		if args.coregen:
			pass
	#		netList.runCoreGenerator(args.module, args.l)
		else:
			argParser.print_help()
	except PoCBase.PoCNotConfiguredException as ex:
		print("ERROR: %s" % ex.message)
		print()
		print("Please run 'poc.[sh/cmd] --configure' in PoC root directory.")
		return
			
# entry point
if __name__ == "__main__":
	main()
else:
	from sys import exit
	
	print("========================================================================")
	print("                  PoC Library - NetList Service Tool                    ")
	print("========================================================================")
	print()
	print("This is no library file!")
	exit(1)