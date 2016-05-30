from collections import deque
from enum import Enum

from lib.Parser     import ValuedToken, CharacterToken, StringToken, ParserException, SpaceToken


class VHDLToken(ValuedToken):
	pass

class KeywordToken(VHDLToken):
	__KEYWORD__ = None

	def __init__(self, stringToken):
		if (stringToken.Value.lower() != self.__KEYWORD__):
			raise ParserException("Expected keyword {0}.".format(self.__KEYWORD__.upper()))
		super().__init__(stringToken.PreviousToken, self.__KEYWORD__, stringToken.Start, stringToken.End)

	def __str__(self):
		return "<Keyword: {0}>".format(self.__KEYWORD__.upper())

class CommentKeyword(VHDLToken):
	__KEYWORD__ = "--"

	def __init__(self, characterToken):
		super().__init__(characterToken.PreviousToken, self.__KEYWORD__, characterToken.Start, characterToken.NextToken.End)

class CommentToken(VHDLToken):
	def __init__(self, commentKeyword):
		super().__init__(commentKeyword.PreviousToken, None, commentKeyword.Start)

class IdentifierToken(VHDLToken):
	def __init__(self, stringToken):
		super().__init__(stringToken.PreviousToken, stringToken.Value, stringToken.Start, stringToken.End)

	def __str__(self):
		return "<Identifier '{value}' at {line}:{col}>".format(
			value=self.Value, pos=self.Start.Absolute, line=self.Start.Row, col=self.Start.Column)

class DelimiterToken(ValuedToken):
	def __init__(self, characterToken):
		super().__init__(characterToken.PreviousToken, characterToken.Value, characterToken.Start, characterToken.End)

	def __str__(self):
		return "<DelimiterToken '{value}' at {line}:{col}>".format(
						value=self.Value, pos=self.Start.Absolute, line=self.Start.Row, col=self.Start.Column)

class LibraryKeyword(KeywordToken):
	__KEYWORD__ = "library"

class UseKeyword(KeywordToken):
	__KEYWORD__ = "use"

class EntityKeyword(KeywordToken):
	__KEYWORD__ = "entity"

class IsKeyword(KeywordToken):
	__KEYWORD__ = "is"

class GenericKeyword(KeywordToken):
	__KEYWORD__ = "generic"

class PortKeyword(KeywordToken):
	__KEYWORD__ = "port"

class ArchitectureKeyword(KeywordToken):
	__KEYWORD__ = "architecture"

class BeginKeyword(KeywordToken):
	__KEYWORD__ = "begin"

class EndKeyword(KeywordToken):
	__KEYWORD__ = "end"


class Block(object):
	def __init__(self, previousBlock, startToken, endToken=None, multiPart=False):
		previousBlock.NextBlock = self
		self._previousBlock =     previousBlock
		self._nextBlock =         None
		self.StartToken =         startToken
		self._endToken =          endToken
		self.MultiPart =          multiPart

	def __len__(self):
		return self.EndToken.End.Absolute - self.StartToken.Start.Absolute + 1

	def __iter__(self):
		token = self.StartToken
		while (token is not self.EndToken):
			yield token
			if (token.NextToken is None):
				raise ParserException("Token after {0} is None.".format(token))
			token = token.NextToken

		yield self.EndToken

	def __repr__(self):
		buffer = ""
		for token in self:
			if isinstance(token, CharacterToken):
				buffer += repr(token)
			else:
				buffer += token.Value

		return buffer

	@property
	def PreviousBlock(self):
		return self._previousBlock
	@PreviousBlock.setter
	def PreviousBlock(self, value):
		self._previousBlock = value
		value.NextBlock = self

	@property
	def NextBlock(self):
		return self._nextBlock
	@NextBlock.setter
	def NextBlock(self, value):
		self._nextBlock = value

	@property
	def EndToken(self):
		return self._endToken
	@EndToken.setter
	def EndToken(self, value):
		self._endToken = value

	@property
	def Length(self):
		return len(self)

