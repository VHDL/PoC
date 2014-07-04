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


from enum import Enum, EnumMeta, unique
import configparser
from pathlib import Path
import re


class PoCBase(object):
	__debug = False
	__verbose = False
	__quiet = False
	platform = ""

	Directories =	{}
	Files =				{}
	
	__pocConfigFileName =			"configuration.ini"
	__pocStructureFileName =	"structure.ini"
	
	pocConfig = None
	pocStructure = None
	
	def __init__(self, debug, verbose, quiet):
		import platform
	
		# save flags
		self.__debug = debug
		self.__verbose = verbose
		self.__quiet = quiet
		
		# load platform information (Windows, Linux, ...)
		self.platform = platform.system()
		
		# check for environment variables
		if (environ.get('PoCRootDirectory') == None):
			raise PoC.PoCEnvironmentException("Shell environment does not provide 'PoCRootDirectory' variable.")
		
		self.Directories['Root'] =		Path.cwd()
		self.Directories['PoCRoot'] =	Path(environ.get('PoCRootDirectory'))
		self.Files['PoCConfig'] =			None
		self.Files['PoCStructure'] =	None
		
		self.readPoCConfiguration()
		self.readPoCStructure()
		
	# read PoC configuration
	# ============================================================================
	def readPoCConfiguration(self):
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
	def readPoCStructure(self):
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
		self.Directories["XSTFiles"] =			self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['ISESynthesisFiles']
		#self.Directories["QuartusFiles"] =	self.Directories["PoCRoot"] / self.pocStructure['DirectoryNames']['QuartusSynthesisFiles']
		
		self.Directories["iSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ISESimulatorFiles']
		self.Directories["xSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['VivadoSimulatorFiles']
		self.Directories["vSimTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ModelSimSimulatorFiles']
		self.Directories["GHDLTemp"] =			self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['GHDLSimulatorFiles']
		
		self.Directories["CoreGenTemp"] =		self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ISECoreGeneratorFiles']
		self.Directories["XSTTemp"] =				self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['ISESynthesisFiles']
		#self.Directories["QuartusTemp"] =	self.Directories["PoCTemp"] / self.pocStructure['DirectoryNames']['QuartusSynthesisFiles']
	
	def getDebug(self):
		return self.__debug
		
	def getVerbose(self):
		return self.__verbose
	
	def getQuiet(self):
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


@unique
class PoCEntityTypes(Enum):
	Unknown = 0
	Source = 1
	Testbench = 2
	NetList = 3

	def __str__(self):
		if	 (self == PoCEntityTypes.Unknown):		return "??"
		elif (self == PoCEntityTypes.Source):			return "src"
		elif (self == PoCEntityTypes.Testbench):	return "tb"
		elif (self == PoCEntityTypes.NetList):		return "nl"

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

class PoCDevice(object):
	@unique
	class Vendors(Enum):
		Unknown = 0
		Xilinx = 1
		Altera = 2

		def __str__(obj):
			return obj.name.lower()
		
	@unique
	class Families(Enum):
		Unknown = 0
		# Xilinx families
		Spartan = 1
		Artix = 2
		Kintex = 3
		Virtex = 4
		Zynq = 5
		# Altera families
		Cyclon = 11
		Stratix = 12

		def __str__(obj):
			return obj.name.lower()
		
		def __repr__(obj):
			if	 (obj == PoCDevice.Families.Spartan):	return "s"
			elif (obj == PoCDevice.Families.Artix):		return "a"
			elif (obj == PoCDevice.Families.Kintex):	return "k"
			elif (obj == PoCDevice.Families.Virtex):	return "v"
			elif (obj == PoCDevice.Families.Zynq):		return "z"
		
	@unique
	class SubTypes(Enum):
		Unknown = 0
		# Xilinx device subtypes
		X = 1
		T = 2
		XT = 3
		HT = 4
		LX = 5
		SXT = 6
		LXT = 7
		TXT = 8
		FXT = 9
		CXT = 10
		HXT = 11
		# Altera device subtypes
		E = 101
		GS = 102
		GX = 103
		GT = 104

		def __str__(obj):
			return obj.name.lower()

		def groups(obj):
			if	 (obj == PoCDevice.SubTypes.X):		return ("x",	"")
			elif (obj == PoCDevice.SubTypes.T):		return ("",		"t")
			elif (obj == PoCDevice.SubTypes.XT):	return ("x",	"t")
			elif (obj == PoCDevice.SubTypes.HT):	return ("h",	"t")
			elif (obj == PoCDevice.SubTypes.LX):	return ("lx",	"")
			elif (obj == PoCDevice.SubTypes.SXT):	return ("sx",	"t")
			elif (obj == PoCDevice.SubTypes.LXT):	return ("lx",	"t")
			elif (obj == PoCDevice.SubTypes.TXT):	return ("tx",	"t")
			elif (obj == PoCDevice.SubTypes.FXT):	return ("fx",	"t")
			elif (obj == PoCDevice.SubTypes.CXT):	return ("cx",	"t")
			elif (obj == PoCDevice.SubTypes.HXT):	return ("hx",	"t")
			else: return ("??", "?")
		
	@unique
	class Packages(Enum):
		Unknown = 0
		
		FF = 1
		FFG = 2
		
		def __str__(obj):
			if	 (obj == PoCDevice.Packages.FF):		return "ff"
			elif (obj == PoCDevice.Packages.FFG):		return "ffg"
			else: return "??"

	# PoCDevice members
	vendor = Vendors.Unknown
	generation = 0
	family = Families.Unknown
	subtype = SubTypes.Unknown
	number = 0
	speedGrade = 0
	package = Packages.Unknown
	pinCount = 0

	def __init__(obj, deviceString):
		# vendor = Xilinx
		if (deviceString[0:2].lower() == "xc"):
			obj.vendor = PoCDevice.Vendors.Xilinx
			obj.generation = int(deviceString[2:3])

			temp = deviceString[3:4].lower()
			if	 (temp == "a"):	obj.family = PoCDevice.Families.Artix
			elif (temp == "k"):	obj.family = PoCDevice.Families.Kintex
			elif (temp == "v"):	obj.family = PoCDevice.Families.Virtex
			elif (temp == "z"):	obj.family = PoCDevice.Families.Zynq
			else: raise PoCException("Unknown device family.")

			deviceRegExpStr =  r"(?P<st1>[cfhlstx]{0,2})"			# device subtype - part 1
			deviceRegExpStr += r"(?P<no>\d{1,4})"							# device number
			deviceRegExpStr += r"(?P<st2>[t]{0,1})"						# device subtype - part 2
			deviceRegExpStr += r"(?P<sg>[-1-3]{2})"						# speed grade
			deviceRegExpStr += r"(?P<pack>[fg]{1,3})"					# package
			deviceRegExpStr += r"(?P<pins>\d{1,4})"						# pin count
			
			deviceRegExp = re.compile(deviceRegExpStr)
			deviceRegExpMatch = deviceRegExp.match(deviceString[4:].lower())

			if (deviceRegExpMatch is not None):
				subtype = deviceRegExpMatch.group('st1') + deviceRegExpMatch.group('st2')
				package = deviceRegExpMatch.group('pack')
				
				obj.subtype = PoCDevice.SubTypes[subtype.upper()]
				obj.number = int(deviceRegExpMatch.group('no'))
				obj.speedGrade = int(deviceRegExpMatch.group('sg'))
				obj.package = PoCDevice.Packages[package.upper()]
				obj.pinCount = int(deviceRegExpMatch.group('pins'))
		
		# vendor = Altera
		if (deviceString[0:2].lower() == "ep"):
			obj.vendor = PoCDevice.Vendors.Altera
			obj.generation = int(deviceString[2:3])

			temp = deviceString[3:4].lower()
			if	 (temp == "C"):	obj.family = PoCDevice.Families.Cyclon
			elif (temp == "S"):	obj.family = PoCDevice.Families.Stratix

#			deviceRegExpStr =  r"(?P<st1>[cfhlstx]{0,2})"			# device subtype - part 1
#			deviceRegExpStr += r"(?P<no>\d{1,4})"							# device number
#			deviceRegExpStr += r"(?P<st2>[t]{0,1})"						# device subtype - part 2
#			deviceRegExpStr += r"(?P<sg>[-1-3]{2})"						# speed grade
#			deviceRegExpStr += r"(?P<pack>[fg]{1,3})"					# package
#			deviceRegExpStr += r"(?P<pins>\d{1,4})"						# pin count
#			
#			deviceRegExp = re.compile(deviceRegExpStr)
#			deviceRegExpMatch = deviceRegExp.match(deviceString[4:].lower())
#
#			if (deviceRegExpMatch is not None):
#				print("dev subtype: %s%s" % (deviceRegExpMatch.group('st1'), deviceRegExpMatch.group('st2')))
	
	def shortName(obj):
		if (obj.vendor == PoCDevice.Vendors.Xilinx):
			subtype = obj.subtype.groups()
			return "xc%i%s%s%i%s" % (
				obj.generation,
				repr(obj.family),
				subtype[0],
				obj.number,
				subtype[1]
			)
		elif (obj.vendor == PoCDevice.Vendors.Altera):
			raise NotImplementedException("shortName() not implemented for vendor Altera")
			return "ep...."
	
	def fullName(obj):
		if (obj.vendor == PoCDevice.Vendors.Xilinx):
			subtype = obj.subtype.groups()
			return "xc%i%s%s%i%s%i%s%i" % (
				obj.generation,
				repr(obj.family),
				subtype[0],
				obj.number,
				subtype[1],
				obj.speedGrade,
				str(obj.package),
				obj.pinCount
			)
		elif (obj.vendor == PoCDevice.Vendors.Altera):
			raise NotImplementedException("fullName() not implemented for vendor Altera")
			return "ep...."
	
	def __str__(obj):
		return obj.fullName()
	
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
		
		splitList2 = namespacePart.split('.')
		print("len2: %i" % len(splitList2))
		if (splitList2[0] == "PoC"):
			self.parts = splitList2[1:]
		else:
			self.parts = splitList2
		
#		if (not self.host.pocStructure.has_option('NamespaceDirectoryNames', str(self))):
#			raise PoCException("Namespace or entity '%s' does not exist." % str(self))
		
				
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
