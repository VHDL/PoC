from collections import deque
from enum import Enum

from lib.Parser     import Token, CharacterToken, StringToken, ParserException, SpaceToken


class VHDLToken(Token):
	pass

class KeywordToken(VHDLToken):
	__KEYWORD__ = None

	def __init__(self, stringToken):
		super().__init__(stringToken.PreviousToken, self.__KEYWORD__, stringToken.Start, stringToken.End)

	def __str__(self):
		return "<Keyword: {0}>".format(self.__KEYWORD__.upper())

class CommentKeyword(VHDLToken):
	__KEYWORD__ = "--"

	def __init__(self, characterToken):
		super().__init__(characterToken.PreviousToken, self.__KEYWORD__, characterToken.Start, characterToken.NextToken.End)

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

class EndKeyword(KeywordToken):
	__KEYWORD__ = "end"

class ArchitectureKeyword(KeywordToken):
	__KEYWORD__ = "architecture"

class BeginEntityKeyword(KeywordToken):
	__KEYWORD__ = "begin"


class Block(object):
	def __init__(self, previousBlock, startToken, endToken=None):
		previousBlock.NextBlock = self
		self._previousBlock =     previousBlock
		self._nextBlock =         None
		self.StartToken =         startToken
		self._endToken =          endToken

	def __len__(self):
		return self.EndToken.End.Absolute - self.StartToken.Start.Absolute + 1

	def __iter__(self):
		token = self.StartToken
		while (token is not self.EndToken):
			yield token
			token = token.NextToken
		yield self.EndToken

	def __repr__(self):
		buffer = ""
		for token in self:
			if isinstance(token, CharacterToken):
				buffer += str(token)
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
		self._endToken =          None

	def __len__(self):
		return 0

	def __str__(self):
		return "[StartOfDocumentBlock]"

class EmptyLineBlock(Block):
	def __str__(self):
		return "[EmptyLineBlock]"

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

class GenericListOpenBlock(Block):
	def __str__(self):
		return "[GENERIC: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericListCloseBlock(Block):
	def __str__(self):
		return "[generic-close: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class GenericBlock(Block):
	def __str__(self):
		return "[generic: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortListOpenBlock(Block):
	def __str__(self):
		return "[PORT: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortListCloseBlock(Block):
	def __str__(self):
		return "[port-close: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)

class PortBlock(Block):
	def __str__(self):
		return "[port: '{stream!r}' at {start!s} .. {end!s}]".format(stream=self, start=self.StartToken.Start, end=self.EndToken.End)


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

		newTokenBuffer =  deque()
		self._stack =     [newTokenBuffer]
		self._top =       newTokenBuffer

	def Push(self):
		newTokenBuffer = deque()
		self._stack.append(newTokenBuffer)
		self._top = newTokenBuffer

	def Pop(self):
		if (len(self._top) > 0):
			raise ParserException("TokenBuffer is not empty.")
		self._stack.pop()
		self._top = self._stack[-1]

	def Get(self):
		return self._top.popleft()

	def __add__(self, other):
		self._top.append(other)
		return self

	def __bool__(self):
		return (len(self._top) > 0)


