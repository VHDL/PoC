 
from enum			import Enum, unique		# EnumMeta
from time			import time
from colorama	import init, Fore

init(convert=True)

DEBUG =		not True
DEBUG2 =	not True

class ParserException(Exception):
	pass

class MismatchingParserResult(StopIteration):							pass
class EmptyChoiseParserResult(MismatchingParserResult):		pass
class MatchingParserResult(StopIteration):								pass
class LastMatchingParserResult(MatchingParserResult):			pass
class CollectedParserResult(MatchingParserResult):				pass

class SourceCodePosition:
	def __init__(self, row, column, absolute):
		self._row =				row
		self._column =		column
		self._absolute =	absolute
	
	@property
	def Row(self):
		return self._row
	
	@Row.setter
	def Row(self, value):
		self._row = value
	
	@property
	def Column(self):
		return self._column
	
	@Column.setter
	def Column(self, value):
		self._column = value
	
	@property
	def Absolute(self):
		return self._absolute
	
	@Absolute.setter
	def Absolute(self, value):
		self._absolute = value

class Token:
	def __init__(self, value, start, end=None):
		self._value =	value
		self._start =	start
		self._end =		end

	def __len__(self):
		return self._end.Absolute - self._start.Absolute + 1
		
	@property
	def Value(self):
		return self._value
	
	@property
	def Start(self):
		return self._start
	
	@property
	def End(self):
		return self._end
	
	@property
	def Length(self):
		return len(self)

class CharacterToken(Token):
	def __init__(self, value, start):
		if (len(value) != 1):		raise ValueError()
		self._value =	value
		self._start =	start
		self._end =		start

	def __len__(self):
		return 1
		
	def __str__(self):
		if (self._value == "\r"):
			return "<CharacterToken char=CR at pos={0}; line={1}; col={2}>".format(self._start.Absolute, self._start.Row, self._start.Column)
		elif (self._value == "\n"):
			return "<CharacterToken char=NL at pos={0}; line={1}; col={2}>".format(self._start.Absolute, self._start.Row, self._start.Column)
		elif (self._value == "\t"):
			return "<CharacterToken char=TAB at pos={0}; line={1}; col={2}>".format(self._start.Absolute, self._start.Row, self._start.Column)
		elif (self._value == " "):
			return "<CharacterToken char=SPACE at pos={0}; line={1}; col={2}>".format(self._start.Absolute, self._start.Row, self._start.Column)
		else:
			return "<CharacterToken char={0} at pos={1}; line={2}; col={3}>".format(self._value, self._start.Absolute, self._start.Row, self._start.Column)
	
	def __repr(self):
		if (self._value == "\r"):
			return "CR"
		elif (self._value == "\n"):
			return "NL"
		elif (self._value == "\t"):
			return "TAB"
		elif (self._value == " "):
			return "SPACE"
		else:
			return self._value
	
class SpaceToken(Token):
	def __str__(self):
		return "<SpaceToken '{0}'>".format(self._value)
		
class DelimiterToken(Token):
	def __str__(self):
		return "<DelimiterToken '{0}'>".format(self._value)
		
class NumberToken(Token):
	def __str__(self):
		return "<NumberToken '{0}'>".format(self._value)
		
class StringToken(Token):
	def __str__(self):
		return "<StringToken '{0}'>".format(self._value)

