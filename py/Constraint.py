# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Main Module:  Entry point to the constraint tools in PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - generates constraint files,
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
from libFunctions import Exit
import PoCConstraintGenerator
import PoCUCFGenerator
import PoCXDCGenerator


class PoCConstraint(PoC.PoCBase):
	__constraintConfigFileName = "configuration.ini"
	
	headLine = "PoC Library - Constraint Service Tool"
	
	dryRun = False
	constraintConfig = None
	
	def __init__(self, debug, verbose, quiet):
		super(self.__class__, self).__init__(debug, verbose, quiet)

		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
		self.readconstraintConfiguration()
		
	# read constraint configuration
	# ==========================================================================
	def readconstraintConfiguration(self):
		from configparser import ConfigParser, ExtendedInterpolation
		
		self.files["PoCNLConfig"] = self.directories["PoCconstraint"] / self.__constraintConfigFileName
		constraintConfigFilePath	= self.files["PoCNLConfig"]
		
		self.printDebug("Reading constraint configuration from '%s'" % str(constraintConfigFilePath))
		if not constraintConfigFilePath.exists():
			raise PoCNotConfiguredException("PoC constraint configuration file does not exist. (%s)" % str(constraintConfigFilePath))
			
		self.constraintConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.constraintConfig.optionxform = str
		self.constraintConfig.read([str(self.files['PoCPrivateConfig']), str(self.files['PoCPublicConfig']), str(self.files["PoCNLConfig"])])

	def ucfGeneration(self, ucfFile):
		
		entityToCompile = PoC.PoCEntity(self, entity)

		compiler = PoCXSTCompiler.PoCXSTCompiler(self, showLogs, showReport)
		compiler.dryRun = self.dryRun
		compiler.run(entityToCompile, device)


# main program
def main():
	print("=" * 80)
	print("{: ^80s}".format(PoCConstraint.headLine))
	print("=" * 80)
	print()
	
	try:
		import argparse
		import textwrap
		
		# create a command line argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library constraint Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																											help='enable script wrapper debug mode',	action='store_const', const=True, default=False)
		group1.add_argument('-d',																		dest="debug",				help='enable debug mode',									action='store_const', const=True, default=False)
		group1.add_argument('-v',																		dest="verbose",			help='print out detailed messages',				action='store_const', const=True, default=False)
		group1.add_argument('-q',																		dest="quiet",				help='run in quiet mode',									action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',												dest="help",				help='show this help message and exit',		action='store_const', const=True, default=False)
		group211 = group21.add_mutually_exclusive_group()
		group211.add_argument(		 '--ucf',			metavar="<UCF File>",	dest="ucf",				help='generate User Constraint File (*.ucf)')

		# parse command line options
		args = argParser.parse_args()
		
	except Exception as ex:
		Exit.printException(ex)
		
	try:
		constraint = PoCConstraint(args.debug, args.verbose, args.quiet)
		#constraint.dryRun = True
	
		if (args.help == True):
			argParser.print_help()
			return
		elif (args.ucf is not None):
			constraint.ucfGeneration(args.ucf)
		else:
			argParser.print_help()
		
	except PoCCompiler.PoCCompilerException as ex:			Exit.printPoCException(ex)
	except PoC.PoCEnvironmentException as ex:						Exit.printPoCEnvironmentException(ex)
	except PoC.PoCNotConfiguredException as ex:					Exit.printPoCNotConfiguredException(ex)
	except PoC.PoCPlatformNotSupportedException as ex:	Exit.printPoCPlatformNotSupportedException(ex)
	except PoC.PoCException as ex:											Exit.printPoCException(ex)
	except PoC.NotImplementedException as ex:						Exit.printNotImplementedException(ex)
	except Exception as ex:															Exit.printException(ex)
			
# entry point
if __name__ == "__main__":
	Exit.VersionCheck((3,4,0))
	main()
else:
	Exit.ThisIsNoLibraryFile(PoCTool_HeadLine)
	