class VHDL:
	class State(Enum):
		DocumentRoot =            0
		PossibleCommentStart =    1
		ConsumeComment =          2
		EndOfLine =               3
		LibraryStatement =        4
		UseStatement =            5
		EntityDeclaration =       10
		GenericList =             11
		Generic =                 12
		PortList =                13
		Port =                    14
		EntityDeclarationEnd =    19
		ArchitectureDeclaration = 20

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
						parserState +=  cls.State.EntityDeclaration
						newToken =      EntityKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (keyword == "architecture"):
						parserState +=  cls.State.ArchitectureDeclaration
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
				raise NotImplementedError("State=CommentStart1: {0!r}".format(token))
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
				# consume everything until ";"
			elif (parserState == cls.State.EntityDeclaration):
				if isinstance(token, StringToken):
					if (token.Value == "generic"):
						if (not isinstance(lastBlock, EntityBlock)):
							startToken =  tokenBuffer.Get()
							newBlock =    EntityBlock(lastBlock, startToken, endToken=token.PreviousToken)

						parserState +=  cls.State.GenericList
						newToken =      GenericKeyword(token)
						tokenBuffer +=  newToken

						continue
					elif (token.Value == "port"):
						if (not isinstance(lastBlock, EntityBlock)):
							startToken =  tokenBuffer.Get()
							newBlock =    EntityBlock(lastBlock, startToken, endToken=token.PreviousToken)

						parserState +=  cls.State.PortList
						newToken =      PortKeyword(token)
						tokenBuffer +=  newToken
						continue
					elif (token.Value == "end"):
						if (not isinstance(lastBlock, EntityBlock)):
							startToken = tokenBuffer.Get()
							newBlock = EntityBlock(lastBlock, startToken, endToken=token.PreviousToken)

						parserState <<= cls.State.EntityDeclarationEnd
						newToken =     EndKeyword(token)
						tokenBuffer += newToken
						continue
					# else:
					# 	raise ParserException("Expected keywords: generic, port or end.")
			elif (parserState == cls.State.EntityDeclarationEnd):
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      EntityEndBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
						continue
					# consume everything until ";"
			elif (parserState == cls.State.GenericList):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						startToken =    tokenBuffer.Get()
						newBlock =      GenericListOpenBlock(lastBlock, startToken, endToken=token)
						parserState +=  cls.State.Generic
						openParenthesisCount += 1
					elif (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      GenericListCloseBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
					elif (token.Value == "\n"):
						pass
					else:
						raise ParserException("Unexpected character: '{0!s}'".format(token))
				elif isinstance(token, SpaceToken):
					pass
				else:
					raise ParserException("Unexpected token class: {0!s}".format(token))
			elif (parserState == cls.State.Generic):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						openParenthesisCount += 1
					elif (token.Value == ")"):
						openParenthesisCount -= 1
						if (openParenthesisCount == 0):
							startToken =  tokenBuffer.Get()
							newBlock =    GenericBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState.Pop()
							tokenBuffer += token
					elif ((token.Value == ";") and (openParenthesisCount == 1)):
						startToken =    tokenBuffer.Get()
						newBlock =      GenericBlock(lastBlock, startToken, endToken=token.PreviousToken)
						parserState.Pop()
						parserState += cls.State.Generic
			elif (parserState == cls.State.PortList):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						startToken =    tokenBuffer.Get()
						newBlock =      PortListOpenBlock(lastBlock, startToken, endToken=token)
						parserState +=  cls.State.Port
						openParenthesisCount += 1
					elif (token.Value == ";"):
						startToken =    tokenBuffer.Get()
						newBlock =      PortListCloseBlock(lastBlock, startToken, endToken=token)
						parserState.Pop()
					elif (token.Value == "\n"):
						pass
					else:
						raise ParserException("Unexpected character: '{0!s}'".format(token))
				elif isinstance(token, SpaceToken):
					pass
				else:
					raise ParserException("Unexpected token class: {0!s}".format(token))
			elif (parserState == cls.State.Port):
				if isinstance(token, CharacterToken):
					if (token.Value == "("):
						openParenthesisCount += 1
					elif (token.Value == ")"):
						openParenthesisCount -= 1
						if (openParenthesisCount == 0):
							startToken =  tokenBuffer.Get()
							newBlock =    PortBlock(lastBlock, startToken, endToken=token.PreviousToken)
							parserState.Pop()
							tokenBuffer += token
					elif ((token.Value == ";") and (openParenthesisCount == 1)):
						startToken =    tokenBuffer.Get()
						newBlock =      PortBlock(lastBlock, startToken, endToken=token.PreviousToken)
						parserState.Pop()
						parserState +=  cls.State.Port



					# startToken = tokenBuffer.popleft()
						# newBlock = UseBlock(lastBlock, startToken, endToken=token)
						# tokenBuffer.clear()
						# parserState.Pop()
						# continue
				# consume everything until ";"
			else:
				raise RuntimeError("Unknown Tokenizer state: {0!s}.".format(parserState.Top))
