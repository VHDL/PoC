# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Main Module:  Entry point to configure the local copy of this PoC repository.
# 
# Authors:         		 Patrick Lehmann
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - configures the PoC Library to your local environment,
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


class PoCConfiguration(PoC.PoCBase):
	
	__privateSections = ["PoC", "Xilinx", "Xilinx-ISE", "Xilinx-Vivado", "Altera-QuartusII", "Altera-ModelSim", "Questa-ModelSim", "GHDL", "GTKWave"]
	
	def __init__(self, debug, verbose, quiet):
		try:
			super(self.__class__, self).__init__(debug, verbose, quiet)

			if not ((self.platform == "Windows") or (self.platform == "Linux")):
				raise PoC.PoCPlatformNotSupportedException(self.platform)
				
		except PoC.PoCNotConfiguredException as ex:
			from configparser import ConfigParser, ExtendedInterpolation
			from collections import OrderedDict
			
			self.printVerbose("Configuration file does not exists; creating a new one")
			
			self.pocConfig = ConfigParser(interpolation=ExtendedInterpolation())
			self.pocConfig.optionxform = str
			self.pocConfig['PoC'] = OrderedDict()
			self.pocConfig['PoC']['Version'] = '0.0.0'
			self.pocConfig['PoC']['InstallationDirectory'] = self.Directories["PoCRoot"].as_posix()

			self.pocConfig['Xilinx'] =						OrderedDict()
			self.pocConfig['Xilinx-ISE'] =				OrderedDict()
			self.pocConfig['Xilinx-Vivado'] =			OrderedDict()
			self.pocConfig['Altera-QuartusII'] =	OrderedDict()
			self.pocConfig['Altera-ModelSim'] =		OrderedDict()
			self.pocConfig['Questa-ModelSim'] =		OrderedDict()
			self.pocConfig['GHDL'] =							OrderedDict()
			self.pocConfig['GTKWave'] =						OrderedDict()

			# Writing configuration to disc
			with self.files["PoCPrivateConfig"].open('w') as configFileHandle:
				self.pocConfig.write(configFileHandle)
			
			self.printDebug("New configuration file created: %s" % self.files["PoCPrivateConfig"])
			
			# re-read configuration
			self.readPoCConfiguration()
	
	def autoConfiguration(self):
		raise PoC.NotImplementedException("No automatic configuration available!")
	
	def manualConfiguration(self):
		self.printConfigurationHelp()
		
		# configure Windows
		if (self.platform == 'Windows'):
			# configure ISE on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsISE()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
			
			# configure Vivado on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsVivado()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
			
			# configure GHDL on Windows
			next = False
			while (next == False):
				try:
					self.manualConfigureWindowsGHDL()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
		
		# configure Linux
		elif (self.platform == 'Linux'):
			# configure ISE on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxISE()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
			
			# configure Vivado on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxVivado()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
					
			# configure GHDL on Linux
			next = False
			while (next == False):
				try:
					self.manualConfigureLinuxGHDL()
					next = True
				except PoC.PoCException as ex:
					print("FAULT: %s" % ex.message)
				except Exception as ex:
					raise Exception
		else:
			raise PoC.PoCPlatformNotSupportedException(self.platform)
	
		# remove non private sections from pocConfig
		sections = self.pocConfig.sections()
		for privateSection in self.__privateSections:
			sections.remove(privateSection)
			
		for section in sections:
			self.pocConfig.remove_section(section)
	
		# Writing configuration to disc
		print("Writing configuration file to '%s'" % str(self.files["PoCPrivateConfig"]))
		with self.files["PoCPrivateConfig"].open('w') as configFileHandle:
			self.pocConfig.write(configFileHandle)
	
		# re-read configuration
		self.readPoCConfiguration()
	
	def printConfigurationHelp(self):
		self.printVerbose("starting manual configuration...")
		print('Explanation of abbreviations:')
		print('  y - yes')
		print('  n - no')
		print('  p - pass (jump to next question)')
		print('Upper case means default value')
		print()
	
	def manualConfigureWindowsISE(self):
		# Ask for installed Xilinx ISE
		isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
		isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
		if (isXilinxISE != 'p'):
			if (isXilinxISE == 'Y'):
				xilinxDirectory =	input('Xilinx Installation Directory [C:\Xilinx]: ')
				iseVersion =			input('Xilinx ISE Version Number [14.7]: ')
				print()
				
				xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "C:\Xilinx"
				iseVersion = iseVersion if iseVersion != "" else "14.7"
				
				xilinxDirectoryPath = Path(xilinxDirectory)
				iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"
				
				if not xilinxDirectoryPath.exists():	raise PoC.PoCException("Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
				if not iseDirectoryPath.exists():			raise PoC.PoCException("Xilinx ISE version '%s' is not installed." % iseVersion)
				
				self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
				self.pocConfig['Xilinx-ISE']['Version'] = iseVersion
				self.pocConfig['Xilinx-ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
				self.pocConfig['Xilinx-ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/nt64'
			elif (isXilinxISE == 'n'):
				self.pocConfig['Xilinx-ISE'] = {}
			else:
				raise PoC.PoCException("unknown option")
		
	def manualConfigureWindowsVivado(self):
		# Ask for installed Xilinx Vivado
		isXilinxVivado = input('Is Xilinx Vivado installed on your system? [Y/n/p]: ')
		isXilinxVivado = isXilinxVivado if isXilinxVivado != "" else "Y"
		if (isXilinxVivado != 'p'):
			if (isXilinxVivado == 'Y'):
				xilinxDirectory =	input('Xilinx Installation Directory [C:\Xilinx]: ')
				vivadoVersion =		input('Xilinx Vivado Version Number [2014.1]: ')
				print()
			
				xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "C:\Xilinx"
				vivadoVersion = vivadoVersion if vivadoVersion != "" else "2014.1"
			
				xilinxDirectoryPath = Path(xilinxDirectory)
				vivadoDirectoryPath = xilinxDirectoryPath / "Vivado" / vivadoVersion
			
				if not xilinxDirectoryPath.exists():	raise PoC.PoCException("Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
				if not vivadoDirectoryPath.exists():	raise PoC.PoCException("Xilinx Vivado version '%s' is not installed." % vivadoVersion)
			
				self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
				self.pocConfig['Xilinx-Vivado']['Version'] = vivadoVersion
				self.pocConfig['Xilinx-Vivado']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/Vivado/${Version}'
				self.pocConfig['Xilinx-Vivado']['BinaryDirectory'] = '${InstallationDirectory}/bin'
			elif (isXilinxVivado == 'n'):
				self.pocConfig['Xilinx-Vivado'] = {}
			else:
				raise PoC.PoCException("unknown option")
		
	def manualConfigureWindowsGHDL(self):
		# Ask for installed GHDL
		isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
		isGHDL = isGHDL if isGHDL != "" else "Y"
		if (isGHDL != 'p'):
			if (isGHDL == 'Y'):
				ghdlDirectory =	input('GHDL Installation Directory [C:\Program Files (x86)\GHDL]: ')
				ghdlVersion =		input('GHDL Version Number [0.31]: ')
				print()
			
				ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "C:\Program Files (x86)\GHDL"
				ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"
			
				ghdlDirectoryPath = Path(ghdlDirectory)
				ghdlExecutablePath = ghdlDirectoryPath / "bin" / "ghdl.exe"
			
				if not ghdlDirectoryPath.exists():	raise PoC.PoCException("GHDL Installation Directory '%s' does not exist." % ghdlDirectory)
				if not ghdlExecutablePath.exists():	raise PoC.PoCException("GHDL is not installed.")
			
				self.pocConfig['GHDL']['Version'] = ghdlVersion
				self.pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
				self.pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}/bin'
			elif (isGHDL == 'n'):
				self.pocConfig['GHDL'] = {}
			else:
				raise PoC.PoCException("unknown option")
		
	def manualConfigureLinuxISE(self):
		# Ask for installed Xilinx ISE
		isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
		isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
		if (isXilinxISE != 'p'):
			if (isXilinxISE == 'Y'):
				xilinxDirectory =	input('Xilinx Installation Directory [/opt/Xilinx]: ')
				iseVersion =			input('Xilinx ISE Version Number [14.7]: ')
				print()
			
				xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "/opt/Xilinx"
				iseVersion = iseVersion if iseVersion != "" else "14.7"
			
				xilinxDirectoryPath = Path(xilinxDirectory)
				iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"
			
				if not xilinxDirectoryPath.exists():	raise PoC.PoCException("Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
				if not iseDirectoryPath.exists():			raise PoC.PoCException("Xilinx ISE version '%s' is not installed." % iseVersion)
			
				self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
				self.pocConfig['Xilinx-ISE']['Version'] = iseVersion
				self.pocConfig['Xilinx-ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
				self.pocConfig['Xilinx-ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/lin64'
			elif (isXilinxISE == 'n'):
				self.pocConfig['Xilinx-ISE'] = {}
			else:
				raise PoC.PoCException("unknown option")
		
	def manualConfigureLinuxVivado(self):
		# Ask for installed Xilinx Vivado
		isXilinxVivado = input('Is Xilinx Vivado installed on your system? [Y/n/p]: ')
		isXilinxVivado = isXilinxVivado if isXilinxVivado != "" else "Y"
		if (isXilinxVivado != 'p'):
			if (isXilinxVivado == 'Y'):
				xilinxDirectory =	input('Xilinx Installation Directory [/opt/Xilinx]: ')
				vivadoVersion =		input('Xilinx Vivado Version Number [2014.1]: ')
				print()
			
				xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "/opt/Xilinx"
				vivadoVersion = vivadoVersion if vivadoVersion != "" else "2014.1"
			
				xilinxDirectoryPath = Path(xilinxDirectory)
				vivadoDirectoryPath = xilinxDirectoryPath / "Vivado" / vivadoVersion
			
				if not xilinxDirectoryPath.exists():	raise PoC.PoCException("Xilinx Installation Directory '%s' does not exist." % xilinxDirectory)
				if not vivadoDirectoryPath.exists():	raise PoC.PoCException("Xilinx Vivado version '%s' is not installed." % vivadoVersion)
			
				self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
				self.pocConfig['Xilinx-Vivado']['Version'] = vivadoVersion
				self.pocConfig['Xilinx-Vivado']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/Vivado/${Version}'
				self.pocConfig['Xilinx-Vivado']['BinaryDirectory'] = '${InstallationDirectory}/bin'
			elif (isXilinxVivado == 'n'):
				self.pocConfig['Xilinx-Vivado'] = {}
			else:
				raise PoC.PoCException("unknown option")
	
	def manualConfigureLinuxGHDL(self):
		# Ask for installed GHDL
		isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
		isGHDL = isGHDL if isGHDL != "" else "Y"
		if (isGHDL != 'p'):
			if (isGHDL == 'Y'):
				ghdlDirectory =	input('GHDL Installation Directory [/usr/bin]: ')
				ghdlVersion =		input('GHDL Version Number [0.31]: ')
				print()
			
				ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "/usr/bin"
				ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"
			
				ghdlDirectoryPath = Path(ghdlDirectory)
				ghdlExecutablePath = ghdlDirectoryPath / "ghdl"
			
				if not ghdlDirectoryPath.exists():	raise PoC.PoCException("GHDL Installation Directory '%s' does not exist." % ghdlDirectory)
				if not ghdlExecutablePath.exists():	raise PoC.PoCException("GHDL is not installed.")
			
				self.pocConfig['GHDL']['Version'] = ghdlVersion
				self.pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
				self.pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}'
			elif (isGHDL == 'n'):
				self.pocConfig['GHDL'] = {}
			else:
				raise PoC.PoCException("unknown option")
		
	def getISESettingsFile(self):
		if (len(self.pocConfig.options("Xilinx-ISE")) == 0):
			raise PoCNotConfiguredException("ERROR: Xilinx ISE is not configured on this system.")
		
		iseInstallationDirectoryPath = Path(self.pocConfig['Xilinx-ISE']['InstallationDirectory'])
		
		if		(self.Platform == "Windows"):		return (str(iseInstallationDirectoryPath / "settings64.bat"))
		elif	(self.Platform == "Linux"):			return (str(iseInstallationDirectoryPath / "settings64.sh"))
		
	def getVivadoSettingsFile(self):
		if (len(self.pocConfig.options("Xilinx-Vivado")) == 0):
			raise PoCNotConfiguredException("ERROR: Xilinx Vivado is not configured on this system.")
		
		vivadoInstallationDirectoryPath = Path(self.pocConfig['Xilinx-Vivado']['InstallationDirectory'])
		
		if		(self.Platform == "Windows"):		return (str(vivadoInstallationDirectoryPath / "settings64.bat"))
		elif	(self.Platform == "Linux"):			return (str(vivadoInstallationDirectoryPath / "settings64.sh"))
	
# main program
def main():
	from sys import exit
	import argparse
	import textwrap
	
	try:
		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Repository Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																								help='enable script wrapper debug mode',		action='store_const', const=True, default=False)
		group1.add_argument('-d',											dest="debug",								help='enable debug mode',										action='store_const', const=True, default=False)
		group1.add_argument('-v',											dest="verbose",							help='print out detailed messages',					action='store_const', const=True, default=False)
		group1.add_argument('-q',											dest="quiet",								help='run in quiet mode',										action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',					dest="help",								help='show this help message and exit',			action='store_const', const=True, default=False)
		group21.add_argument('--configure',						dest="configurePoC",				help='configure PoC Library',								action='store_const', const=True, default=False)
		group21.add_argument('--ise-settingsfile',		dest="iseSettingsFile",			help='return Xilinx ISE settings file',			action='store_const', const=True, default=False)
		group21.add_argument('--vivado-settingsfile',	dest="vivadoSettingsFile",	help='return Xilinx Vivado settings file',	action='store_const', const=True, default=False)

		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("FATAL: %s" % ex.__str__())
		print()
		exit(1)

	# create class instance and start processing
	try:
		config = PoCConfiguration(args.debug, args.verbose, args.quiet)
		
		if (args.help == True):
			argParser.print_help()
			return
		elif args.configurePoC:
			print("========================================================================")
			print("                  PoC Library - Repository Service Tool                 ")
			print("========================================================================")
			print()
		
			#config.autoConfiguration()
			config.manualConfiguration()
			exit(0)
		elif args.iseSettingsFile:
			print(config.getISESettingsFile())
			exit(0)
		elif args.vivadoSettingsFile:
			print(config.getVivadoSettingsFile())
			exit(0)
		else:
			argParser.print_help()
			exit(0)
	
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
		print("-" * 20)
		print_tb(ex.__traceback__)
		print("-" * 20)
		print()
		return
	
	exit(1)

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
	print("                  PoC Library - Repository Service Tool                 ")
	print("========================================================================")
	print()
	print("This is no library file!")
	exit(1)
