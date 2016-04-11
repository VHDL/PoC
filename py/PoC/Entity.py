# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
# 
# Python Class:			TODO
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

# entry point
from pathlib import Path

from Base.Exceptions import NotConfiguredException

if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module Base.Entity")


# load dependencies
from enum									import Enum, unique
from collections					import OrderedDict

#from Base.Exceptions			import CommonException
from Base.Configuration		import ConfigurationException


@unique
class EntityTypes(Enum):
	Unknown = 0
	Source = 1
	Testbench = 2
	NetList = 3

	def __str__(self):
		if   (self is EntityTypes.Unknown):		return "??"
		elif (self is EntityTypes.Source):		return "src"
		elif (self is EntityTypes.Testbench):	return "tb"
		elif (self is EntityTypes.NetList):		return "nl"

def _PoCEntityTypes_parser(cls, value):
	if not isinstance(value, str):
		return Enum.__new__(cls, value)
	else:
		# map strings to enum values, default to Unknown
		return {
			'src':			EntityTypes.Source,
			'tb':				EntityTypes.Testbench,
			'nl':				EntityTypes.NetList
		}.get(value,	EntityTypes.Unknown)

# override __new__ method in EntityTypes with _PoCEntityTypes_parser
setattr(EntityTypes, '__new__', _PoCEntityTypes_parser)


class PathElement:
	def __init__(self, host, name, configSection, parent):
		self.__name =					name
		self._host =					host
		self._configSection = configSection
		self.__parent =				parent

	@property
	def Name(self):
		return self.__name

	@property
	def Parent(self):
		return self.__parent

	def __str__(self):
		return self.__name

	def __str__(self):
		return "{0}.{1}".format(str(self.Parent), self.Name)

class Namespace(PathElement):
	def __init__(self, host, name, configSection, parent):
		super().__init__(host, name, configSection, parent)

		self._configSection = configSection

		self.__namespaces =		OrderedDict()
		self.__entities =			OrderedDict()

		self._Load()

	def _Load(self):
		for optionName in self._host.PoCConfig[self._configSection]:
			type = self._host.PoCConfig[self._configSection][optionName]
			if (type == "Namespace"):
				# print("loading namespace: {0}".format(optionName))
				section = self._configSection + "." + optionName
				ns = Namespace(host=self._host, name=optionName, configSection=section, parent=self)
				self.__namespaces[optionName] = ns
			elif (type == "Entity"):
				# print("loading entity: {0}".format(optionName))
				section = self._configSection.replace("NS", "IP") + "." + optionName
				ent = Entity(host=self._host, name=optionName, configSection=section, parent=self)
				self.__entities[optionName] = ent

	@property
	def Namespaces(self):
		return [ns for ns in self.__namespaces.values()]

	@property
	def NamespaceNames(self):
		return [nsName for nsName in self.__namespaces.keys()]

	def GetNamespaces(self):
		return self.__namespaces.values()

	def GetNamespaceNames(self):
		return self.__namespaces.keys()

	@property
	def Entities(self):
		return [ent for ent in self.__entities.values()]

	@property
	def EntityNames(self):
		return [entName for entName in self.__entities.keys()]

	def GetEntities(self):
		return self.__entities.values()

	def GetEntityNames(self):
		return self.__entities.keys()

	def __getitem__(self, key):
		try:
			return self.__namespaces[key]
		except:
			pass
		return self.__entities[key]


	def pprint(self, indent=0):
		__indent = "  " * indent
		buffer = "{0}{1}\n".format(__indent, self.Name)
		for ent in self.GetEntities():
			buffer += ent.pprint(indent + 1)
		for ns in self.GetNamespaces():
			buffer += ns.pprint(indent + 1)
		return buffer

class Root(Namespace):
	__POCRoot_Name =						"PoC"
	__POCRoot_SectionName =			"NS"

	def __init__(self, host):
		super().__init__(host, self.__POCRoot_Name, self.__POCRoot_SectionName, None)

	def __str__(self):
		return self.__POCRoot_Name

class WildCard(PathElement):
	pass

class Entity(PathElement):
	def __init__(self, host, name, configSection, parent):
		super().__init__(host, name, configSection, parent)

		self._vhdltb =	None
		self._cocotb =	None
		self._netlist =	None

		self._Load()

	@property
	def VHDLTestbench(self):
		if self._vhdltb is None:
			raise NotConfiguredException("No VHDL testbench configured for '{0!s}'.".format(self))
		return self._vhdltb

	@property
	def CocoTestbench(self):
		if self._cocotb is None:
			raise NotConfiguredException("No Cocotb testbench configured for '{0!s}'.".format(self))
		return self._cocotb

	@property
	def Netlist(self):
		if self._netlist is None:
			raise NotConfiguredException("No netlist configured for '{0!s}'.".format(self))
		return self._netlist

	def _Load(self):
		self._LoadVHDLTestbench()
		self._LoadCocotbTestbench()
		self._LoadNetlist()

	def _LoadVHDLTestbench(self):
		testbench = self._host.PoCConfig[self._configSection]["VHDLTestbench"]
		if (testbench == ""):
			raise ConfigurationException("IPCore '{0!s}' has a VHDL Testbench option, but it's empty.".format(self.Parent))
		if (testbench.lower() == "none"):
			return

		# print("found a testbench in '{0}' for '{1!s}'".format(testbench, self))
		self._vhdltb = VHDLTestbench(self._host, testbench)

	def _LoadCocotbTestbench(self):
		testbench = self._host.PoCConfig[self._configSection]["CocotbTestbench"]
		if (testbench == ""):
			raise ConfigurationException("IPCore '{0!s}' has a Cocotb Testbench option, but it's empty.".format(self.Parent))
		if (testbench.lower() == "none"):
			return

		# print("found a testbench in '{0}' for '{1!s}'".format(testbench, self))
		self._cocotb = CocoTestbench(self._host, testbench)

	def _LoadNetlist(self):
		netlist = self._host.PoCConfig[self._configSection]["Netlist"]
		if (netlist == ""):
			raise ConfigurationException("IPCore '{0!s}' has a Netlist option, but it's empty.".format(self))
		if (netlist.lower() == "none"):
			return

		# print("found a netlist in '{0}' for '{1!s}'".format(netlist, self.Parent))
		self._vhdltb = Netlist(self._host, netlist)

	def pprint(self, indent=0):
		__indent = "  " * indent
		buffer = "{0}Entity: {1}\n".format(__indent, self.Name)
		if (self._vhdltb is not None):
			buffer += self._vhdltb.pprint(indent + 1)
		if (self._cocotb is not None):
			buffer += self._cocotb.pprint(indent + 1)
		if (self._netlist is not None):
			buffer += self._netlist.pprint(indent + 1)
		return buffer

