from collections import deque
from enum import Enum

from lib.Parser     import Token, Tokenizer, CharacterToken, StringToken


class VHDLToken(Token):
	pass

class CommentToken(VHDLToken):
	def __init__(self, previousToken, commentText, start, end=None):
		super().__init__(previousToken, commentText, start, end)

	def __str__(self):
		return "<CommentToken: '{0}'>".format(self.Value)

class Block(Token):
	pass

class KeywordToken(VHDLToken):
	pass

class LibraryKeyword(KeywordToken):
	def __init__(self, stringToken):
		super().__init__(stringToken.PreviousToken, None, stringToken.Start, stringToken.End)

	def __str__(self):
		return "<Keyword: LIBRARY>"

class LibraryBlock(Block):

	def __str__(self):
		return "{LIBRARY ...}"


class VHDLTokenizer:
	class State(Enum):
		DocumentRoot =      0
		CommentStart1 =     1
		CommentStart2 =     2
		EndOfLine =         3
		LibraryStatement =  4

	@classmethod
	def Transform(cls, rawTokenGenerator):
		tokenBuffer = deque()
		strBuffer =   ""
		stack =       [cls.State.DocumentRoot]
		newToken =    None

		for token in rawTokenGenerator:
			if newToken is not None:
				token.PreviousToken = newToken
				newToken =            None

			state = stack[-1]
			if (state is cls.State.DocumentRoot):
				if isinstance(token, CharacterToken):
					tokenBuffer.append(token)
					if (token.Value == "-"):
						stack.append(cls.State.CommentStart1)
						continue
				elif isinstance(token, StringToken):
					keyword = token.Value.lower()
					if (keyword == "library"):
						stack.append(cls.State.LibraryStatement)
						newToken = LibraryKeyword(token)
						tokenBuffer.append(newToken)
				else:
					yield token
			elif (state is cls.State.CommentStart1):
				if isinstance(token, CharacterToken):
					if (token.Value == "-"):
						stack[-1] =     cls.State.CommentStart2
						strBuffer = "--"
						continue
				yield token
			elif (state is cls.State.CommentStart2):
				if isinstance(token, CharacterToken):
					if (token.Value == "\n"):
						startToken = tokenBuffer.popleft()
						newToken = CommentToken(startToken.PreviousToken, strBuffer, startToken.Start, token.PreviousToken.End)
						yield newToken
						stack.pop()
						continue
				strBuffer += token.Value
			elif (state is cls.State.LibraryStatement):
				if isinstance(token, CharacterToken):
					if (token.Value == ";"):
						startToken = tokenBuffer.popleft()
						newToken = LibraryBlock()
						continue
				tokenBuffer.append(token)
			else:
				raise RuntimeError("Unknown Tokenizer state.")