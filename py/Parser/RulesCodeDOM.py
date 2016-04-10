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
from lib.Parser import CodeDOMObject
from lib.Parser import MismatchingParserResult, MatchingParserResult
from lib.Parser import SpaceToken, CharacterToken, StringToken, NumberToken
from lib.Parser import Statement, BlockStatement


class EmptyLine(CodeDOMObject):
	def __init__(self):
		super().__init__()

	@classmethod
	def GetParser(cls):
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield

		# match for delimiter sign: \n
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		# construct result
		result = cls()
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		return "  " * indent + "<empty>"


class CommentLine(CodeDOMObject):
	def __init__(self, commentText):
		super().__init__()
		self._commentText = commentText
	
	@property
	def Text(self):
		return self._commentText

	@classmethod
	def GetParser(cls):
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield

		# match for sign: #
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "#"):						raise MismatchingParserResult()
	
		# match for any until line end
		commentText = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\n"):			break
			commentText += token.Value
		
		# construct result
		result = cls(commentText)
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		return "{0}#{1}".format("  " * indent, self._commentText)

# ==============================================================================
# Blocked Statements (Forward declaration)
# ==============================================================================
class ProcessStatements(Statement):
	_allowedStatements = []

	@classmethod
	def AddChoice(cls, value):
		cls._allowedStatements.append(value)
	
	@classmethod
	def GetParser(cls):
		return cls.GetChoiceParser(cls._allowedStatements)

class DocumentStatements(Statement):
	_allowedStatements = []

	@classmethod
	def AddChoice(cls, value):
		cls._allowedStatements.append(value)

	@classmethod
	def GetParser(cls):
		return cls.GetChoiceParser(cls._allowedStatements)

# ==============================================================================
# File Reference Statements
# ==============================================================================
class CopyStatement(Statement):
	def __init__(self, libraryName, fileName, commentText):
		super().__init__()
		self._libraryName =	libraryName
		self._fileName =		fileName
		self._commentText =	commentText
	
	@property
	def LibraryName(self):
		return self._libraryName
		
	@property
	def FileName(self):
		return self._fileName
	
	@classmethod
	def GetParser(cls):
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield

		# match for VHDL keyword
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult("VHDLParser: Expected VHDL keyword.")
		if (token.Value.lower() != "vhdl"):					raise MismatchingParserResult("VHDLParser: Expected VHDL keyword.")

		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VHDLParser: Expected whitespace before VHDL library name.")

		# match for library name
		library = ""
		while True:
			token = yield
			if isinstance(token, StringToken):				library += token.Value
			elif isinstance(token, NumberToken):			library += token.Value
			elif (isinstance(token, CharacterToken) and  (token.Value == "_")):
				library += token.Value
			else:
				break

		# match for whitespace
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VHDLParser: Expected whitespace before VHDL fileName.")

		# match for delimiter sign: "
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VHDLParser: Expected double quote sign before VHDL fileName.")
		if (token.Value.lower() != "\""):						raise MismatchingParserResult("VHDLParser: Expected double quote sign before VHDL fileName.")

		# match for string: fileName
		fileName = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\""):
					break
			fileName += token.Value

		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield
		# match for delimiter sign: \n
		commentText = ""
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VHDLParser: Expected end of line or comment")
		if (token.Value == "\n"):
			pass
		elif (token.Value == "#"):
			# match for any until line end
			while True:
				token = yield
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"): break
				commentText += token.Value
		else:
			raise MismatchingParserResult("VHDLParser: Expected end of line or comment")
		
		# construct result
		result = cls(library, fileName, commentText)
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		if (self._commentText != ""):
			return "{0}VHDL {1} \"{2}\" # {3}".format(("  " * indent), self._libraryName, self._fileName, self._commentText)
		else:
			return "{0}VHDL {1} \"{2}\"".format(("  " * indent), self._libraryName, self._fileName)


