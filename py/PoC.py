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
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from sys import exit

	print("========================================================================")
	print("                  PoC Library - Python Class PoCBase                    ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)


import configparser
from pathlib import Path
#import os

#import re
#import shutil
#import string
#import subprocess
#import sys
#import textwrap

class PoCBase(object):
	from platform import system
	
	__debug = False
	__verbose = False
	__quiet = False
	platform = system()

	Directories = {
		"Root"					: Path.cwd(),
		"PoCRoot"				: None
		}
	
	Files = {
		"PoCConfig"			: None,
		"PoCStructure"	: None
	}
	
	__pocConfigFileName = "configuration.ini"
	__pocStructureFileName = "structure.ini"
	
	pocConfig = None
	pocStructure = None
	
	def __init__(self, debug, verbose, quiet):
		self.__debug = debug
		self.__verbose = verbose
		self.__quiet = quiet

		self.__readPoCConfiguration()
		self.__readPoCStructure()
		
	# read PoC configuration
	# ============================================================================
	def __readPoCConfiguration(self):
		pocConfigFilePath = self.Directories["Root"] / self.__pocConfigFileName
		self.Files["PoCConfig"]	= pocConfigFilePath
		
		self.printDebug("Reading PoC configuration from '%s'" % str(pocConfigFilePath))
		if not pocConfigFilePath.exists():
			raise PoCNotConfiguredException("PoC configuration file does not exist. (%s)" % str(pocConfigFilePath))
		
		self.pocConfig = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.pocConfig.optionxform = str
		self.pocConfig.read(str(pocConfigFilePath))
		
		# parsing values into class fields
		self.Directories["PoCRoot"] = Path(self.pocConfig['PoC']['InstallationDirectory'])

	# read PoC configuration
	# ============================================================================
	def __readPoCStructure(self):
		pocStructureFilePath = self.Directories["Root"] / self.__pocStructureFileName
		self.Files["PoCStructure"]	= pocStructureFilePath
		
		self.printDebug("Reading PoC configuration from '%s'" % str(pocStructureFilePath))
		if not pocStructureFilePath.exists():
			raise PoCNotConfiguredException("PoC structure file does not exist. (%s)" % str(pocStructureFilePath))
		
		self.pocStructure = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.pocStructure.optionxform = str
		self.pocStructure.read(str(pocStructureFilePath))
		
		# parsing values into class fields
		self.Directories["PoCSource"] =			self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['HDLSourceFiles']
		self.Directories["PoCTestbench"] =	self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['TestbenchFiles']
		self.Directories["PoCNetList"] =		self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['NetListFiles']
		self.Directories["PoCTemp"] =				self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['TemporaryFiles']
		
		self.Directories["iSimFiles"] =			self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['ISESimulatorFiles']
		#XilinxSynthesisFiles = xst
		#QuartusSynthesisFiles = quartus		
		
		self.Directories["iSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ISESimulatorFiles']
		self.Directories["xSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['VivadoSimulatorFiles']
		self.Directories["vSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ModelSimSimulatorFiles']
		self.Directories["ghdlTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['GHDLSimulatorFiles']
		
		self.Directories["coreGenTemp"] =		self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ISECoreGeneratorFiles']
	
	def getDebug(self):
		return self.__debug
		
	def getVerbose(self):
		return self.__verbose
	
	def getquiet(self):
		return self.__quiet
	
	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)
	
	def printNonQuiet(self, message):
		if (not self.__quiet):
			print(message)

	def getNamespaceForPrefix(self, namespacePrefix):
		return self.tbConfig['NamespacePrefixes'][namespacePrefix]

from enum import Enum, EnumMeta, unique
#class PoCEntityTypesEnumMeta(EnumMeta):
#	def __call__(cls, value, *args, **kw):
#		if isinstance(value, str):
#			# map strings to enum values, defaults to Unknown
#			mapping = {
#				'src': 1,
#				'tb' : 2,
#				'nl': 3
#			}
#			value = mapping.get(value, 0)
#			return super().__call__(value, *args, **kw)

@unique
class PoCEntityTypes(Enum):#, metaclass=PoCEntityTypesEnumMeta):
	Unknown = 0
	Source = 1
	Testbench = 2
	NetList = 3

	def __str__(self):
		if		(self == PoCEntityTypes.Unknown):		return "??"
		elif	(self == PoCEntityTypes.Source):		return "src"
		elif	(self == PoCEntityTypes.Testbench):	return "tb"
		elif	(self == PoCEntityTypes.NetList):		return "nl"

def _PoCEntityTypes_parser(cls, value):
	if not isinstance(value, str):
		return Enum.__new__(cls, value)
	else:
		# map strings to enum values, default to Unknown
		return {
			'src':	PoCEntityTypes.Source,
			'tb':		PoCEntityTypes.Testbench,
			'nl':		PoCEntityTypes.NetList
		}.get(value, PoCEntityTypes.Unknown)

# override __new__ method in PoCEntityTypes with _PoCEntityTypes_parser
setattr(PoCEntityTypes, '__new__', _PoCEntityTypes_parser)
		
class PoCEntity(object):
	host = None
  
	type = None
	name = ""
	parts = []
	
	def __init__(self, host, name):
		self.host = host
	
		#check if a type is given
		splitList1 = name.split(':')
		if (len(splitList1) == 1):
			self.type = PoCEntityTypes.Source
			namespacePart = name
		elif (len(splitList1) == 2):
			self.type = PoCEntityTypes(splitList1[0])
			namespacePart = splitList1[1]
		else:
			raise ArgumentException("Argument has to many ':' signs.")
		
		self.parts = namespacePart.split('.')
		
	def Root(host):
		return PoCEntity(host, "PoC")
	
	def isSingleEntity(self):
		pass
	
	def isNamespace(self):
		pass
	
	def getParentNamespace(self):
		pass
	
	def getEntities(self):
		pass
	
	def getSubNamespaces(self):
		pass
	
	def __str__(self):
		return "PoC." + '.'.join(self.parts)
		#return str(self.type) + ":PoC." + '.'.join(self.parts)
		
class NotImplementedException(Exception):
	def __init__(self, message):
		super().__init__()
		self.message = message
	
class ArgumentException(Exception):
	def __init__(self, message):
		super().__init__()
		self.message = message
		
class PoCException(Exception):
	def __init__(self, message=""):
		super().__init__()
		self.message = message

	def __str__(self):
		return self.message
		
class PoCEnvironmentException(PoCException):
	def __init__(self, message=""):
		super().__init__(message)
		self.message = message

class PoCPlatformNotSupportedException(PoCException):
	def __init__(self, message=""):
		super().__init__(message)
		self.message = message

class PoCNotConfiguredException(PoCException):
	def __init__(self, message=""):
		super().__init__(message)
		self.message = message