class Tokenizer:
	class TokenKind(Enum):
		SpaceChars =			0
		AlphaChars =			1
		NumberChars =			2
		DelimiterChars =	3
		OtherChars =			4

	@classmethod
	def GetCharacterTokenizer(cls, iterable):
		absolute =	0
		column =		0
		row =				1
		for char in iterable:
			absolute +=	1
			column +=		1
			yield CharacterToken(char, SourceCodePosition(row, column, absolute))
			if (char == "\n"):
				column =	0
				row +=		1
	
	@classmethod
	def GetWordTokenizer(cls, iterable):
		tokenKind =	cls.TokenKind.OtherChars
		start =			SourceCodePosition(1, 1, 1)
		end =				start
		buffer =		""
		absolute =	0
		column =		0
		row =				1
		for char in iterable:
			absolute +=	1
			column +=		1
			
			if (tokenKind is cls.TokenKind.SpaceChars):
				if ((char == " ") or (char == "\t")):
					buffer += char
				else:
					yield SpaceToken(buffer, start, end)
					
					if (char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):
						buffer = char
						tokenKind = cls.TokenKind.AlphaChars
					elif (char in "0123456789"):
						buffer = char
						tokenKind = cls.TokenKind.NumberChars
					else:
						tokenKind = cls.TokenKind.OtherChars
						yield CharacterToken(char, SourceCodePosition(row, column, absolute))
			elif (tokenKind is cls.TokenKind.AlphaChars):
				if (char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):
					buffer += char
				else:
					yield StringToken(buffer, start, end)
				
					if (char in " \t"):
						buffer = char
						tokenKind = cls.TokenKind.SpaceChars
					elif (char in "0123456789"):
						buffer = char
						tokenKind = cls.TokenKind.NumberChars
					else:
						tokenKind = cls.TokenKind.OtherChars
						yield CharacterToken(char, SourceCodePosition(row, column, absolute))
			elif (tokenKind is cls.TokenKind.NumberChars):
				if (char in "0123456789"):
					buffer += char
				else:
					yield NumberToken(buffer, start, end)
				
					if (char in " \t"):
						buffer = char
						tokenKind = cls.TokenKind.SpaceChars
					elif (char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):
						buffer = char
						tokenKind = cls.TokenKind.AlphaChars
					else:
						tokenKind = cls.TokenKind.OtherChars
						yield CharacterToken(char, SourceCodePosition(row, column, absolute))
			elif (tokenKind is cls.TokenKind.OtherChars):
				if (char in " \t"):
					buffer = char
					tokenKind = cls.TokenKind.SpaceChars
				elif (char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):
					buffer = char
					tokenKind = cls.TokenKind.AlphaChars
				elif (char in "0123456789"):
					buffer = char
					tokenKind = cls.TokenKind.NumberChars
				else:
					yield CharacterToken(char, SourceCodePosition(row, column, absolute))
			else:
				raise ParserException("Unknown state.")
			
			end.Row =				row
			end.Column =		column
			end.Absolute =	absolute
			
			if (char == "\n"):
				column =	0
				row +=		1
		# end for
	
class CodeDOMMeta(type):
	def parse(mcls, string):
		result = mcls()
		return result
	
	def GetSequenceParser(self):
		pass
		# print("GetSequenceParser")
	
	def GetChoiceParser(self, choices):
		if DEBUG: print("init ChoiceParser")
		parsers = []
		for choice in choices:
			# print("create parser for {0}".format(choice.__name__))
			parser = choice.GetParser()
			parser.send(None)
			tup = (choice, parser)
			parsers.append(tup)
			
		removeList =	[]
		while True:
			token = yield
			for parser in parsers:
				try:
					ret = parser[1].send(token)
				except MismatchingParserResult as ex:
					removeList.append(parser)
				except MatchingParserResult as ex:
					if DEBUG: print("ChoiceParser: found a matching choice")
					raise ex
			
			for parser in removeList:
				if DEBUG: print("deactivating parser for {0}".format(parser[0].__name__))
				parsers.remove(parser)
			removeList.clear()
			
			if (len(parsers) == 0):
				break
		
		if DEBUG: print("ChoiceParser: list of choices is empty -> no match found")
		raise EmptyChoiseParserResult("ChoiceParser: ")
		
	def GetRepeatParser(self, callback, generator):
		if DEBUG: print("init RepeatParser")
		parser = generator()
		parser.send(None)
		
		while True:
			token = yield
			try:
				ret = parser.send(token)
			except MismatchingParserResult as ex:
				break
			except MatchingParserResult as ex:
				if DEBUG: print("RepeatParser: found a statement")
				callback(ex.value)
				
				parser = generator()
				parser.send(None)
		
		if DEBUG: print("RepeatParser: repeat end")
		raise MatchingParserResult()
	

