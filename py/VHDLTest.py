 
from enum      import Enum, unique		# EnumMeta
from time      import time
from colorama  import init, Fore

from Parser.VHDLParser import VHDL, EmptyLineBlock, IndentationBlock, CommentBlock
from lib.CodeDOM import CodeDOMObject
from lib.Functions import Init
from lib.Parser import MatchingParserResult, SpaceToken, CharacterToken, MismatchingParserResult, StringToken, NumberToken, ParserException

from lib.Parser     import Tokenizer

init(convert=True)

DEBUG =   True
DEBUG2 =  True

print("{RED}{line}{NOCOLOR}".format(line="="*160, **Init.Foreground))

content = """\
-- one first comment line
-- a second comment line
	-- the third comment

library ieee;
use     ieee.std_logic_1164.all;
  use   ieee.numeric_std.all;
				
entity test is
	generic (
		BITS  : integer range 0 to 15;
		DEPTH : natural := 5
	);
	port (
		Clock    : in	 std_logic;
		Reset
		  : in  std_logic;
		ClockDiv : out
									 std_logic_vector(8-1 downto 0)
	);
end entity;
--		Clock    : in	 std_logic;   -- a line comment
--		Reset    : in  std_logic;		-- 2. line comment
--		ClockDiv : out              -- bad comment
--									 std_logic_vector(8-1 downto 0)

architecture rtl of test is
--	subtype T_SLV is std_logic_vector(7 downto 0);
--  type T_STATE is (ST_IDLE, ST_FINISH);
--  type T_Record is record
--		Member1 : STD_LOGIC;
--		Member2 : BOOLEAN
--	end record;
begin

--	process(Clock)
--	begin
--		if (Reset = '1') then
--			-- foo
--		end if;
--	end process;
end architecture;
""".replace("\r\n", "\n") # make it universal newline compatible

wordTokenStream = Tokenizer.GetWordTokenizer(content, alphaCharacters=Tokenizer.__ALPHA_CHARS__+"_")
vhdlBlockStream = VHDL.TransformTokensToBlocks(wordTokenStream)

