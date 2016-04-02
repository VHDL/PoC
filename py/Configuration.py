# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:         		 Patrick Lehmann
# 
# Python Main Module:  Entry point to configure the local copy of this PoC repository.
# 
# Description:
# ------------------------------------
#		This is a python main module (executable) which:
#		- configures the PoC Library to your local environment,
#		- return the paths to tool chain files (e.g. ISE settings file)
#		- ...
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

from pathlib					import Path
from configparser			import ConfigParser, ExtendedInterpolation

from lib.Functions		import Exit
from Base.Exceptions	import *
from Base.Logging			import Logger, Severity
from Base.PoCBase			import CommandLineProgram
from collections			import OrderedDict


class Configuration(CommandLineProgram):
	headLine = "The PoC-Library - Repository Service Tool"
	
	__privateSections = [
		"PoC",
		"Aldec", "Aldec.ActiveHDL", "Aldec.RivieraPRO",
		"Altera", "Altera.QuartusII", "Altera.ModelSim",
		"GHDL", "GTKWave",
		"Lattice", "Lattice.Diamond", "Lattice.ActiveHDL", "Lattice.Symplify",
		"Mentor", "Mentor.QuestaSIM",
		"Xilinx", "Xilinx.ISE", "Xilinx.LabTools", "Xilinx.Vivado", "Xilinx.HardwareServer",
		"Solutions"
	]
	__privatePoCOptions = ["Version", "InstallationDirectory"]
	
	def __init__(self, debug, verbose, quiet):
		if quiet:			severity = Severity.Quiet
		elif debug:		severity = Severity.Debug
		elif verbose:	severity = Severity.Verbose
		else:					severity = Severity.Normal
		
		logger =			Logger(self, severity, printToStdOut=True)
		try:
			super(self.__class__, self).__init__(logger=logger)

			if		(self.Platform == "Windows"):	pass
			elif	(self.Platform == "Linux"):		pass
			else:																						raise PlatformNotSupportedException(self.Platform)
		
		except NotConfiguredException as ex:
			self._LogVerbose("Configuration file does not exists; creating a new one")
			
			self.pocConfig = ConfigParser(interpolation=ExtendedInterpolation())
			self.pocConfig.optionxform = str
			self.pocConfig['PoC'] = OrderedDict()
			self.pocConfig['PoC']['Version'] = '0.0.0'
			self.pocConfig['PoC']['InstallationDirectory'] = self.directories['PoCRoot'].as_posix()

			self.pocConfig['Aldec'] =									OrderedDict()
			self.pocConfig['Aldec.ActiveHDL'] =				OrderedDict()
			self.pocConfig['Aldec.RivieraPRO'] =			OrderedDict()
			self.pocConfig['Altera'] =								OrderedDict()
			self.pocConfig['Altera.QuartusII'] =			OrderedDict()
			self.pocConfig['Altera.ModelSim'] =				OrderedDict()
			self.pocConfig['Lattice'] =								OrderedDict()
			self.pocConfig['Lattice.Diamond'] =				OrderedDict()
			self.pocConfig['Lattice.ActiveHDL'] =			OrderedDict()
			self.pocConfig['Lattice.Symplify'] =			OrderedDict()
			self.pocConfig['GHDL'] =									OrderedDict()
			self.pocConfig['GTKWave'] =								OrderedDict()
			self.pocConfig['Mentor'] =								OrderedDict()
			self.pocConfig['Mentor.QuestaSIM'] =			OrderedDict()
			self.pocConfig['Xilinx'] =								OrderedDict()
			self.pocConfig['Xilinx.ISE'] =						OrderedDict()
			self.pocConfig['Xilinx.LabTools'] =				OrderedDict()
			self.pocConfig['Xilinx.Vivado'] =					OrderedDict()
			self.pocConfig['Xilinx.HardwareServer'] =	OrderedDict()
			self.pocConfig['Solutions'] =							OrderedDict()

			# Writing configuration to disc
			with self.files['PoCPrivateConfig'].open('w') as configFileHandle:
				self.pocConfig.write(configFileHandle)
			
			self._LogDebug("New configuration file created: %s" % self.files['PoCPrivateConfig'])
			
			# re-read configuration
			self.__ReadPoCConfiguration()
	
	def autoConfiguration(self):
		raise NotImplementedException("No automatic configuration available!")
	
	def manualConfiguration(self):
		self._LogConfigurationHelp()
		
		# configure Windows
		if (self.Platform == 'Windows'):
			# configure QuartusII on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsQuartusII()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure ISE on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsISE()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure LabTools on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsLabTools()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure Vivado on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsVivado()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure HardwareServer on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsHardwareServer()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
				
			# configure Mentor QuestaSIM on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsQuestaSim()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
				
			# configure GHDL on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsGHDL()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
				
			# configure GTKWave on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsGTKW()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
				
		# configure Linux
		elif (self.Platform == 'Linux'):
			# configure QuartusII on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxQuartusII()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure ISE on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxISE()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure LabTools on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxLabTools()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure Vivado on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxVivado()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure HardwareServer on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxHardwareServer()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure Mentor QuestaSIM on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxQuestaSim()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure GHDL on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxGHDL()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
			
			# configure GTKWave on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxGTKW()
					next = True
				except BaseException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise
		else:
			raise PlatformNotSupportedException(self.Platform)
	
		# write configuration
		self.writePoCConfiguration()
		# re-read configuration
		self.readPoCConfiguration()
	
	def printConfigurationHelp(self):
		self._LogVerbose("starting manual configuration...")
		print('Explanation of abbreviations:')
		print('  y - yes')
		print('  n - no')
		print('  p - pass (jump to next question)')
		print('Upper case means default value')
		print()
	
	def newSolution(self, solutionName):
		print("new solution: name=%s" % solutionName)
		print("solution here: %s" % self.directories['Working'])
		print("script root: %s" % self.directories['ScriptRoot'])
	
		raise NotImplementedException("Currently new solution should be created by hand.")
	
	def addSolution(self, solutionName):
		print("Adding existing solution '%s' to PoC Library." % solutionName)
		print()
		print("You can specify paths and file names relative to the current working directory")
		print("or as an absolute path.")
		print()
		print("Current working directory: %s" % self.directories['Working'])
		print()
		
		if (not self.pocConfig.has_section('Solutions')):
			self.pocConfig['Solutions'] = OrderedDict()
		
		if self.pocConfig.has_option('Solutions', solutionName):
			raise BaseException("Solution is already registered in PoC Library.")
		
		# 
		solutionFileDirectoryName = input("Where is the solution file 'solution.ini' stored? [./py]: ")
		solutionFileDirectoryName = solutionFileDirectoryName if solutionFileDirectoryName != "" else "py"
	
		solutionFilePath = Path(solutionFileDirectoryName)
	
		if (solutionFilePath.is_absolute()):
			solutionFilePath = solutionFilePath / "solution.ini"
		else:
			solutionFilePath = ((self.directories['Working'] / solutionFilePath).resolve()) / "solution.ini"
			
		if (not solutionFilePath.exists()):
			raise BaseException("Solution file '%s' does not exist." % str(solutionFilePath))
		
		self.pocConfig['Solutions'][solutionName] = solutionFilePath.as_posix()
	
		# write configuration
		self.writePoCConfiguration()
		# re-read configuration
		self.readPoCConfiguration()
	
	def cleanupPoCConfiguration(self):
		# remove non-private sections from pocConfig
		sections = self.pocConfig.sections()
		for privateSection in self.__privateSections:
			sections.remove(privateSection)
		for section in sections:
			self.pocConfig.remove_section(section)
		
		# remove non-private options from [PoC] section
		pocOptions = self.pocConfig.options("PoC")
		for privatePoCOption in self.__privatePoCOptions:
			pocOptions.remove(privatePoCOption)
		for pocOption in pocOptions:
			self.pocConfig.remove_option("PoC", pocOption)
	
	def writePoCConfiguration(self):
		self.cleanupPoCConfiguration()
		
		# Writing configuration to disc
		print("Writing configuration file to '%s'" % str(self.files['PoCPrivateConfig']))
		with self.files['PoCPrivateConfig'].open('w') as configFileHandle:
			self.pocConfig.write(configFileHandle)
	
	def getPoCInstallationDir(self):
		if (len(self.pocConfig.options("PoC")) != 0):
			pocInstallationDirectoryPath = Path(self.pocConfig['PoC']['InstallationDirectory'])
			
			return str(pocInstallationDirectoryPath)
		else:
			raise NotConfiguredException("ERROR: PoC is not configured on this system.")
			
	def getModelSimInstallationDir(self):
		if (len(self.pocConfig.options("Mentor.QuestaSim")) != 0):
			modelSimInstallationDirectoryPath = Path(self.pocConfig['Mentor.QuestaSim']['InstallationDirectory'])
			
		elif (len(self.pocConfig.options("Altera.ModelSim")) != 0):
			modelSimInstallationDirectoryPath = Path(self.pocConfig['Altera.ModelSim']['InstallationDirectory'])
			
		else:
			raise NotConfiguredException("ERROR: ModelSim is not configured on this system.")
		return str(modelSimInstallationDirectoryPath)
			
	def getISESettingsFile(self):
		if (len(self.pocConfig.options("Xilinx.ISE")) != 0):
			iseInstallationDirectoryPath = Path(self.pocConfig['Xilinx.ISE']['InstallationDirectory'])
			
			if		(self.Platform == "Windows"):		return (str(iseInstallationDirectoryPath / "settings64.bat"))
			elif	(self.Platform == "Linux"):			return (str(iseInstallationDirectoryPath / "settings64.sh"))
			else:	raise PlatformNotSupportedException(self.Platform)
		elif (len(self.pocConfig.options("Xilinx.LabTools")) != 0):
			labToolsInstallationDirectoryPath = Path(self.pocConfig['Xilinx.LabTools']['InstallationDirectory'])
			
			if		(self.Platform == "Windows"):		return (str(labToolsInstallationDirectoryPath / "settings64.bat"))
			elif	(self.Platform == "Linux"):			return (str(labToolsInstallationDirectoryPath / "settings64.sh"))
			else:	raise PlatformNotSupportedException(self.Platform)
		else:
			raise NotConfiguredException("ERROR: Xilinx ISE or Xilinx LabTools is not configured on this system.")
			
	def getVivadoSettingsFile(self):
		if (len(self.pocConfig.options("Xilinx.Vivado")) != 0):
			vivadoInstallationDirectoryPath = Path(self.pocConfig['Xilinx.Vivado']['InstallationDirectory'])
			
			if		(self.Platform == "Windows"):		return (str(vivadoInstallationDirectoryPath / "settings64.bat"))
			elif	(self.Platform == "Linux"):			return (str(vivadoInstallationDirectoryPath / "settings64.sh"))
			else:	raise PlatformNotSupportedException(self.Platform)
		elif (len(self.pocConfig.options("Xilinx.HardwareServer")) != 0):
			hardwareServerInstallationDirectoryPath = Path(self.pocConfig['Xilinx.HardwareServer']['InstallationDirectory'])
			
			if		(self.Platform == "Windows"):		return (str(hardwareServerInstallationDirectoryPath / "settings64.bat"))
			elif	(self.Platform == "Linux"):			return (str(hardwareServerInstallationDirectoryPath / "settings64.sh"))
			else:	raise PlatformNotSupportedException(self.Platform)
		else:
			raise NotConfiguredException("ERROR: Xilinx Vivado or Xilinx HardwareServer is not configured on this system.")
	
