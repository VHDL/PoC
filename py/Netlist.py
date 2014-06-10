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
	netListConfig = None
	
	def __init__(self, debug, verbose, quite):
		super(self.__class__, self).__init__(debug, verbose, quite)

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

	def coreGenCompilation(self, module, device, showLogs, showReport):
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

		entityToCompile = PoC.PoCEntity(self, module)

		compiler = PoCXCOCompiler.PoCXCOCompiler(self, showLogs, showReport)
		compiler.run(entityToCompile, device)


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
				'''))

		# add arguments
		argParser.add_argument('-D', action='store_const', const=True, default=False, help='enable script wrapper debug mode')
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('-q', action='store_const', const=True, default=False, help='run in quite mode')
		argParser.add_argument('-l', action='store_const', const=True, default=False, help='show logs')
		argParser.add_argument('-r', action='store_const', const=True, default=False, help='show report')
		argParser.add_argument('--coregen', action='store_const', const=True, default=False, help='use Xilinx IP-Core Generator (CoreGen)')
		argParser.add_argument("module", help="Specify the module which should be tested.")
		argParser.add_argument('--device', action='store_const', const=True, default=False, help='target device')
		argParser.add_argument("devicename", help="Specify the target device.")
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("FATAL: %s" % ex.__str__())
		print()
		return

		
	try:
		netList = PoCNetList(args.d, args.v, args.q)
	
		if args.coregen:
			netList.coreGenCompilation(args.module, args.devicename, args.l, args.r)
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