try:
	for vhdlBlock in vhdlBlockStream:
		if isinstance(vhdlBlock, (EmptyLineBlock, IndentationBlock)):
			print("{DARK_GRAY}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
		elif isinstance(vhdlBlock, CommentBlock):
			print("{DARK_GREEN}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
		else:
			print("{YELLOW}{block}{NOCOLOR}".format(block=vhdlBlock, **Init.Foreground))
except ParserException as ex:
	print("ERROR: " + str(ex))
except NotImplementedError as ex:
	print("NotImplementedError: " + str(ex))

#
#
# class List(CodeDOMObject):
# 	def __init__(self):
# 		super().__init__()
# 		self._list = []
#
# 	@classmethod
# 	def GetSemicolonListParser(cls, result, element):
# 		if DEBUG: print("init SemicolonListParser")
#
# 		parser = element.GetParser()
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			result.AddElement(ex.value)
#
# 		while True:
# 			# match for optional whitespace
# 			token = yield
# 			if isinstance(token, SpaceToken):           token = yield
# 			# match for delimiter sign: ;
# 			if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 			if (token.Value.lower() != ";"):            raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 			# match for optional whitespace
# 			token = yield
# 			if isinstance(token, SpaceToken):           token = yield
# 			try:
# 				while True:
# 					token = yield
# 					parser.send(token)
# 			except MatchingParserResult as ex:
# 				result.AddElement(ex.value)
#
# 		# construct result
# 		if DEBUG: print("GetSemicolonListParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# class PortDefinition(CodeDOMObject):
# 	def __init__(self, name, mode, typeMark):
# 		super().__init__()
# 		self._name =      name
# 		self._mode =      mode
# 		self._typeMark =  typeMark
#
# 	@property
# 	def Name(self):
# 		return self._name
#
# 	@property
# 	def Mode(self):
# 		return self._mode
#
# 	@property
# 	def TypeMark(self):
# 		return self._typeMark
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init PortDefinitionParser")
#
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
#
# 		# match for name
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("PortListParser: Expected port name keyword.")
# 		name = token.Value
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
# 		# match for delimiter sign: (
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		if (token.Value != ":"):                    raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
# 		# match for mode
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("PortListParser: Expected port mode keyword.")
# 		mode = token.Value
# 		if (mode not in ["in", "out", "inout", "buffer"]):
# 			mode = "default"
# 		# match for whitespace
# 		token = yield
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult("PortListParser: Expected whitespace.")
# 		# match for type
# 		token = yield
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("PortListParser: Expected port mode keyword.")
# 		typeMark = token.Value
#
# 		# construct result
# 		result = cls(name, mode, typeMark)
# 		if DEBUG: print("PortListParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# class PortList(List):
# 	@property
# 	def Ports(self):
# 		return self._list
#
# 	def AddElement(self, value):
# 		self._list.append(value)
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init PortListParser")
#
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
#
# 		# match for keyword: PORT
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("PortListParser: Expected PORT keyword.")
# 		if (token.Value.lower() != "port"):         raise MismatchingParserResult("PortListParser: Expected PORT keyword.")
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
# 		# match for delimiter sign: (
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		if (token.Value.lower() != "("):            raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
#
# 		# construct result
# 		result = cls()
# 		parser = cls.GetSemicolonListParser(result, PortDefinition)
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			pass
#
# 		# match for delimiter sign: )
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		if (token.Value.lower() != ")"):            raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		# match for delimiter sign: ;
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
# 		if (token.Value.lower() != ";"):            raise MismatchingParserResult("PortListParser: Expected double quote sign before VHDL filename.")
#
# 		if DEBUG: print("PortListParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		return "{0}Verilog \"{1}\"".format(_indent, self._filename)
#
# class Statement(CodeDOMObject):
# 	def __init__(self):
# 		super().__init__()
#
# class EntityStatement(Statement):
# 	def __init__(self, name):
# 		super().__init__()
# 		self._name =    name
#
# 	@property
# 	def Name(self):
# 		return self._name
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init EntityParser")
#
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):
# 			token = yield
#
# 		if DEBUG2: print("EntityParser: token={0} expected ENTITY keyword".format(token.Value))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("EntityParser: Expected ENTITY keyword.")
# 		if (token.Value.lower() != "entity"):       raise MismatchingParserResult("EntityParser: Expected ENTITY keyword.")
#
# 		# match for whitespace
# 		token = yield
# 		if DEBUG2: print("EntityParser: token={0} expected WHITESPACE".format(token.Value))
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult("EntityParser: Expected whitespace before ENTITY name.")
#
# 		# match for entity name
# 		name = ""
# 		while True:
# 			token = yield
# 			if DEBUG2: print("EntityParser: token={0} collecting...".format(token.Value))
# 			if isinstance(token, StringToken):
# 				name += token.Value
# 			elif isinstance(token, NumberToken):
# 				name += token.Value
# 			elif isinstance(token, CharacterToken):
# 				# if (token.Value in [_]):
# 				if (token.Value == "_"):
# 					name += token.Value
# 				else:
# 					break
# 			else:
# 				break
#
# 		# match for whitespace
# 		if DEBUG2: print("EntityParser: token={0} expected WHITESPACE".format(token.Value))
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult("EntityParser: Expected whitespace before VHDL filename.")
#
# 		# match for IS keyword
# 		token = yield
# 		if DEBUG2: print("EntityParser: token={0} expected IS keyword".format(token.Value))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("EntityParser: Expected IS keyword.")
# 		if (token.Value.lower() != "is"):           raise MismatchingParserResult("EntityParser: Expected IS keyword.")
#
# 		# match for delimiter sign: \n
# 		token = yield
# 		if DEBUG2: print("EntityParser: token={0} expected NL".format(token.Value))
# 		if (not isinstance(token, CharacterToken)):  raise MismatchingParserResult("EntityParser: Expected end of line")
# 		if (token.Value.lower() != "\n"):            raise MismatchingParserResult("EntityParser: Expected end of line")
#
# 		parser = PortList.GetParser()
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			portList = ex.value
#
# 		genericList = None
#
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):
# 			token = yield
#
# 		if DEBUG2: print("EntityParser: token={0} expected END keyword".format(token.Value))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult("EntityParser: Expected END keyword.")
# 		if (token.Value.lower() != "end"):          raise MismatchingParserResult("EntityParser: Expected END keyword.")
#
# 		# # match for whitespace
# 		# token = yield
# 		# if DEBUG2: print("EntityParser: token={0} expected WHITESPACE".format(token.Value))
# 		# if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult("EntityParser: Expected whitespace before ENTITY name.")
#
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult("EntityParser: Expected ';'.")
# 		if (token.Value != ";"):                    raise MismatchingParserResult("EntityParser: Expected ';'.")
#
#
# 		# construct result
# 		result = cls(name, genericList, portList)
# 		if DEBUG: print("EntityParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		return "{0}VHDL {1} \"{2}\"".format(_indent, self._library, self._filename)
#
# class BlockedStatement(Statement):
# 	_allowedStatements = []
#
# 	def __init__(self):
# 		super().__init__()
#
# 	@classmethod
# 	def AddChoice(cls, value):
# 		cls._allowedStatements.append(value)
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init BlockedStatementParser")
# 		parser = cls.GetChoiceParser(cls._allowedStatements)
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG: print("BlockedStatementParser: matched {0}".format(ex.__class__.__name__))
# 			raise ex
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "BlockedStatement"
# 		for stmt in self._statements:
# 			buffer += "\n{0}".format(stmt.__str__(indent + 1))
# 		return buffer
#
# class BlockStatement(Statement):
# 	def __init__(self):
# 		super().__init__()
# 		self._statements = []
#
# 	def AddStatement(self, stmt):
# 		self._statements.append(stmt)
#
# 	@property
# 	def Statements(self):
# 		return self._statements
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "BlockStatement"
# 		for stmt in self._statements:
# 			buffer += "\n{0}".format(stmt.__str__(indent + 1))
# 		return buffer
#
# class ConditionalBlockStatement(BlockStatement):
# 	def __init__(self, expression):
# 		super().__init__()
# 		self._expression = expression
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "ConditionalBlockStatement " + self._expression.__str__()
# 		for stmt in self._statements:
# 			buffer += "\n{0}".format(stmt.__str__(indent + 1))
# 		return buffer
#
# class IfStatement(ConditionalBlockStatement):
# 	def __init__(self, expression):
# 		super().__init__(expression)
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init IfStatementParser")
#
# 		# match for IF clause
# 		# ==========================================================================
# 		# match for optional whitespace
# 		token = yield
# 		if DEBUG2: print("IfStatementParser: token={0} if".format(token))
# 		if isinstance(token, SpaceToken):
# 			token = yield
# 			if DEBUG2: print("IfStatementParser: token={0}".format(token))
#
# 		if DEBUG2: print("IfStatementParser: token={0}".format(token))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "if"):           raise MismatchingParserResult()
#
# 		# match for whitespace
# 		token = yield
# 		if DEBUG2: print("IfStatementParser: token={0}".format(token))
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult()
#
# 		# match for expression
# 		# ==========================================================================
# 		parser = Expressions.GetParser()
# 		parser.send(None)
#
# 		expressionRoot = None
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
# 			expressionRoot = ex.value
#
# 		# construct result
# 		result = cls(expressionRoot)
#
# 		# match for whitespace
# 		token = yield
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult()
#
# 		# match for keyword: THEN
# 		token = yield
# 		if DEBUG2: print("IfStatementParser: token={0}".format(token))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "then"):         raise MismatchingParserResult()
#
# 		# match for delimiter sign: \n
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "\n"):           raise MismatchingParserResult()
#
# 		# match for inner statements
# 		# ==========================================================================
# 		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			pass
# 			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
#
# 		if DEBUG: print("IfStatementParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "IfStatement " + self._expression.__str__()
# 		for stmt in self._statements:
# 			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
# 		return buffer
#
# class ElseIfStatement(ConditionalBlockStatement):
# 	def __init__(self, expression):
# 		super().__init__(expression)
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init ElseIfStatementParser")
#
# 		# match for multiple ELSEIF clauses
# 		# ==========================================================================
# 		token = yield
# 		# match for optional whitespace
# 		if DEBUG2: print("ElseIfStatementParser: token={0} elseif".format(token))
# 		if isinstance(token, SpaceToken):
# 			token = yield
# 			if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
#
# 		# match for keyword: ELSEIF
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "elsif"):        raise MismatchingParserResult()
# 		# match for whitespace
# 		token = yield
# 		if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult()
#
# 		# match for expression
# 		# ==========================================================================
# 		parser = Expressions.GetParser()
# 		parser.send(None)
#
# 		expressionRoot = None
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG2: print("IfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
# 			expressionRoot = ex.value
#
# 		# construct result
# 		result = cls(expressionRoot)
#
# 		# match for whitespace
# 		token = yield
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult()
#
# 		# match for keyword: THEN
# 		token = yield
# 		if DEBUG2: print("ElseIfStatementParser: token={0}".format(token))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "then"):         raise MismatchingParserResult()
#
# 		# match for delimiter sign: \n
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "\n"):           raise MismatchingParserResult()
#
# 		# match for inner statements
# 		# ==========================================================================
# 		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
# 		parser.send(None)
#
# 		statementList = None
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			pass
# 			if DEBUG2: print("ElseIfStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
#
# 		if DEBUG: print("ElseIfStatementParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "ElseIfStatement" + self._expression.__str__()
# 		for stmt in self._statements:
# 			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
# 		return buffer
#
# class ElseStatement(BlockStatement):
# 	def __init__(self):
# 		super().__init__()
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init ElseStatementParser")
#
# 		# match for ELSE clause
# 		# ==========================================================================
# 		# match for optional whitespace
# 		token = yield
# 		if DEBUG2: print("ElseStatementParser: token={0} else".format(token))
# 		if isinstance(token, SpaceToken):
# 			token = yield
# 			if DEBUG2: print("ElseStatementParser: token={0}".format(token))
#
# 		# match for keyword: ELSE
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "else"):         raise MismatchingParserResult()
#
# 		# match for delimiter sign: \n
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "\n"):           raise MismatchingParserResult()
#
# 		# match for inner statements
# 		# ==========================================================================
# 		# construct result
# 		result = cls()
# 		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
# 		parser.send(None)
#
# 		statementList = None
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			pass
# 			if DEBUG2: print("ElseStatementParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
#
# 		if DEBUG: print("ElseStatementParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "ElseStatement"
# 		for stmt in self._statements:
# 			buffer += "\n{1}".format(_indent, stmt.__str__(indent + 1))
# 		return buffer
#
# class IfElseIfElseStatement(Statement):
# 	def __init__(self):
# 		super().__init__()
# 		self._ifStatement =        None
# 		self._elseIfStatements =  None
# 		self._elseStatement =      None
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init IfElseIfElseStatementParser")
#
# 		# construct result
# 		result = cls()
#
# 		# match for IF clause
# 		# ==========================================================================
# 		parser = IfStatement.GetParser()
# 		parser.send(None)
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for IF clause".format(ex.__class__.__name__, ex.value))
# 			result._ifStatement = ex.value
#
# 		# match for multiple ELSEIF clauses
# 		# ==========================================================================
# 		try:
# 			while True:
# 				parser = ElseIfStatement.GetParser()
# 				parser.send(None)
#
# 				try:
# 					parser.send(token)
# 					while True:
# 						token = yield
# 						parser.send(token)
# 				except MatchingParserResult as ex:
# 					if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for ELSEIF clause".format(ex.__class__.__name__, ex.value))
# 					if (result._elseIfStatements is None):
# 						result._elseIfStatements = []
# 					result._elseIfStatements.append(ex.value)
# 		except MismatchingParserResult as ex:
# 			if DEBUG: print("IfElseIfElseStatementParser: mismatch {0} in ELSEIF clause. Message: {1}".format(ex.__class__.__name__, ex.value))
#
# 		# match for ELSE clause
# 		# ==========================================================================
# 		# match for inner statements
# 		parser = ElseStatement.GetParser()
# 		parser.send(None)
#
# 		try:
# 			parser.send(token)
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG: print("IfElseIfElseStatementParser: matched {0} got {1} for ELSE clause".format(ex.__class__.__name__, ex.value))
# 			result._elseStatement = ex.value
# 		except MismatchingParserResult as ex:
# 			if DEBUG: print("IfElseIfElseStatementParser: mismatch {0} in ELSE clause. Message: {1}".format(ex.__class__.__name__, ex.value))
#
# 		# match for END IF clause
# 		# ==========================================================================
# 		# match for optional whitespace
# 		if DEBUG2: print("IfElseIfElseStatementParser: token={0} end if".format(token))
# 		if isinstance(token, SpaceToken):
# 			token = yield
# 			if DEBUG2: print("IfElseIfElseStatementParser: token={0}".format(token))
#
# 		# match for keyword: END
# 		if DEBUG2: print("IfElseIfElseStatementParser: token={0} expected 'end'".format(token))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "end"):          raise MismatchingParserResult()
#
# 		# match for whitespace
# 		token = yield
# 		if (not isinstance(token, SpaceToken)):     raise MismatchingParserResult()
#
# 		# match for keyword: IF
# 		token = yield
# 		if DEBUG2: print("IfElseIfElseStatementParser: token={0}".format(token))
# 		if (not isinstance(token, StringToken)):    raise MismatchingParserResult()
# 		if (token.Value.lower() != "if"):           raise MismatchingParserResult()
#
# 		# match for delimiter sign: \n
# 		token = yield
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "\n"):           raise MismatchingParserResult()
#
# 		if DEBUG: print("IfElseIfElseStatementParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "IfElseIfElseStatement\n"
# 		buffer += self._ifStatement.__str__(indent + 1)
# 		if (self._elseIfStatements is not None):
# 			for elseIf in self._elseIfStatements:
# 				buffer += "\n" + elseIf.__str__(indent + 1)
# 		if (self._elseStatement is not None):
# 			buffer += "\n" + self._elseStatement.__str__(indent + 1)
# 		return buffer
#
# class EmptyLine(CodeDOMObject):
# 	def __init__(self):
# 		super().__init__()
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init EmptyLine")
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
# 		# match for delimiter sign: \n
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "\n"):           raise MismatchingParserResult()
# 		# construct result
# 		result = cls()
# 		if DEBUG: print("EmptyLine: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		return _indent + "<empty>"
#
# class CommentLine(CodeDOMObject):
# 	def __init__(self, commentText):
# 		super().__init__()
# 		self._commentText = commentText
#
# 	@property
# 	def Text(self):
# 		return self._commentText
#
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init CommentLineParser")
# 		# match for optional whitespace
# 		token = yield
# 		if isinstance(token, SpaceToken):           token = yield
# 		# match for sign: -
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "-"):            raise MismatchingParserResult()
# 		# match for sign: -
# 		if (not isinstance(token, CharacterToken)): raise MismatchingParserResult()
# 		if (token.Value.lower() != "-"):            raise MismatchingParserResult()
# 		# match for any until line end
# 		commentText = ""
# 		while True:
# 			token = yield
# 			if isinstance(token, CharacterToken):
# 				if (token.Value == "\n"):    break
# 			commentText += token.Value
# 		# construct result
# 		result = cls(commentText)
# 		if DEBUG: print("CommentLineParser: matched {0}".format(result))
# 		raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		return "{0}#{1}".format(_indent, self._commentText)
#
# class Document(BlockStatement):
# 	@classmethod
# 	def GetParser(cls):
# 		if DEBUG: print("init DocumentParser")
#
# 		result = cls()
# 		parser = cls.GetRepeatParser(result.AddStatement, BlockedStatement.GetParser)
# 		parser.send(None)
#
# 		try:
# 			while True:
# 				token = yield
# 				parser.send(token)
# 		except MatchingParserResult as ex:
# 			if DEBUG: print("DocumentParser: matched {0} got {1}".format(ex.__class__.__name__, ex.value))
# 			raise MatchingParserResult(result)
#
# 	def __str__(self, indent=0):
# 		_indent = "  " * indent
# 		buffer = _indent + "Document"
# 		for stmt in self._statements:
# 			buffer += "\n{0}".format(stmt.__str__(indent + 1))
# 		return buffer
#
# BlockedStatement.AddChoice(EntityStatement)
# # BlockedStatement.AddChoice(IfElseIfElseStatement)
# BlockedStatement.AddChoice(CommentLine)
# BlockedStatement.AddChoice(EmptyLine)
#
#
#
# _input = input
#
# def main():
# 	print("="*80)
# 	# print(_input)
# 	try:
# 		startTime = time()
# 		tree = Document.parse(_input, printChar= True)
# 		endTime = time()
# 		print("="*80)
# 		print(tree)
# 		print("="*80)
# 		print("time={0}".format(endTime - startTime))
# 	except ParserException as ex:
# 		print(str(ex))
#
#
# if (__name__ == "__main__"):
# 	main()
#
# #parserTree.render(view=True)