class StartOfDocumentBlock(Block):
	def __init__(self, startToken):
		self._previousBlock =     None
		self._nextBlock =         None
		self.StartToken =         startToken
		self._endToken =          startToken
		self.MultiPart =          False

	def __len__(self):
		return 0

	def __str__(self):
		return "[StartOfDocumentBlock]"

class EmptyLineBlock(Block):
	def __str__(self):
		buffer = ""
		for token in self:
			buffer += token.Value
		buffer = buffer.replace("\t", "\\t").replace("\n", "\\n")
		return "[EmptyLineBlock: '{0}']".format(buffer)

class IndentationBlock(Block):
	def __str__(self):
		return "[IndentationBlock: length={len}]".format(len=len(self))

class CommentBlock(Block):
	def __str__(self):
		return "[CommentBlock: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class LibraryBlock(Block):
	def __str__(self):
		return "[LIBRARY: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class UseBlock(Block):
	def __str__(self):
		return "[USE: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class EntityBlock(Block):
	def __str__(self):
		return "[ENTITY: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class EntityBeginBlock(Block):
	def __str__(self):
		return "[ENTITY BEGIN: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class EntityEndBlock(Block):
	def __str__(self):
		return "[END ENTITY: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericList_OpenBlock(Block):
	def __str__(self):
		return "[GENERIC: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericList_DelimiterBlock(Block):
	def __str__(self):
		return "[generic-delimiter: ';' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericList_CloseBlock(Block):
	def __str__(self):
		return "[generic-close: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericList_ItemBlock(Block):
	def __str__(self):
		return "[generic-item: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortList_OpenBlock(Block):
	def __str__(self):
		return "[PORT: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortList_DelimiterBlock(Block):
	def __str__(self):
		return "[port-delimiter: ';' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortList_CloseBlock(Block):
	def __str__(self):
		return "[Port-close: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortList_ItemBlock(Block):
	def __str__(self):
		return "[port-item: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)


class ParserStack:
	def __init__(self, topElement):
		self._stack =       [topElement]
		self.Top =          topElement

	def Register(self, push, pop):
		self.__push = push
		self.__pop =  pop

	def Pop(self, n=1):
		for i in range(n):
			self._stack.pop()
		self.Top = self._stack[-1]
		self.__pop()

	def __eq__(self, other):
		return self.Top is other

	def __add__(self, other):
		self._stack.append(other)
		self.Top =          other
		self.__push()
		return self

	def __lshift__(self, other):
		self._stack[-1] = other
		self.Top =        other
		return self

	# Method aliases
	Push =  __add__

class TokenBuffer:
	def __init__(self, parserStack):
		parserStack.Register(self.Push, self.Pop)

		# newTokenBuffer =  deque()
		self._stack =     [None]  #newTokenBuffer]
		self._top =       None  #newTokenBuffer

	def Push(self):
		newTokenBuffer = deque()
		self._stack.append(None)  #newTokenBuffer)
		self._top = None   #newTokenBuffer

	def Pop(self):
		if self:
			raise ParserException("TokenBuffer is not empty: {0}.".format(", ".join([str(token) for token in self._top])))
		self._stack.pop()
		self._top = self._stack[-1]

	def Get(self):
		top = self._top
		self._top = None
		return top
		# return self._top.popleft()

	def __add__(self, other):
		# print("  tokenBuffer.add({0!s})".format(other))
		self._top = other
		# self._top.append(other)
		return self

	def __bool__(self):
		return (self._top is not None)
		# return (len(self._top) > 0)


