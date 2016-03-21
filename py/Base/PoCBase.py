# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Class:			TODO
# 
# Authors:				 	Patrick Lehmann
# 
# Description:
# ------------------------------------
#		TODO:
#		- 
#		- 
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
#
# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Base.PoCBase")

# load dependencies
from configparser			import ConfigParser, ExtendedInterpolation
from pathlib					import Path
from platform					import system as platform_system
from os								import environ

from Base.Exceptions	import *
from Base.Logging			import ILogable

class CommandLineProgram(ILogable):
	# configure hard coded variables here
	__scriptDirectoryName = 			"py"
	__pocPrivateConfigFileName =	"config.private.ini"
	__pocPublicConfigFileName =		"config.public.ini"
	__pocBoardConfigFileName =		"config.boards.ini"

	# private fields
	__platform = platform_system()			# load platform information (Windows, Linux, ...)

	# constructor
	# ============================================================================
	def __init__(self, logger=None):
		ILogable.__init__(self, logger)
		
		self.__logger =				logger
		self.__files =				{}
		self.__directories =	{}
		
		# check for environment variables
		if (environ.get('PoCRootDirectory') == None):			raise EnvironmentException("Shell environment does not provide 'PoCRootDirectory' variable.")
		if (environ.get('PoCScriptDirectory') == None):		raise EnvironmentException("Shell environment does not provide 'PoCScriptDirectory' variable.")
		
		self.Directories['Working'] =			Path.cwd()
		self.Directories['PoCRoot'] =			Path(environ.get('PoCRootDirectory'))
		self.Directories['ScriptRoot'] =	Path(environ.get('PoCRootDirectory'))
		self.Files['PoCPrivateConfig'] =	self.Directories["PoCRoot"] / self.__scriptDirectoryName / self.__pocPrivateConfigFileName
		self.Files['PoCPublicConfig'] =		self.Directories["PoCRoot"] / self.__scriptDirectoryName / self.__pocPublicConfigFileName
		self.Files['PoCBoardConfig'] =		self.Directories["PoCRoot"] / self.__scriptDirectoryName / self.__pocBoardConfigFileName
		
		self.__ReadPoCConfiguration()

	# class properties
	# ============================================================================
	@property
	def Platform(self):			return self.__platform
	@property
	def Directories(self):	return self.__directories
	@property
	def Files(self):				return self.__files
	
	# read PoC configuration
	# ============================================================================
	def __ReadPoCConfiguration(self):
		pocPrivateConfigFilePath =	self.Files['PoCPrivateConfig']
		pocPublicConfigFilePath =		self.Files['PoCPublicConfig']
		pocBoardConfigFilePath =		self.Files['PoCBoardConfig']
		
		self._LogDebug("Reading PoC configuration from\n  '{0}'\n  '{1}\n  '{2}'".format(str(pocPrivateConfigFilePath), str(pocPublicConfigFilePath), str(pocBoardConfigFilePath)))
		if not pocPrivateConfigFilePath.exists():		raise NotConfiguredException("PoC's private configuration file '{0}' does not exist.".format(str(pocPrivateConfigFilePath)))	from FileNotFoundError(str(pocPrivateConfigFilePath))
		if not pocPublicConfigFilePath.exists():		raise NotConfiguredException("PoC' public configuration file '{0}' does not exist.".format(str(pocPublicConfigFilePath)))			from FileNotFoundError(str(pocPublicConfigFilePath))
		if not pocBoardConfigFilePath.exists():			raise NotConfiguredException("PoC's board configuration file '{0}' does not exist.".format(str(pocBoardConfigFilePath)))			from FileNotFoundError(str(pocBoardConfigFilePath))
		
		self.pocConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.pocConfig.optionxform = str
		self.pocConfig.read([
			str(pocPrivateConfigFilePath),
			str(pocPublicConfigFilePath),
			str(pocBoardConfigFilePath)
		])
		
		# parsing values into class fields
		if (self.Directories["PoCRoot"] != Path(self.pocConfig['PoC']['InstallationDirectory'])):
			raise NotConfiguredException("There is a mismatch between PoCRoot and PoC installation directory.")

		# read PoC configuration
		# ============================================================================
		# parsing values into class fields
		self.Directories["PoCSource"] =			self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['HDLSourceFiles']
		self.Directories["PoCTestbench"] =	self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['TestbenchFiles']
		self.Directories["PoCNetList"] =		self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['NetListFiles']
		self.Directories["PoCTemp"] =				self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['TemporaryFiles']

		# self.Directories["XSTFiles"] =			self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['ISESynthesisFiles']
		# #self.Directories["QuartusFiles"] =	self.Directories["PoCRoot"] / self.pocConfig['PoC.DirectoryNames']['QuartusSynthesisFiles']

		# self.Directories["CoreGenTemp"] =		self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ISECoreGeneratorFiles']
		# self.Directories["XSTTemp"] =				self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['ISESynthesisFiles']
		# #self.Directories["QuartusTemp"] =	self.Directories["PoCTemp"] / self.pocConfig['PoC.DirectoryNames']['QuartusSynthesisFiles']