class ReplaceStatement(Statement):
	def __init__(self, fileName, commentText):
		super().__init__()
		self._fileName =		fileName
		self._commentText =	commentText
	
	@property
	def FileName(self):
		return self._fileName
	
	@classmethod
	def GetParser(cls):
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):
			token = yield
	
		# match for keyword: VERILOG
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult("VerilogParser: Expected VERILOG keyword.")
		if (token.Value.lower() != "verilog"):			raise MismatchingParserResult("VerilogParser: Expected VERILOG keyword.")
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VerilogParser: Expected whitespace before Verilog fileName.")
		
		# match for delimiter sign: "
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VerilogParser: Expected double quote sign before Verilog fileName.")
		if (token.Value.lower() != "\""):						raise MismatchingParserResult("VerilogParser: Expected double quote sign before Verilog fileName.")
		
		# match for string: fileName
		fileName = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\""):
					break
			fileName += token.Value

		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield
		# match for delimiter sign: \n
		commentText = ""
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VerilogParser: Expected end of line or comment")
		if (token.Value == "\n"):
			pass
		elif (token.Value == "#"):
			# match for any until line end
			while True:
				token = yield
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"):		break
				commentText += token.Value
		else:
			raise MismatchingParserResult("VerilogParser: Expected end of line or comment")
		
		# construct result
		result = cls(fileName, commentText)
		raise MatchingParserResult(result)
		
	def __str__(self, indent=0):
		return "{0}Verilog \"{1}\"".format("  " * indent, self._fileName)

# ==============================================================================
# Block Statements
# ==============================================================================
class PreProcessStatement(BlockStatement):
	def __init__(self, commentText):
		super().__init__()
		self._commentText =	commentText

	@classmethod
	def GetParser(cls):
		# match for ELSE clause
		# ==========================================================================
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield

		# match for keyword: ELSE
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "else"):					raise MismatchingParserResult()
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield
		# match for delimiter sign: \n
		commentText = ""
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("ElseStatementParser: Expected end of line or comment")
		if (token.Value == "\n"):
			pass
		elif (token.Value == "#"):
			# match for any until line end
			while True:
				token = yield
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"): break
				commentText += token.Value
		else:
			raise MismatchingParserResult("ElseStatementParser: Expected end of line or comment")
		
		# match for inner statements
		# ==========================================================================
		# construct result
		result = cls(commentText)
		parser = cls.GetRepeatParser(result.AddStatement, ProcessStatements.GetParser)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult:
			raise MatchingParserResult(result)

	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "ElseStatement"
		for stmt in self._statements:
			buffer += "\n{0}{1}".format(_indent, stmt.__str__(indent + 1))
		return buffer

class PostProcessStatement(BlockStatement):
	def __init__(self, commentText):
		super().__init__()
		self._commentText =	commentText

	@classmethod
	def GetParser(cls):
		# match for ELSE clause
		# ==========================================================================
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield

		# match for keyword: ELSE
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "else"):					raise MismatchingParserResult()

		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):						token = yield
		# match for delimiter sign: \n
		commentText = ""
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("ElseStatementParser: Expected end of line or comment")
		if (token.Value == "\n"):
			pass
		elif (token.Value == "#"):
			# match for any until line end
			while True:
				token = yield
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"): break
				commentText += token.Value
		else:
			raise MismatchingParserResult("ElseStatementParser: Expected end of line or comment")

		# match for inner statements
		# ==========================================================================
		# construct result
		result = cls(commentText)
		parser = cls.GetRepeatParser(result.AddStatement, ProcessStatements.GetParser)
		parser.send(None)

		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult:
			raise MatchingParserResult(result)

	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "ElseStatement"
		for stmt in self._statements:
			buffer += "\n{0}{1}".format(_indent, stmt.__str__(indent + 1))
		return buffer

class Document(BlockStatement):
	@classmethod
	def GetParser(cls):
		result = cls()
		parser = cls.GetRepeatParser(result.AddStatement, DocumentStatements.GetParser)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		buffer = "  " * indent + "Document"
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer

ProcessStatements.AddChoice(CopyStatement)
ProcessStatements.AddChoice(ReplaceStatement)
ProcessStatements.AddChoice(CommentLine)
ProcessStatements.AddChoice(EmptyLine)

DocumentStatements.AddChoice(PreProcessStatement)
DocumentStatements.AddChoice(PostProcessStatement)
DocumentStatements.AddChoice(CommentLine)
DocumentStatements.AddChoice(EmptyLine)
