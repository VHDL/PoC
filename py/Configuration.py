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
	
	def __init__(self, debug, verbose):
		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PoC.PoCPlatformNotSupportedException(self.platform)
		
		try:
			super(self.__class__, self).__init__(debug, verbose)
		except PoC.PoCNotConfiguredException as ex:
			import configparser
			
			self.printVerbose("Configuration file does not exists; creating a new one")
			
			self.pocConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
			self.pocConfig.optionxform = str
			self.pocConfig['PoC'] = {
				'Version' : '0.0.0',
				'InstallationDirectory' : self.Directories["Root"].as_posix()
			}
			self.pocConfig['Xilinx'] = {}
			self.pocConfig['Xilinx-ISE'] = {}
			self.pocConfig['Xilinx-Vivado'] = {}
			self.pocConfig['Altera-QuartusII'] = {}
			self.pocConfig['Altera-ModelSim'] = {}
			self.pocConfig['Questa-ModelSim'] = {}
			self.pocConfig['GHDL'] = {}
			self.pocConfig['GTKWave'] = {}

			# Writing configuration to disc
			with self.Files["PoCConfig"].open('w') as configFileHandle:
				self.pocConfig.write(configFileHandle)
			
			self.printDebug("New configuration file created: %s" % self.Files["PoCConfig"])
			
			# re-read configuration
			self.__readPoCConfiguration()
			self.__readPoCStructure()
	
	def autoConfiguration(self):
		raise NotImplementedException("No automatic configuration available!")
	
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
	
		# Writing configuration to disc
		print("Writing configuration file to '%s'" % str(self.Files["PoCConfig"]))
		with self.Files["PoCConfig"].open('w') as configFileHandle:
			self.pocConfig.write(configFileHandle)
	
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
				xilinxDirectory = input('Xilinx Installation Directory [C:\Xilinx]: ')
				iseVersion = input('Xilinx ISE Version Number [14.7]: ')
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
				xilinxDirectory = input('Xilinx Installation Directory [C:\Xilinx]: ')
				vivadoVersion = input('Xilinx Vivado Version Number [2014.1]: ')
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
				ghdlDirectory = input('GHDL Installation Directory [C:\Program Files (x86)\GHDL]: ')
				ghdlVersion = input('GHDL Version Number [0.31]: ')
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
				xilinxDirectory = input('Xilinx Installation Directory [/opt/xilinx]: ')
				iseVersion = input('Xilinx ISE Version Number [14.7]: ')
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
				xilinxDirectory = input('Xilinx Installation Directory [/opt/xilinx]: ')
				vivadoVersion = input('Xilinx Vivado Version Number [2014.1]: ')
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
				ghdlDirectory = input('GHDL Installation Directory [/usr/bin]: ')
				ghdlVersion = input('GHDL Version Number [0.31]: ')
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
		
		if		(self.platform == "Windows"):		return(str(iseInstallationDirectoryPath / "settings64.cmd"))
		elif	(self.platform == "Linux"):			return(str(iseInstallationDirectoryPath / "settings64.sh"))
		
	def getVivadoSettingsFile(self):
		raise NotImplementedException("method 'getVivadoSettingsFile' not implemented!")
	
# main program
def main():
	from sys import exit
	
	try:
		import argparse
		import textwrap

		# create a commandline argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library Repository Service Tool.
				'''))

		# add arguments
		argParser.add_argument('-D', action='store_const', const=True, default=False, help='enable script wrapper debug mode')
		argParser.add_argument('-d', action='store_const', const=True, default=False, help='enable debug mode')
		argParser.add_argument('-v', action='store_const', const=True, default=False, help='generate detailed report')
		argParser.add_argument('--configure',						action='store_const', const=True, default=False, help='configures PoC Library')
		argParser.add_argument('--ise-settingsfile',		action='store_const', const=True, default=False, help='Return Xilinx ISE settings file')
		argParser.add_argument('--vivado-settingsfile', action='store_const', const=True, default=False, help='Return Xilinx Vivado settings file')
		
		# parse command line options
		args = argParser.parse_args()

	except Exception as ex:
		print("FATAL: %s" % ex.__str__())
		print()
		exit(1)

	# create class instance and start processing
	try:
		config = PoCConfiguration(args.d, args.v)
		
		if args.configure:
			print("========================================================================")
			print("                  PoC Library - Repository Service Tool                 ")
			print("========================================================================")
			print()
		
			#config.autoConfiguration()
			config.manualConfiguration()
			exit(0)
		elif args.ise_settingsfile:
			print(config.getISESettingsFile())
			exit(0)
		elif args.vivado_settingsfile:
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
		print("FATAL: %s" % ex.__str__())
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
