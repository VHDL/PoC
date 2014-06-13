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

from pathlib import Path

import PoC
import PoCCompiler
import PoCXCOCompiler
#import PoCXSTCompiler


class PoCNetList(PoC.PoCBase):
	__netListConfigFileName = "configuration.ini"
	dryRun = False
	netListConfig = None
	
	def __init__(self, debug, verbose, quiet):
		super(self.__class__, self).__init__(debug, verbose, quiet)

		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
		self.readNetListConfiguration()
		
	# read NetList configuration
	# ==========================================================================
	def readNetListConfiguration(self):
		import configparser
		
		netListConfigFilePath = self.Directories["Root"] / ".." / self.pocStructure['DirectoryNames']['NetListFiles'] / self.__netListConfigFileName
		self.printDebug("Reading NetList configuration from '%s'" % str(netListConfigFilePath))
		if not netListConfigFilePath.exists():
			raise PoCNotConfiguredException("PoC netlist configuration file does not exist. (%s)" % str(netListConfigFilePath))
			
		self.netListConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.netListConfig.optionxform = str
		self.netListConfig.read([str(self.Files["PoCConfig"]), str(self.Files["PoCStructure"]), str(netListConfigFilePath)])
		self.Files["PoCNLConfig"]	= netListConfigFilePath

	def coreGenCompilation(self, entity, showLogs, showReport, device=None, board=None):
		# check if ISE is configure
		if (len(self.pocConfig.options("Xilinx-ISE")) == 0):
			raise PoCNotConfiguredException("Xilinx ISE is not configured on this system.")
		
		# prepare some paths
		self.Directories["ISEInstallation"] = Path(self.pocConfig['Xilinx-ISE']['InstallationDirectory'])
		self.Directories["ISEBinary"] =				Path(self.pocConfig['Xilinx-ISE']['BinaryDirectory'])
	
		# check if the appropriate environment is loaded
		from os import environ
		if (environ.get('XILINX') == None):
			raise PoC.PoCEnvironmentException("Xilinx ISE environment is not loaded in this shell environment. ")

		deviceString = ""
		if (board is not None):
			deviceString = self.netListConfig['BOARDS'][board]
		elif (device is not None):
			deviceString = device
		
		entityToCompile = PoC.PoCEntity(self, entity)

		compiler = PoCXCOCompiler.PoCXCOCompiler(self, showLogs, showReport)
		compiler.dryRun = self.dryRun
		compiler.run(entityToCompile, deviceString)


# main program
def main():
	print("========================================================================")
	print("                  PoC Library - NetList Service Tool                    ")
	print("========================================================================")
	print()
	
	try:
		import argparse
		import textwrap
		
		# create a command line argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library NetList Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																											help='enable script wrapper debug mode',	action='store_const', const=True, default=False)
		group1.add_argument('-d',																		dest="debug",				help='enable debug mode',									action='store_const', const=True, default=False)
		group1.add_argument('-v',																		dest="verbose",			help='print out detailed messages',				action='store_const', const=True, default=False)
		group1.add_argument('-q',																		dest="quiet",				help='run in quiet mode',									action='store_const', const=True, default=False)
		group1.add_argument('-r',																		dest="showReport",	help='show report',												action='store_const', const=True, default=False)
		group1.add_argument('-l',																		dest="showLog",			help='show logs',													action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',												dest="help",				help='show this help message and exit',		action='store_const', const=True, default=False)
		group21.add_argument('-c', '--coregen',	metavar="<Entity>",	dest="coreGen",			help='use Xilinx IP-Core Generator (CoreGen)')
		group21.add_argument('-x', '--xst',			metavar="<Entity>",	dest="xst",					help='use Xilinx Synthesis Tool (XST)')
		group3 = argParser.add_argument_group('Specify target platform')
		group31 = group3.add_mutually_exclusive_group(required=True)
		group31.add_argument('--device',				metavar="<Device>",	dest="device",			help='target device (e.g. XC5VLX50T-1FF1136)')
		group31.add_argument('--board',					metavar="<Board>",	dest="board",				help='target board to infere the device (e.g. ML505)')

		# parse command line options
		args = argParser.parse_args()
		
	except Exception as ex:
		print("FATAL: %s" % ex.__str__())
		print()
		return

		
	try:
		netList = PoCNetList(args.debug, args.verbose, args.quiet)
		#netList.dryRun = True
	
		if (args.help == True):
			argParser.print_help()
			return
		elif (args.coreGen is not None):
			netList.coreGenCompilation(args.coreGen, args.showLog, args.showReport, device=args.device, board=args.board)
		elif (args.xst is not None):
			raise PoC.NotImplementedException("XST workflow is not yet implemented!")
			#netList.coreGenCompilation(args.coreGen, args.showLog, args.showReport, device=args.device, board=args.board)
		else:
			argParser.print_help()
		
	except PoCCompiler.PoCCompilerException as ex:
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

#	except Exception as ex:
#		print("FATAL: %s" % ex.__str__())
#		print()
#		return
			
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
	print("                  PoC Library - NetList Service Tool                    ")
	print("========================================================================")
	print()
	print("This is no library file!")
	exit(1)