class CodeDOMObject(metaclass=CodeDOMMeta):
	def __init__(self):
		super().__init__()
		self._name =	None
	
	@property
	def Name(self):
		if (self._name is not None):
			return self._name
		else:
			return self.__class__.__name__

	@Name.setter
	def Name(self, value):
		self._name = value
	
	@classmethod
	def parse(cls, string, printChar):
		parser = cls.GetParser()
		parser.send(None)
		
		try:
			for token in Tokenizer.GetWordTokenizer(string):
				if printChar: print(Fore.LIGHTBLUE_EX + str(token) + Fore.RESET)
				parser.send(token)
			
			print("send empty token")
			parser.send(None)
		except MatchingParserResult as ex:
			return ex.value
		except MismatchingParserResult as ex:
			print("ERROR: {0}".format(ex.value))
		
		# print("close root parser")
		# parser.close()
		
class Statement(CodeDOMObject):
	def __init__(self):
		super().__init__()
	
class VHDLStatement(Statement):
	def __init__(self, library, filename):
		super().__init__()
		self._library =		library
		self._filename =	filename
	
	@property
	def Library(self):
		return self._library
		
	@property
	def Filename(self):
		return self._filename
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init VHDLParser")
	
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):
			token = yield
		
		if DEBUG2: print("VHDLParser: token={0} expected VHDL keyword".format(token.Value))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult("VHDLParser: Expected VHDL keyword.")
		if (token.Value.lower() != "vhdl"):					raise MismatchingParserResult("VHDLParser: Expected VHDL keyword.")
		
		# match for whitespace
		token = yield
		if DEBUG2: print("VHDLParser: token={0} expected WHITESPACE".format(token.Value))
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VHDLParser: Expected whitespace before VHDL library name.")
		
		# match for library name
		library = ""
		while True:
			token = yield
			if DEBUG2: print("VHDLParser: token={0} collecting...".format(token.Value))
			if isinstance(token, StringToken):
				library += token.Value
			elif isinstance(token, NumberToken):
				library += token.Value
			elif isinstance(token, CharacterToken):
				# if (token.Value in [_]):
				if (token.Value == "_"):
					library += token.Value
				else:
					break
			else:
				break
		
		# match for whitespace
		if DEBUG2: print("VHDLParser: token={0} expected WHITESPACE".format(token.Value))
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VHDLParser: Expected whitespace before VHDL filename.")
		
		# match for delimiter sign: "
		token = yield
		if DEBUG2: print("VHDLParser: token={0} expected double quote".format(token.Value))
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VHDLParser: Expected double quote sign before VHDL filename.")
		if (token.Value.lower() != "\""):						raise MismatchingParserResult("VHDLParser: Expected double quote sign before VHDL filename.")
		
		# match for string: filename
		filename = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\""):
					break
			filename += token.Value
		
		# match for delimiter sign: \n
		token = yield
		if DEBUG2: print("VHDLParser: token={0} expected NL".format(token.Value))
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VHDLParser: Expected end of line")
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult("VHDLParser: Expected end of line")
		
		# construct result
		result = cls(library, filename)
		if DEBUG: print("VHDLParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		return "{0}VHDL {1} \"{2}\"".format(_indent, self._library, self._filename)
	
class VerilogStatement(Statement):
	def __init__(self, filename):
		super().__init__()
		self._filename =	filename
	
	@property
	def Filename(self):
		return self._filename
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init VerilogParser")
	
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):
			token = yield
	
		# match for keyword: VERILOG
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult("VerilogParser: Expected VERILOG keyword.")
		if (token.Value.lower() != "verilog"):			raise MismatchingParserResult("VerilogParser: Expected VERILOG keyword.")
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult("VerilogParser: Expected whitespace before Verilog filename.")
		
		# match for delimiter sign: "
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VerilogParser: Expected double quote sign before VHDL filename.")
		if (token.Value.lower() != "\""):						raise MismatchingParserResult("VerilogParser: Expected double quote sign before VHDL filename.")
		
		# match for string: filename
		filename = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\""):
					break
			filename += token.Value
		
		# match for delimiter sign: \n
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult("VHDLParser: Expected end of line")
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult("VHDLParser: Expected end of line")
		
		# construct result
		result = cls(filename)
		if DEBUG: print("VerilogParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self, indent=0):
		_indent = "  " * indent
		return "{0}Verilog \"{1}\"".format(_indent, self._filename)


class Expressions(CodeDOMObject):
	_allowedExpressions = []

	def __init__(self):
		super().__init__()
	
	@classmethod
	def AddChoice(cls, value):
		cls._allowedExpressions.append(value)
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init ExpressionsParser")
		parser = cls.GetChoiceParser(cls._allowedExpressions)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG: print("ExpressionsParser: matched {0}".format(ex.__class__.__name__))
			raise ex
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "........."
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer
		
class Expression(CodeDOMObject):
	def __init__(self):
		super().__init__()

class Identifier(Expression):
	def __init__(self, name):
		super().__init__()
		self._name = name
	
	@property
	def Name(self):
		return self._name
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init IdentifierParser")
		
		# match for identifier name
		token = yield
		if DEBUG2: print("IdentifierParser: token={0} expected name".format(token))
		if (not isinstance(token, StringToken)):			raise MismatchingParserResult()
		name = token.Value
		
		# construct result
		result = cls(name)
		if DEBUG: print("IdentifierParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return self._name

class Literal(Expression):
	pass
		
class StringLiteral(Literal):
	def __init__(self, value):
		super().__init__()
		self._value = value
	
	@property
	def Value(self):
		return self._value
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init StringLiteralParser")
		
		# match for opening "
		token = yield
		if DEBUG2: print("StringLiteralParser: token={0} expected '\"'".format(token))
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "\""):											raise MismatchingParserResult()
		
		# match for string value
		value = ""
		while True:
			token = yield
			if isinstance(token, CharacterToken):
				if (token.Value == "\""):
					break
			value += token.Value
		
		# construct result
		result = cls(value)
		if DEBUG: print("StringLiteralParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "\"{0}\"".format(self._value)
		
class IntegerLiteral(Literal):
	def __init__(self, value):
		super().__init__()
		self._value = value
	
	@property
	def Value(self):
		return self._value
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init IntegerLiteralParser")
		
		# match for opening "
		token = yield
		if DEBUG2: print("IntegerLiteralParser: token={0} expected number".format(token))
		if (not isinstance(token, NumberToken)):			raise MismatchingParserResult()
		value = int(token.Value)
		
		# construct result
		result = cls(value)
		if DEBUG: print("IntegerLiteralParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return str(self._value)
		
class UnaryExpression(Expression):
	def __init__(self, child):
		super().__init__()
		self._child = child
	
	@property
	def Child(self):
		return self._child

class BinaryExpression(Expression):
	def __init__(self, leftChild, rightChild):
		super().__init__()
		self._leftChild =		leftChild
		self._rightChild =	rightChild
	
	@property
	def LeftChild(self):
		return self._leftChild
	
	@property
	def RightChild(self):
		return self._rightChild
		
	def __str__(self):
		return "({0} ?? {1})".format(self._leftChild.__str__(), self._rightChild.__str__())

class LogicalExpression(BinaryExpression):
	pass

class CompareExpression(BinaryExpression):
	pass

class EqualExpression(CompareExpression):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init EqualExpressionParser")
		
		# match for opening (
		token = yield
		if DEBUG2: print("EqualExpressionParser: token={0} expected '('".format(token))
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "("):											raise MismatchingParserResult()
		
		# match for optional whitespace
		token = yield
		if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("EqualExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			leftChild = ex.value
			
		# match for optional whitespace
		token = yield
		if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		
		# match for equal sign =
		if DEBUG2: print("EqualExpressionParser: token={0} expected '='".format(token))
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "="):											raise MismatchingParserResult()
		
		# match for optional whitespace
		token = yield
		if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("EqualExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			rightChild = ex.value
		
		# match for optional whitespace
		token = yield
		if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("EqualExpressionParser: token={0}".format(token))
		
		# match for closing )
		if DEBUG2: print("EqualExpressionParser: token={0} expected ')'".format(token))
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != ")"):											raise MismatchingParserResult()
	
		# construct result
		result = cls(leftChild, rightChild)
		if DEBUG: print("EqualExpressionParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "({0} = {1})".format(self._leftChild.__str__(), self._rightChild.__str__())
		
class UnequalExpression(CompareExpression):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init UnequalExpressionParser")
		
		# match for opening (
		token = yield
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "("):											raise MismatchingParserResult()
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("UnequalExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			leftChild = ex.value
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		# match for equal sign !
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "!"):											raise MismatchingParserResult()
		# match for equal sign =
		token = yield
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "="):											raise MismatchingParserResult()
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("UnequalExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			rightChild = ex.value
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		# match for closing )
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != ")"):											raise MismatchingParserResult()
		
		# construct result
		result = cls(leftChild, rightChild)
		if DEBUG: print("UnequalExpressionParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "({0} != {1})".format(self._leftChild.__str__(), self._rightChild.__str__())
		
class AndExpression(LogicalExpression):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init AndExpressionParser")
		
		# match for opening (
		token = yield
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "("):											raise MismatchingParserResult()
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("AndExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			leftChild = ex.value
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		# match for AND keyword
		token = yield
		if (not isinstance(token, StringToken)):			raise MismatchingParserResult()
		if (token.Value.lower() != "and"):						raise MismatchingParserResult()
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG2: print("AndExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			rightChild = ex.value
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		# match for closing )
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != ")"):											raise MismatchingParserResult()
		
		# construct result
		result = cls(leftChild, rightChild)
		if DEBUG: print("AndExpressionParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "({0} and {1})".format(self._leftChild.__str__(), self._rightChild.__str__())

class OrExpression(LogicalExpression):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init OrExpressionParser")
		
		# match for opening (
		token = yield
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "("):											raise MismatchingParserResult()
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("OrExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			leftChild = ex.value
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		# match for OR keyword
		token = yield
		if (not isinstance(token, StringToken)):			raise MismatchingParserResult()
		if (token.Value.lower() != "or"):							raise MismatchingParserResult()
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG2: print("OrExpressionParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			rightChild = ex.value
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		# match for closing )
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != ")"):											raise MismatchingParserResult()
		
		# construct result
		result = cls(leftChild, rightChild)
		if DEBUG: print("OrExpressionParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "({0} or {1})".format(self._leftChild.__str__(), self._rightChild.__str__())
		
class XorExpression(LogicalExpression):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init XorExpressionParser")
		
		# match for opening (
		token = yield
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != "("):											raise MismatchingParserResult()
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				parser.send(token)
				token = yield
		except MatchingParserResult as ex:
			if DEBUG2: print("XorExpression: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			leftChild = ex.value
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		# match for XOR keyword
		token = yield
		if (not isinstance(token, StringToken)):			raise MismatchingParserResult()
		if (token.Value.lower() != "xor"):						raise MismatchingParserResult()
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):				raise MismatchingParserResult()
		
		# match for sub expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG2: print("XorExpression: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			rightChild = ex.value
		
		# match for optional whitespace
		token = yield
		if isinstance(token, SpaceToken):							token = yield
		# match for closing )
		if (not isinstance(token, CharacterToken)):		raise MismatchingParserResult()
		if (token.Value != ")"):											raise MismatchingParserResult()
		
		# construct result
		result = cls(leftChild, rightChild)
		if DEBUG: print("XorExpressionParser: matched {0}".format(result))
		raise MatchingParserResult(result)
		
	def __str__(self):
		return "({0} xor {1})".format(self._leftChild.__str__(), self._rightChild.__str__())

Expressions.AddChoice(Identifier)
Expressions.AddChoice(StringLiteral)
Expressions.AddChoice(IntegerLiteral)
Expressions.AddChoice(AndExpression)
Expressions.AddChoice(OrExpression)
Expressions.AddChoice(XorExpression)
Expressions.AddChoice(EqualExpression)
Expressions.AddChoice(UnequalExpression)

class BlockedStatement(Statement):
	_allowedStatements = []

	def __init__(self):
		super().__init__()
	
	@classmethod
	def AddChoice(cls, value):
		cls._allowedStatements.append(value)
	
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init BlockedStatementParser")
		parser = cls.GetChoiceParser(cls._allowedStatements)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG: print("BlockedStatementParser: matched {0}".format(ex.__class__.__name__))
			raise ex
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "BlockedStatement"
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer
		
class BlockStatement(Statement):
	def __init__(self):
		super().__init__()
		self._statements = []
	
	def AddStatement(self, stmt):
		self._statements.append(stmt)
	
	@property
	def Statements(self):
		return self._statements
		
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "BlockStatement"
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer

class ConditionalBlockStatement(BlockStatement):
	def __init__(self, expression):
		super().__init__()
		self._expression = expression
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "ConditionalBlockStatement " + self._expression.__str__()
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer
		
class IfStatement(ConditionalBlockStatement):
	def __init__(self, expression):
		super().__init__(expression)

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init IfStatementParser")
	
		# match for IF clause
		# ==========================================================================
		# match for optional whitespace
		token = yield
		if DEBUG2: print("IfStatementParser: token={0} if".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("IfStatementParser: token={0}".format(token))
		
		if DEBUG2: print("IfStatementParser: token={0}".format(token))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "if"):						raise MismatchingParserResult()
		
		# match for whitespace
		token = yield
		if DEBUG2: print("IfStatementParser: token={0}".format(token))
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult()
		
		# match for expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		
		expressionRoot = None
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			expressionRoot = ex.value
		
		# construct result
		result = cls(expressionRoot)
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult()
		
		# match for keyword: THEN
		token = yield
		if DEBUG2: print("IfStatementParser: token={0}".format(token))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "then"):						raise MismatchingParserResult()
		
		# match for delimiter sign: \n
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		# match for inner statements
		# ==========================================================================
		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			pass
			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			
		if DEBUG: print("IfStatementParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "IfStatement " + self._expression.__str__()
		for stmt in self._statements:
			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
		return buffer

class ElseIfStatement(ConditionalBlockStatement):
	def __init__(self, expression):
		super().__init__(expression)

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init ElseIfStatementParser")
	
		# match for multiple ELSEIF clauses
		# ==========================================================================
		token = yield
		# match for optional whitespace
		if DEBUG2: print("ElseIfStatementParser: token={0} elseif".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
		
		# match for keyword: ELSEIF
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "elseif"):				raise MismatchingParserResult()
		# match for whitespace
		token = yield
		if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult()
		
		# match for expression
		# ==========================================================================
		parser = Expressions.GetParser()
		parser.send(None)
		
		expressionRoot = None
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			expressionRoot = ex.value
		
		# construct result
		result = cls(expressionRoot)
		
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult()
		
		# match for keyword: THEN
		token = yield
		if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "then"):						raise MismatchingParserResult()
		
		# match for delimiter sign: \n
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		# match for inner statements
		# ==========================================================================
		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
		parser.send(None)
		
		statementList = None
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			pass
			if DEBUG2: print("ElseIfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
		
		if DEBUG: print("ElseIfStatementParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "ElseIfStatement" + self._expression.__str__()
		for stmt in self._statements:
			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
		return buffer
		
class ElseStatement(BlockStatement):
	def __init__(self):
		super().__init__()

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init ElseStatementParser")
	
		# match for ELSE clause
		# ==========================================================================
		# match for optional whitespace
		token = yield
		if DEBUG2: print("ElseStatementParser: token={0} else".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("ElseStatementParser: token={0}".format(token))
	
		# match for keyword: ELSE
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "else"):					raise MismatchingParserResult()
		
		# match for delimiter sign: \n
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		# match for inner statements
		# ==========================================================================
		# construct result
		result = cls()
		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
		parser.send(None)
		
		statementList = None
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			pass
			if DEBUG2: print("ElseStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))

		if DEBUG: print("ElseStatementParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "ElseStatement"
		for stmt in self._statements:
			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
		return buffer
		
class IfElseIfElseStatement(Statement):
	def __init__(self):
		super().__init__()
		self._ifStatement =				None
		self._elseIfStatements =	None
		self._elseStatement =			None

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init IfElseIfElseStatementParser")
		
		# construct result
		result = cls()
	
		# match for IF clause
		# ==========================================================================
		parser = IfStatement.GetParser()
		parser.send(None)
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for IF clause".format(ex.__class__.__name__, ex.value))
			result._ifStatement = ex.value
		
		# match for multiple ELSEIF clauses
		# ==========================================================================
		try:
			while True:
				parser = ElseIfStatement.GetParser()
				parser.send(None)
				
				try:
					parser.send(token)
					while True:
						token = yield
						parser.send(token)
				except MatchingParserResult as ex:
					if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for ELSEIF clause".format(ex.__class__.__name__, ex.value))
					if (result._elseIfStatements is None):
						result._elseIfStatements = []
					result._elseIfStatements.append(ex.value)
		except MismatchingParserResult as ex:
			if DEBUG: print("IfElseIfElseStatementParser: mismatch {0} in ELSEIF clause. Message: {1}".format(ex.__class__.__name__, ex.value))
		
		# match for ELSE clause
		# ==========================================================================
		# match for inner statements
		parser = ElseStatement.GetParser()
		parser.send(None)
			
		try:
			parser.send(token)
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for ELSE clause".format(ex.__class__.__name__, ex.value))
			result._elseStatement = ex.value
		except MismatchingParserResult as ex:
			if DEBUG: print("IfElseIfElseStatementParser: mismatch {0} in ELSE clause. Message: {1}".format(ex.__class__.__name__, ex.value))
		
		# match for END IF clause
		# ==========================================================================
		# match for optional whitespace
		if DEBUG2: print("IfElseIfElseStatementParser: token={0} end if".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("IfElseIfElseStatementParser: token={0}".format(token))
	
		# match for keyword: END
		if DEBUG2: print("IfElseIfElseStatementParser: token={0} expected 'end'".format(token))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "end"):					raise MismatchingParserResult()
	
		# match for whitespace
		token = yield
		if (not isinstance(token, SpaceToken)):			raise MismatchingParserResult()
	
		# match for keyword: IF
		token = yield
		if DEBUG2: print("IfElseIfElseStatementParser: token={0}".format(token))
		if (not isinstance(token, StringToken)):		raise MismatchingParserResult()
		if (token.Value.lower() != "if"):						raise MismatchingParserResult()
		
		# match for delimiter sign: \n
		token = yield
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		if DEBUG: print("IfElseIfElseStatementParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "IfElseIfElseStatement\n"
		buffer += self._ifStatement.__str__(indent + 1)
		if (self._elseIfStatements is not None):
			for elseIf in self._elseIfStatements:
				buffer += "\n" + elseIf.__str__(indent + 1)
		if (self._elseStatement is not None):
			buffer += "\n" + self._elseStatement.__str__(indent + 1)
		return buffer

class EmptyLine(CodeDOMObject):
	def __init__(self):
		super().__init__()

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init EmptyLine")
	
		# match for optional whitespace
		token = yield
		if DEBUG2: print("EmptyLine: token={0}".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("EmptyLine: token={0}".format(token))
	
		# match for delimiter sign: \n
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "\n"):						raise MismatchingParserResult()
		
		# construct result
		result = cls()
		if DEBUG: print("EmptyLine: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		return _indent + "<empty>"

class CommentLine(CodeDOMObject):
	def __init__(self, commentText):
		super().__init__()
		self._commentText = commentText
	
	@property
	def Text(self):
		return self._commentText

	@classmethod
	def GetParser(cls):
		if DEBUG: print("init CommentLineParser")
	
		# match for optional whitespace
		token = yield
		if DEBUG2: print("CommentLineParser: token={0} end if".format(token))
		if isinstance(token, SpaceToken):
			token = yield
			if DEBUG2: print("CommentLineParser: token={0}".format(token))
	
		# match for sign: #
		if DEBUG2: print("CommentLineParser: token={0} expected '#'".format(token))
		if (not isinstance(token, CharacterToken)):	raise MismatchingParserResult()
		if (token.Value.lower() != "#"):						raise MismatchingParserResult()
	
		# match for any until line end
		commentText = ""
		while True:
			token = yield
			if DEBUG2: print("CommentLineParser: token={0} collecting...".format(token.Value))
			if isinstance(token, CharacterToken):
				if (token.Value == "\n"):
					break
			commentText += token.Value
		
		# construct result
		result = cls(commentText)
		if DEBUG: print("CommentLineParser: matched {0}".format(result))
		raise MatchingParserResult(result)
	
	def __str__(self, indent=0):
		_indent = "  " * indent
		return "{0}#{1}".format(_indent, self._commentText)
		
class Document(BlockStatement):
	@classmethod
	def GetParser(cls):
		if DEBUG: print("init DocumentParser")
		
		result = cls()
		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
		parser.send(None)
		
		try:
			while True:
				token = yield
				parser.send(token)
		except MatchingParserResult as ex:
			if DEBUG: print("DocumentParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
			raise MatchingParserResult(result)
		
	def __str__(self, indent=0):
		_indent = "  " * indent
		buffer = _indent + "Document"
		for stmt in self._statements:
			buffer += "\n{0}".format(stmt.__str__(indent + 1))
		return buffer
		
BlockedStatement.AddChoice(VHDLStatement)
BlockedStatement.AddChoice(VerilogStatement)
BlockedStatement.AddChoice(IfElseIfElseStatement)
BlockedStatement.AddChoice(CommentLine)
BlockedStatement.AddChoice(EmptyLine)
		
input = """vhdl poc \"file1.vhdl\"
vhdl poc \"file2.vhdl\"
vhdl poc \"file3.vhdl\"
if (Vendor = \"Xilinx\") then
  verilog \"file4.v\"
	if (Device = \"Virtex\") then
		verilog \"file5.v\"
	end if
  verilog \"file6.v\"
elseif (Vendor = \"Altera\") then
	vhdl test \"mytestbench.vhdl\"
	vhdl test \"mytb.vhdl\"
	if (Version = 2008) then
	  vhdl alt_mf \"altera.vhdl\"
	elseif (Version = 2002) then
		vhdl xil_foo \"unizeugs.vhdl\"
	end if
else
	vhdl osvvm \"Coverage.vhdl\"
end if
# my comment 1
vhdl boo \"blubs.vhdl\"
    # my comment 2

"""

_input = input * 100

def main():
	print("="*80)
	# print(_input)
	try:
		startTime = time()
		tree = Document.parse(_input, printChar= not True)
		endTime = time()
		print("="*80)
		print(tree)
		print("="*80)
		print("time={0}".format(endTime - startTime))
	except ParserException as ex:
		print(str(ex))


if (__name__ == "__main__"):
	main()
		
#parserTree.render(view=True)
