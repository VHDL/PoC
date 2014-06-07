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
	__platform = system()

	Directories = {
		"Root"			: Path.cwd(),
		"PoCRoot"		: None
		}
	
	__pocConfigFileName = "configuration.ini"
	__pocStructureFileName = "structure.ini"
	
	pocConfig = None
	pocStructure = None
	
	def __init__(self, debug, verbose):
		self.__debug = debug
		self.__verbose = verbose

		self.__readPoCConfiguration()
		self.__readPoCStructure()
		
	# read PoC configuration
	# ============================================================================
	def __readPoCConfiguration(self):
		pocConfigFilePath = self.Directories["Root"] / self.__pocConfigFileName
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
		self.printDebug("Reading PoC configuration from '%s'" % str(pocStructureFilePath))
		if not pocStructureFilePath.exists():
			raise PoCNotConfiguredException("PoC structure file does not exist. (%s)" % str(pocStructureFilePath))
		
		self.pocStructure = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
		self.pocStructure.optionxform = str
		self.pocStructure.read(str(pocStructureFilePath))
		
		# parsing values into class fields
		# ...

	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)

#	def getNamespaceForPrefix(self, namespacePrefix):
#		return self.__tbConfig['NamespacePrefixes'][namespacePrefix]
		
class PoCException(Exception):
	def __init__(self):
		super(self.__class__, self).__init__()

class NotImplementedException(Exception):
	def __init__(self, message):
		super(self.__class__, self).__init__()
		self.message = message

	def __str__(self):
		return self.message
		
class PoCNotConfiguredException(PoCException):
	def __init__(self, message):
		super(self.__class__, self).__init__()
		self.message = message

	def __str__(self):
		return self.message