class Base:
	def __init__(self, host, sectionName):
		self._sectionName = sectionName
		self._host = host

		self._Load()

class Testbench(Base):
	def __init__(self, host, sectionName):
		self._moduleName =	""
		self._filesFile =		None

		super().__init__(host, sectionName)

	@property
	def ModuleName(self):		return self._moduleName
	@property
	def FilesFile(self):		return self._filesFile

	def _Load(self):
		self._moduleName =	self._host.PoCConfig[self._sectionName]["TestbenchModule"]
		self._filesFile =		Path(self._host.PoCConfig[self._sectionName]["FilesFile"])

	def __str__(self):
		return "Testbench\n"

	def pprint(self, indent):
		__indent = "  " * indent
		buffer  = "{0}Testbench:\n".format(__indent)
		buffer += "{0}  Files: {1!s}\n".format(__indent, self._filesFile)
		return buffer

class VHDLTestbench(Testbench):
	def __init__(self, host, sectionName):
		super().__init__(host, sectionName)

	def _Load(self):
		super()._Load()

	def __str__(self):
		return "VHDL Testbench\n"

	def pprint(self, indent):
		__indent = "  " * indent
		buffer = "{0}VHDL Testbench:\n".format(__indent)
		buffer += "{0}  Files: {1!s}\n".format(__indent, self._filesFile)
		return buffer

class CocoTestbench(Testbench):
	def __init__(self, host, sectionName):
		self._topLevel = ""
		super().__init__(host, sectionName)

	@property
	def TopLevel(self):
		return self._topLevel

	def _Load(self):
		super()._Load()
		self._topLevel =	self._host.PoCConfig[self._sectionName]["TopLevel"]

	def __str__(self):
		return "Cocotb Testbench\n"

	def pprint(self, indent):
		__indent = "  " * indent
		buffer = "{0}Cocotb Testbench:\n".format(__indent)
		buffer += "{0}  Files: {1!s}\n".format(__indent, self._filesFile)
		return buffer

class Netlist(Base):
	def __init__(self, host, sectionName):
		self._rulesFile =		None
		super().__init__(host, sectionName)

	@property
	def RulesFile(self):    return self._rulesFile

	def _Load(self):
		super()._Load()
		self._filesFile =		Path(self._host.PoCConfig[self._sectionName]["FilesFile"])

	def __str__(self):
		return "Netlist\n"

	def pprint(self, indent):
		__indent = "  " * indent
		buffer = "{0}Netlist:\n".format(__indent)
		buffer += "{0}  Files: {1!s}\n".format(__indent, self._filesFile)
		buffer += "{0}  Rules: {1!s}\n".format(__indent, self._rulesFile)
		return buffer

class FQN:
	def __init__(self, host, fqn, defaultType=EntityTypes.Source):
		self.__host =		host
		self.__type =		None
		self.__parts =	[]

		if (fqn is None):			raise ValueError("Parameter 'fqn' is None.")
		if (fqn == ""):				raise ValueError("Parameter 'fqn' is empty.")

		# extract EntityType
		splitList1 = fqn.split(':')
		if (len(splitList1) == 1):
			self.__type =	defaultType
			entity =			fqn
		elif (len(splitList1) == 2):
			self.__type =	EntityTypes(splitList1[0])
			entity =			splitList1[1]
		else:
			raise ValueError("Argument 'fqn' has to many ':' signs.")

		# extract parts
		parts = entity.split('.')
		if (parts[0].lower() == "poc"):
			parts = parts[1:]

		# check and resolve parts
		cur = self.__host.Root
		self.__parts.append(cur)
		for pos,part in enumerate(parts):
			pe = cur[part]
			self.__parts.append(pe)
			cur = pe

	def Root(self):
		return self.__host.Root
	
	@property
	def Entity(self):
		return self.__parts[-1]

	def GetEntities(self):
		if (self.__type is EntityTypes.Testbench):
			config = self.__host.PoCConfig
		elif (self.__type is EntityTypes.NetList):
			config = self.__host.PoCConfig

		entity = self.__parts[-1]
		if (not entity.IsStar):
			yield entity
		else:
			subns = self.__parts[-2]
			path =	str(subns) + "."
			for sectionName in config:
				if sectionName.startswith(path):
					if self.__host.PoCConfig.has_option('PoC.NamespacePrefixes', sectionName):
						continue
					fqn = FQN(self.__host, sectionName)
					yield fqn.Entity

	def __str__(self):
		return ".".join([p.Name for p in self.__parts])