class VHDL:
	class State(Enum):
		DocumentRoot =            0
		PossibleCommentStart =    1
		ConsumeComment =          2
		EndOfLine =               3
		LibraryStatement =        4
		UseStatement =            5

		EntityDeclaration_KeywordEntity =     100
		EntityDeclaration_WhiteSpace1 =       101
		EntityDeclaration_Identifier =        102
		EntityDeclaration_WhiteSpace2 =       103
		EntityDeclaration_DeclarativeRegion = 104
		
		GenericList_KeywordGeneric =          110
		GenericList_WhiteSpace1 =             111
		GenericList_OpeningParenthesis =      112
		GenericList_ClosingParenthesis =      113
		GenericList_ItemDelimiter =           114
		GenericList_ItemRemainder =           115

		PortList_KeywordPort =                120
		PortList_WhiteSpace1 =                121
		PortList_OpeningParenthesis =         122
		PortList_ClosingParenthesis =         123
		PortList_ItemDelimiter =              124
		PortList_ItemRemainder =              125

		EntityDeclaration_KeywordBegin =      150
		EntityDeclaration_KeywordEnd =        190

		ArchitectureDeclaration = 20
		ArchitectureDeclarationEnd = 21

	@classmethod
	def TransformTokensToBlocks(cls, rawTokenGenerator):
		iterator = iter(rawTokenGenerator)

		parserState = ParserStack(cls.State.DocumentRoot)
		tokenBuffer = TokenBuffer(parserState)
		openParenthesisCount = 0
		lastBlock =   StartOfDocumentBlock(next(iterator))
		newToken =    None
		newBlock =    None

		yield lastBlock

		for token in iterator:
			if newBlock is not None:
				# print("  yield block")
				yield newBlock
				lastBlock = newBlock
				newBlock =  None

			if newToken is not None:
				# print("  linking new token")
				token.PreviousToken = newToken
				newToken =            None

			if (not tokenBuffer):
				tokenBuffer += token

			# print("Parser loop: state={state!s} token={token!s} ".format(state=parserState.Top, token=token))

			if (parserState == cls.State.DocumentRoot):
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"):
						# fuse Indentation and EmptyLine blocks
						if isinstance(lastBlock, IndentationBlock):
							lastBlock = EmptyLineBlock(lastBlock.PreviousBlock, lastBlock.StartToken, endToken=token)
						else:
							newBlock = EmptyLineBlock(lastBlock, token, endToken=token)
						continue
					elif (token.Value == "-"):
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
				elif isinstance(token, SpaceToken):
					newBlock = IndentationBlock(lastBlock, token, endToken=token)
					continue
				elif isinstance(token, StringToken):
					keyword = token.Value.lower()
					if (keyword == "library"):
						parserState +=  cls.State.LibraryStatement
						newToken =      LibraryKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (keyword == "use"):
						parserState +=  cls.State.UseStatement
						newToken =      UseKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (keyword == "entity"):
						parserState +=  cls.State.EntityDeclaration_KeywordEntity
						newToken =      EntityKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (keyword == "architecture"):
						parserState +=  cls.State.ArchitectureDeclaration
						newToken =      ArchitectureKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (keyword == "package"):
						parserState +=  cls.State.PackageDeclaration
						newToken =      ArchitectureKeyword(token)
						tokenBuffer +=  newToken
						continue
					else:
						raise ParserException("Unknown keyword: '{0}'".format(token.Value))
				else: # tokenType
					raise ParserException("TokenType not supported here: {0!s}".format(token))
			elif (parserState == cls.State.PossibleCommentStart):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						parserState <<= cls.State.ConsumeComment
						startToken =    tokenBuffer.Get()
						newToken =      CommentKeyword(startToken)
						tokenBuffer +=  newToken
						continue
				raise NotImplementedError("State=PossibleCommentStart: {0!r}".format(token))
			elif (parserState == cls.State.ConsumeComment):
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"):
						startToken =    tokenBuffer.Get()
						newBlock =      CommentBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
						continue
					# consume everything until ";"
			elif (parserState == cls.State.LibraryStatement):
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      LibraryBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
						continue
					elif (token.Value == "-"):
						startToken =    tokenBuffer.Get()
						newBlock =      LibraryBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)

						parserState +=  cls.State.PossibleCommentStart
						tokenBuffer +=  token
						continue
				# consume everything until ";"
			elif (parserState == cls.State.UseStatement):
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      UseBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
						continue
					elif (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = UseBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)

						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue

					# consume everything until ";"
			# ========================================================================
			# ENTITY Declaration
			# ========================================================================
			elif (parserState == cls.State.EntityDeclaration_KeywordEntity):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken =    tokenBuffer.Get()
						newBlock =      EntityBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)
						parserState +=  cls.State.PossibleCommentStart
						tokenBuffer +=  token
						continue
				if (not isinstance(token, SpaceToken)):
					raise ParserException("Expected whitespace after keyword ENTITY.")
				parserState <<=     cls.State.EntityDeclaration_WhiteSpace1
			elif (parserState == cls.State.EntityDeclaration_WhiteSpace1):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = EntityBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
				if (not isinstance(token, StringToken)):
					raise ParserException("Expected entity name (identifier).")
				parserState <<=   cls.State.EntityDeclaration_Identifier
				newToken =        IdentifierToken(token)
			elif (parserState == cls.State.EntityDeclaration_Identifier):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = EntityBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
				if (not isinstance(token, SpaceToken)):
					raise ParserException("Expected whitespace after keyword ENTITY.")
				parserState <<= cls.State.EntityDeclaration_WhiteSpace2
			elif (parserState == cls.State.EntityDeclaration_WhiteSpace2):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = EntityBlock(lastBlock, startToken, endToken=token.PreviousToken, multiPart=True)
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
				if (not isinstance(token, StringToken)):
					raise ParserException("Expected keyword IS after entity name.")
				parserState <<=   cls.State.EntityDeclaration_DeclarativeRegion
				newToken =        IsKeyword(token)

				startToken =      tokenBuffer.Get()
				newBlock =        EntityBlock(lastBlock, startToken, endToken=newToken)
			# ------------------------------------------------------------------------
			# ENTITY Declarative Part
			# ------------------------------------------------------------------------
			elif (parserState == cls.State.EntityDeclaration_DeclarativeRegion):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = IndentationBlock(lastBlock, startToken, endToken=token.PreviousToken)
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
					elif (token.Value == "\n"):
						newBlock = EmptyLineBlock(lastBlock, token, token)
						continue
				elif isinstance(token, SpaceToken):
					newBlock = IndentationBlock(lastBlock, token, token)
					continue
				elif isinstance(token, StringToken):
					if (token.Value == "generic"):
						parserState +=  cls.State.GenericList_KeywordGeneric
						newToken =      GenericKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (token.Value == "port"):
						parserState +=  cls.State.PortList_KeywordPort
						newToken =      PortKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (token.Value == "begin"):
						parserState <<= cls.State.EntityDeclaration_KeywordBegin
						newToken =     BeginKeyword(token)
						tokenBuffer += newToken
						continue
					elif (token.Value == "end"):
						parserState <<= cls.State.EntityDeclaration_KeywordEnd
						newToken =     EndKeyword(token)
						tokenBuffer += newToken
						continue
					else:
						raise ParserException("Expected one of these keywords: generic, port, begin, end.")
					
				if (not isinstance(lastBlock, EntityBlock)):
					startToken = tokenBuffer.Get()
					newBlock = EntityBlock(lastBlock, startToken, endToken=token.PreviousToken)
					continue
				else:
					raise ParserException("Expected one of these keywords: generic, port, begin, end.")
			# ------------------------------------------------------------------------
			# ENTITY Body
			# ------------------------------------------------------------------------
			elif (parserState == cls.State.EntityDeclaration_KeywordBegin):
				raise ParserException("Entity Body is not supported.")
			# ------------------------------------------------------------------------
			# ENTITY End
			# ------------------------------------------------------------------------
			elif (parserState == cls.State.EntityDeclaration_KeywordEnd):
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      EntityEndBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
						continue
					else:
						raise ParserException("Expected ';'.")
				elif isinstance(token, StringToken):
					if (token.Value.lower == "entity"):
						newToken = EntityKeyword(token)
					# consume everything until ";"
			# ========================================================================
			# Generic List
			# ========================================================================
			elif (parserState == cls.State.GenericList_KeywordGeneric):
				if isinstance(token, CharacterToken):
					if (token == "("):
						parserState <<= cls.State.GenericList_ClosingParenthesis
						startToken =    tokenBuffer.Get()
						newBlock =      GenericList_OpenBlock(lastBlock, startToken, endToken=token)
						parserState +=  cls.State.GenericList_OpeningParenthesis
						openParenthesisCount = 1
						continue
				if (not isinstance(token, SpaceToken)):
					raise ParserException("Expected whitespace or '(' after keyword GENERIC.")
				parserState <<= cls.State.GenericList_WhiteSpace1
			elif (parserState == cls.State.GenericList_WhiteSpace1):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						parserState <<= cls.State.GenericList_ClosingParenthesis
						startToken =    tokenBuffer.Get()
						newBlock =      GenericList_OpenBlock(lastBlock, startToken, endToken=token)
						parserState +=  cls.State.GenericList_OpeningParenthesis
						openParenthesisCount = 1
						continue
					raise ParserException("Expected '(' after keyword GENERIC.")
			elif (parserState == cls.State.GenericList_OpeningParenthesis):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						startToken = tokenBuffer.Get()
						newBlock = IndentationBlock(lastBlock, startToken, endToken=token.PreviousToken)
						parserState += cls.State.PossibleCommentStart
						tokenBuffer += token
						continue
					elif (token.Value == "\n"):
						newBlock = EmptyLineBlock(lastBlock, token, token)
						continue
				elif isinstance(token, SpaceToken):
					newBlock = IndentationBlock(lastBlock, token, token)
					continue

				if isinstance(token, CharacterToken):
					if (token.Value == ")"):
						startToken = tokenBuffer.Get()
						if (startToken != token):
							newBlock =    IndentationBlock(lastBlock, startToken, token.PreviousToken)
						parserState.Pop()
						tokenBuffer +=  token
						continue

				if (not isinstance(token, StringToken)):
					raise ParserException("Expected generic name (identifier).")

				startToken =        tokenBuffer.Get()
				if (startToken != token):
					newBlock =        IndentationBlock(lastBlock, startToken, token)

				parserState <<= cls.State.GenericList_ItemRemainder
				newToken =          IdentifierToken(token)
				tokenBuffer +=      newToken
			elif (parserState == cls.State.GenericList_ItemDelimiter):
				startToken = tokenBuffer.Get()
				newToken1 =         DelimiterToken(startToken)
				newBlock =          GenericList_DelimiterBlock(lastBlock, newToken1, newToken1)

				if ((isinstance(token, CharacterToken) and (token.Value == "\n")) or (isinstance(token, SpaceToken))):
					parserState <<=   cls.State.GenericList_OpeningParenthesis
					continue
				if (not isinstance(token, StringToken)):
					raise ParserException("Expected generic name (identifier).")

				parserState <<=     cls.State.GenericList_ItemRemainder
				newToken =          IdentifierToken(token)
				newToken.PreviousToken = newToken1
				tokenBuffer +=      newToken
			elif (parserState == cls.State.GenericList_ItemRemainder):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						openParenthesisCount += 1
					elif (token.Value == ")"):
						openParenthesisCount -= 1
						if (openParenthesisCount == 0):
							startToken =  tokenBuffer.Get()
							newBlock =    GenericList_ItemBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState.Pop()
							tokenBuffer += token
					elif (token.Value == ";"):
						if (openParenthesisCount == 1):
							startToken =    tokenBuffer.Get()
							newBlock =      GenericList_ItemBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState <<= cls.State.GenericList_ItemDelimiter
						else:
							raise ParserException("Mismatch in opening and closing parenthesis: open={0}".format(openParenthesisCount))
			elif (parserState == cls.State.GenericList_ClosingParenthesis):
				if ((isinstance(token, CharacterToken) and (token.Value == "\n")) or (isinstance(token, SpaceToken))):
					continue
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      GenericList_CloseBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
			# ========================================================================
			# Port List
			# ========================================================================
			elif (parserState == cls.State.PortList_KeywordPort):
				if isinstance(token, CharacterToken):
					if (token == "("):
						parserState <<= cls.State.PortList_ClosingParenthesis
						startToken = tokenBuffer.Get()
						newBlock = PortList_OpenBlock(lastBlock, startToken, endToken=token)
						parserState += cls.State.PortList_OpeningParenthesis
						openParenthesisCount = 1
						continue
				if (not isinstance(token, SpaceToken)):
					raise ParserException("Expected whitespace or '(' after keyword PORT.")
				parserState <<= cls.State.PortList_WhiteSpace1
			elif (parserState == cls.State.PortList_WhiteSpace1):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						parserState <<= cls.State.PortList_ClosingParenthesis
						startToken = tokenBuffer.Get()
						newBlock = PortList_OpenBlock(lastBlock, startToken, endToken=token)
						parserState += cls.State.PortList_OpeningParenthesis
						openParenthesisCount = 1
						continue
					raise ParserException("Expected '(' after keyword PORT.")
			elif (parserState == cls.State.PortList_OpeningParenthesis):
				if ((isinstance(token, CharacterToken) and (token.Value == "\n")) or (isinstance(token, SpaceToken))):
					continue
				if isinstance(token, CharacterToken):
					if (token.Value == ")"):
						startToken = tokenBuffer.Get()
						if (startToken != token):
							newBlock = IndentationBlock(lastBlock, startToken, token.PreviousToken)
						parserState.Pop()
						tokenBuffer += token
						continue
				
				if (not isinstance(token, StringToken)):
					raise ParserException("Expected port name (identifier).")
				
				startToken = tokenBuffer.Get()
				if (startToken != token):
					newBlock = IndentationBlock(lastBlock, startToken, token)
				
				parserState <<= cls.State.PortList_ItemRemainder
				newToken = IdentifierToken(token)
				tokenBuffer += newToken
			elif (parserState == cls.State.PortList_ItemDelimiter):
				startToken = tokenBuffer.Get()
				newToken1 = DelimiterToken(startToken)
				newBlock = PortList_DelimiterBlock(lastBlock, newToken1, newToken1)
				
				if ((isinstance(token, CharacterToken) and (token.Value == "\n")) or (isinstance(token, SpaceToken))):
					parserState <<= cls.State.PortList_OpeningParenthesis
					continue
				if (not isinstance(token, StringToken)):
					raise ParserException("Expected port name (identifier).")
				
				parserState <<= cls.State.PortList_ItemRemainder
				newToken = IdentifierToken(token)
				newToken.PreviousToken = newToken1
				tokenBuffer += newToken
			elif (parserState == cls.State.PortList_ItemRemainder):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						openParenthesisCount += 1
					elif (token.Value == ")"):
						openParenthesisCount -= 1
						if (openParenthesisCount == 0):
							startToken = tokenBuffer.Get()
							newBlock = PortList_ItemBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState.Pop()
							tokenBuffer += token
					elif (token.Value == ";"):
						if (openParenthesisCount == 1):
							startToken = tokenBuffer.Get()
							newBlock = PortList_ItemBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState <<= cls.State.PortList_ItemDelimiter
						else:
							raise ParserException("Mismatch in opening and closing parenthesis: open={0}".format(openParenthesisCount))
			elif (parserState == cls.State.PortList_ClosingParenthesis):
				if ((isinstance(token, CharacterToken) and (token.Value == "\n")) or (isinstance(token, SpaceToken))):
					continue
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken = tokenBuffer.Get()
						newBlock = PortList_CloseBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
			elif (parserState == cls.State.ArchitectureDeclaration):
				pass
			else:
				raise RuntimeError("Unknown Tokenizer state: {0!s}.".format(parserState.Top))