# main program
def main():
	from sys import exit
	import argparse
	import textwrap
	import colorama
	
	colorama.init()
	
	try:
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC-Library Repository Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																														help='enable script wrapper debug mode',		action='store_const', const=True, default=False)
		group1.add_argument('-d',																	dest="debug",								help='enable debug mode',										action='store_const', const=True, default=False)
		group1.add_argument('-v',																	dest="verbose",							help='print out detailed messages',					action='store_const', const=True, default=False)
		group1.add_argument('-q',																	dest="quiet",								help='run in quiet mode',										action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',											dest="help",								help='show this help message and exit',			action='store_const', const=True, default=False)
		group21.add_argument('--configure',												dest="configurePoC",				help='configure PoC Library',								action='store_const', const=True, default=False)
		group21.add_argument('--new-solution',	metavar="<Name>",	dest="newSolution",					help='create a new solution')
		group21.add_argument('--add-solution',	metavar="<Name>",	dest="addSolution",					help='add an existing solution')
		group21.add_argument('--poc-installdir',									dest="pocInstallationDir",			help='return PoC installation directory',			action='store_const', const=True, default=False)
		group21.add_argument('--modelsim-installdir',								dest="modelSimInstallationDir",			help='return ModelSim installation directory',			action='store_const', const=True, default=False)
		group21.add_argument('--ise-settingsfile',								dest="iseSettingsFile",			help='return Xilinx ISE settings file',			action='store_const', const=True, default=False)
		group21.add_argument('--vivado-settingsfile',							dest="vivadoSettingsFile",	help='return Xilinx Vivado settings file',	action='store_const', const=True, default=False)

		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		Exit.printException(ex)

	# create class instance and start processing
	try:
		from colorama import Fore, Back, Style
		
		config = Configuration(args.debug, args.verbose, args.quiet)
		
		if (args.help == True):
			print(Fore.MAGENTA + "=" * 80)
			print("{: ^80s}".format(Configuration.headLine))
			print("=" * 80)
			print(Fore.RESET + Back.RESET + Style.RESET_ALL)
		
			argParser.print_help()
			return
		elif args.configurePoC:
			print(Fore.MAGENTA + "=" * 80)
			print("{: ^80s}".format(Configuration.headLine))
			print("=" * 80)
			print(Fore.RESET + Back.RESET + Style.RESET_ALL)
		
			#config.autoConfiguration()
			config.manualConfiguration()
			exit(0)
			
		elif args.newSolution:
			print(Fore.MAGENTA + "=" * 80)
			print("{: ^80s}".format(Configuration.headLine))
			print("=" * 80)
			print(Fore.RESET + Back.RESET + Style.RESET_ALL)
			
			config.newSolution(args.newSolution)
			exit(0)
			
		elif args.addSolution:
			print(Fore.MAGENTA + "=" * 80)
			print("{: ^80s}".format(Configuration.headLine))
			print("=" * 80)
			print(Fore.RESET + Back.RESET + Style.RESET_ALL)
			
			config.addSolution(args.addSolution)
			exit(0)
			
		elif args.pocInstallationDir:
			print(config.getPoCInstallationDir())
			exit(0)
		elif args.modelSimInstallationDir:
			print(config.getModelSimInstallationDir())
			exit(0)
		elif args.iseSettingsFile:
			print(config.getISESettingsFile())
			exit(0)
		elif args.vivadoSettingsFile:
			print(config.getVivadoSettingsFile())
			exit(0)
		else:
			print(Fore.MAGENTA + "=" * 80)
			print("{: ^80s}".format(Configuration.headLine))
			print("=" * 80)
			print(Fore.RESET + Back.RESET + Style.RESET_ALL)
		
			argParser.print_help()
			exit(0)
	
#	except ConfiguratorException as ex:
#		from colorama import Fore, Back, Style
#		print(Fore.RED + "ERROR:" + Fore.RESET + " %s" % ex.message)
#		if isinstance(ex.__cause__, FileNotFoundError):
#			print(Fore.YELLOW + "  FileNotFound:" + Fore.RESET + " '%s'" % str(ex.__cause__))
#		print(Fore.RESET + Back.RESET + Style.RESET_ALL)
#		exit(1)
		
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
	Exit.printThisIsNoLibraryFile(Configuration.headLine)
