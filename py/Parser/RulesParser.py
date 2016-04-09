# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:					Patrick Lehmann
#
# Python Module:		TODO
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

from Parser.Parser				import ParserException
from Parser.FilesCodeDOM	import Document
from Parser.RulesCodeDOM	import PreProcessStatement, PostProcessStatement, CopyStatement, ReplaceStatement


class Rule:
	pass


class CopyRuleMixIn(Rule):
	pass


class ReplaceMixIn(Rule):
	pass


class RulesParserMixIn:
	_classCopyRule =						CopyRuleMixIn
	_classReplaceRule =					ReplaceMixIn

	def __init__(self):
		self._rootDirectory =			None
		self._document =					None
		
		self._preProcessRules =		[]
		self._postProcessRules =	[]

	def _Parse(self):
		self._ReadContent()
		self._document = Document.parse(self._content, printChar=not True)
		# print(Fore.LIGHTBLACK_EX + str(self._document) + Fore.RESET)
		
	def _Resolve(self, statements=None):
		# print("Resolving {0}".format(str(self._file)))
		if (statements is None):
			statements = self._document.Statements
		
		for stmt in statements:
			if isinstance(stmt, PreProcessStatement):
				file =						self._rootDirectory / stmt.FileName
				vhdlSrcFile =			self._classVHDLSourceFile(file, stmt.LibraryName)		# stmt.Library, 
				self._files.append(vhdlSrcFile)
			elif isinstance(stmt, PostProcessStatement):
				file =						self._rootDirectory / stmt.FileName
				verilogSrcFile =	self._classVerilogSourceFile(file)
				self._files.append(verilogSrcFile)
			elif isinstance(stmt, CopyStatement):
				lib =					self._rootDirectory / stmt.DirectoryName
				vhdlLibRef =	VHDLLibraryReference(stmt.Library, lib)
				self._libraries.append(vhdlLibRef)
			elif isinstance(stmt, ReplaceStatement):
				lib = self._rootDirectory / stmt.DirectoryName
				vhdlLibRef = VHDLLibraryReference(stmt.Library, lib)
				self._libraries.append(vhdlLibRef)
			else:
				ParserException("Found unknown statement type '{0}'.".format(stmt.__class__.__name__))
	
	@property
	def PreProcessRules(self):		return self._preProcessRules
	@property
	def PostProcessRules(self):		return self._postProcessRules

	def __str__(self):		return "RULES file: '{0!s}'".format(self._file)
	def __repr__(self):		return self.__str__()
