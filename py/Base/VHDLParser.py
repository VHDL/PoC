# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Module:		TODO
# 
# Authors:				 	Patrick Lehmann
# 
# Description:
# ------------------------------------
#		TODO:
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
from re								import compile	as RegExpCompile
from re								import sub			as RegExpSubstitute
from re								import MULTILINE, IGNORECASE, DOTALL

def StripComments(content):
	return RegExpSubstitute(r"--[^\n]*", "", content)

class RegExpException(Exception):
	pass
	
class ParserException(Exception):
	pass

class VHDLParserMixIn:
	def __init__(self):
		self._packages =								[]
		self._packageBodies =						[]
		self._entities =								[]
		self._architectures =						[]
		self._contexts =								[]
		self._componentInstantiations =	[]
		self._configurations =					[]
		self._references =							[]

	def _Parse(self):
		self._ReadContent()
		
		self._packages =								[x for x in VHDLPackage.Parse(self._content)]
		self._packageBodies =						[x for x in VHDLPackageBody.Parse(self._content)]
		self._entities =								[x for x in VHDLEntity.Parse(self._content)]
		self._architectures =						[x for x in VHDLArchitecture.Parse(self._content)]
		
	def pprint(self, prefix=""):
		buffer =	"VHDL file: {0}\n".format(self._file)
		buffer += prefix + "Packages:\n"
		for package in self._packages:
			buffer +=	prefix + "  {0}\n".format(package.Identifier)
			for subType in package.SubTypes:
				buffer +=	prefix + "    {0}\n".format(subType.Identifier)
		buffer += prefix + "Package Bodies:\n"
		for packageBody in self._packageBodies:
			buffer +=	prefix + "  {0}\n".format(packageBody.Identifier)
			for subType in packageBody.SubTypes:
				buffer +=	prefix + "    {0}\n".format(subType.Identifier)
		buffer += prefix + "Entities:\n"
		for entity in self._entities:
			buffer +=	prefix + "  {0}\n".format(entity.Identifier)
		buffer += prefix + "Architectures:\n"
		for architecture in self._architectures:
			buffer +=	prefix + "  {0}\n".format(architectuIdentifier)
			for subType in architecture.SubTypes:
				buffer +=	prefix + "    {0}\n".format(subType.Identifier)
		return buffer
		
class VHDLBase:
	pass

class VHDLPackage(VHDLBase):
	def __init__(self, identifier, subTypes):
		self._identifier = identifier
		
		self._subTypes =					subTypes
		self._arrayTypes =				[]
		self._enumerationTypes =	[]
		self._recordTypes =				[]
		self._physicalTypes =			[]
	
	@property
	def Identifier(self):
		return self._identifier
		
	@property
	def SubTypes(self):
		return self._subTypes

	_beginPattern =	r"\bpackage\s+(?P<PackageName>[a-zA-Z][\w]*)\s+is"
	_endPattern =		r"\bend\s+package(\s+(?P<PackageName>[a-zA-Z][\w]*))?\s*;"
	# _endPattern =		r"\bend(\s+package)?(\s+(?P<PackageName>[a-zA-Z][\w]*))\s*;"
	_beginRegexp =	RegExpCompile(_beginPattern,	MULTILINE | IGNORECASE | DOTALL)
	_endRegexp =		RegExpCompile(_endPattern,		MULTILINE | IGNORECASE | DOTALL)
	
	@classmethod
	def PreParse(cls, content):
		beginMatches = cls._beginRegexp.finditer(content)
		for beginMatch in beginMatches:
			beginPackageName = beginMatch.group('PackageName')
			remainingContent = content[beginMatch.start():]
			endMatch = cls._endRegexp.search(remainingContent)
			if endMatch:
				endPackageName = endMatch.group('PackageName')
				if ((endPackageName is not None) and (beginPackageName != endPackageName)):
					raise ParserException("Package name mismatch. Package name '{0}'; End label '{1}'".format(beginPackageName, endPackageName))
				yield (beginPackageName, remainingContent[:endMatch.end()])
			else:
				raise ParserException("No 'end package' found.")
	
	@classmethod
	def Parse(cls, content):
		for packageName,packageContent in cls.PreParse(content):
			subTypes = [x for x in VHDLSubType.Parse(packageContent)]
			
			yield cls(
				identifier=packageName,
				subTypes=subTypes
			)
		
class VHDLPackageBody(VHDLBase):
	def __init__(self, identifier, subTypes):
		self._identifier =	identifier
		
		self._subTypes =		subTypes
	
	@property
	def Identifier(self):
		return self._identifier
	
	@property
	def SubTypes(self):
		return self._subTypes
	
	_beginPattern =	r"\bpackage\s+body\s+(?P<PackageName>[a-zA-Z][\w]*)\s+is"
	_endPattern =		r"\bend\s+package\s+body(\s+(?P<PackageName>[a-zA-Z][\w]*))?\s*;"
	# _endPattern =		r"\bend(\s+package)?(\s+body)?(\s+(?P<PackageName>[a-zA-Z][\w]*))\s*;"
	_beginRegexp =	RegExpCompile(_beginPattern,	MULTILINE | IGNORECASE | DOTALL)
	_endRegexp =		RegExpCompile(_endPattern,		MULTILINE | IGNORECASE | DOTALL)
	
	@classmethod
	def PreParse(cls, content):
		beginMatches = cls._beginRegexp.finditer(content)
		for beginMatch in beginMatches:
			beginPackageName = beginMatch.group('PackageName')
			remainingContent = content[beginMatch.start():]
			endMatch = cls._endRegexp.search(remainingContent)
			if endMatch:
				endPackageName = endMatch.group('PackageName')
				if ((endPackageName is not None) and (beginPackageName != endPackageName)):
					raise ParserException("Package name mismatch. Package body name '{0}'; End label '{1}'".format(beginPackageName, endPackageName))
				yield (beginPackageName, remainingContent[:endMatch.end()])
			else:
				raise ParserException("No 'end package body' found.")
	
	@classmethod
	def Parse(cls, content):
		for packageBodyName,packageBodyContent in cls.PreParse(content):
			subTypes = [x for x in VHDLSubType.Parse(packageBodyContent)]
			
			yield cls(
				identifier=packageBodyName,
				subTypes=subTypes
			)
	
class VHDLEntity(VHDLBase):
	def __init__(self, identifier):
		self._identifier = identifier
	
	_beginPattern =	r"\bentity\s+(?P<EntityName>[a-zA-Z][\w]*)\s+is"
	_endPattern =		r"\bend\s+entity(\s+(?P<EntityName>[a-zA-Z][\w]*))?\s*;"
	# _endPattern =		r"\bend(\s+entity)?(\s+(?P<EntityName>[a-zA-Z][\w]*))\s*;"
	_beginRegexp =	RegExpCompile(_beginPattern,	MULTILINE | IGNORECASE | DOTALL)
	_endRegexp =		RegExpCompile(_endPattern,		MULTILINE | IGNORECASE | DOTALL)
	
	@property
	def Identifier(self):
		return self._identifier
	
	@classmethod
	def PreParse(cls, content):
		beginMatches = cls._beginRegexp.finditer(content)
		for beginMatch in beginMatches:
			beginEntityName = beginMatch.group('EntityName')
			remainingContent = content[beginMatch.start():]
			endMatch = cls._endRegexp.search(remainingContent)
			if endMatch:
				endEntityName = endMatch.group('EntityName')
				if ((endEntityName is not None) and (beginEntityName != endEntityName)):
					raise ParserException("Entity name mismatch. Entity name '{0}'; End label '{1}'".format(beginEntityName, endEntityName))
				yield (beginEntityName, remainingContent[:endMatch.end()])
			else:
				raise ParserException("No 'end entity' found.")
	
	@classmethod
	def Parse(cls, content):
		for entityName,entityContent in cls.PreParse(content):
			# subTypes = [x for x in VHDLSubType.Parse(entityContent)]
			
			yield cls(
				identifier=entityName
				# subTypes=subTypes
			)

class VHDLGeneric(VHDLBase):
	def __init__(self):
		pass
	
	@classmethod
	def Parse(cls, content):
		pass

class VHDLPort(VHDLBase):
	def __init__(self):
		pass
	
	@classmethod
	def Parse(cls, content):
		pass


class VHDLArchitecture(VHDLBase):
	def __init__(self, identifier, subTypes):
		self._identifier =	identifier
		self._subTypes =		subTypes
	
	_beginPattern =	r"\barchitecture\s+(?P<ArchitectureName>[a-zA-Z][\w]*)\s+(?P<EntityName>[a-zA-Z][\w]*)\s+is"
	_endPattern =		r"\bend\s+architecture(\s+(?P<ArchitectureName>[a-zA-Z][\w]*))?\s*;"
	# _endPattern =		r"\bend(\s+architecture)?(\s+(?P<ArchitectureName>[a-zA-Z][\w]*))\s*;"
	_beginRegexp =	RegExpCompile(_beginPattern,	MULTILINE | IGNORECASE | DOTALL)
	_endRegexp =		RegExpCompile(_endPattern,		MULTILINE | IGNORECASE | DOTALL)
	
	@property
	def Identifier(self):
		return self._identifier
	
	@classmethod
	def PreParse(cls, content):
		beginMatches = cls._beginRegexp.finditer(content)
		for beginMatch in beginMatches:
			beginArchitectureName = beginMatch.group('ArchitectureName')
			beginEntityName = beginMatch.group('EntityName')
			remainingContent = content[beginMatch.start():]
			endMatch = cls._endRegexp.search(remainingContent)
			if endMatch:
				endArchitectureName = endMatch.group('ArchitectureName')
				if ((endArchitectureName is not None) and (beginArchitectureName != endArchitectureName)):
					raise ParserException("Architecture name mismatch. Architecture name '{0}'; End label '{1}'".format(beginArchitectureName, endArchitectureName))
				yield (architectureName, remainingContent[:endMatch.end()])
			else:
				raise ParserException("No 'end architecture' found.")
	
	@classmethod
	def Parse(cls, content):
		for architectureName,architectureContent in cls.PreParse(content):
			# subTypes = [x for x in VHDLSubType.Parse(architectureContent)]
			
			yield cls(
				identifier=architectureName,
				subTypes=subTypes
			)


class VHDLContext(VHDLBase):
	def __init__(self):
		pass
	
	@classmethod
	def Parse(cls, content):
		pass

class VHDLSubType(VHDLBase):
	def __init__(self, identifier):
		self._identifier = identifier
	
	@property
	def Identifier(self):
		return self._identifier
	
	_pattern = r"\bsubtype\s+(?P<SubTypeName>[a-zA-Z][\w]*)\s+is"
	_regexp = RegExpCompile(_pattern, MULTILINE | IGNORECASE | DOTALL)
	
	@classmethod
	def Parse(cls, content):
		matches = cls._regexp.finditer(content)
		for match in matches:
			subTypeName = match.group('SubTypeName')
			yield cls(
				identifier=subTypeName
			)
