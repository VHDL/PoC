
from enum			import Enum, unique		# EnumMeta
from graphviz	import Digraph

parserTree = Digraph("ParserTree", format="png")

class NodeID:
	_id = -1
	
	@classmethod
	def Value(cls):
		return cls._id
	
	@classmethod
	def Next(cls):
		cls._id += 1
		return cls._id

class ParserException(Exception):
	pass
	
@unique
class ParserResultKind(Enum):
	Mismatch =		0
	Match =				1
	LastMatch =		2
	Collected =		3

	def __str__(self):
		return self.name
	
	def __repr__(self):
		return str(self).lower()

class ParserResult:
	def __init__(self, kind, value=None):
		self._kind =		kind
		self._value =		value
	
	@property
	def Kind(self):
		return self._kind
		
	@property
	def Value(self):
		return self._value
	
	def __str__(self):
		return str(self._value)

def ParserRange(minimum, maximum):
	i = 1
	if (maximum > 0):
		while (i <= maximum):
			yield(i >= minimum)
			i += 1
	else:
		while True:
			yield(i >= minimum)
			i += 1
			
class ParserObject():
	def __init__(self):
		self._parent =	None
		self._name = None
	
	def SetName(self, name):
		self._name = name
		return self
	
	@property
	def Parent(self):
		return self._parent
	
	@Parent.setter
	def Parent(self, value):
		if not isinstance(value, ParserObject): raise ParserException("Parameter 'value' is not of type ParserObject.")
		self._parent = value
	
	@property
	def Name(self):
		return self._name
	
	def parse(self, reader):
		parserTree.node("N{0}".format(NodeID.Next()), "Start")
		parser = self.GetParser()
		# initialize generator by sending a None value as first value
		parser.send(None)

		pos =		0
		col =		0
		line =	1
		for char in reader:
			try:
				pos +=	1
				col +=	1
				if (char == "\r"):
					print("char=CR")
				elif (char == "\n"):
					col =		0
					line +=	1
					print("char=NL")
				elif (char == "\t"):
					print("char=TAB")
				elif (char == " "):
					print("char=SPACE")
				else:
					print("char={0} at pos={1}; line={2}; col={3}".format(char, pos, line, col))
				
				parser.send(char)
			except StopIteration as ex:
				if (ex.value.Kind == ParserResultKind.Mismatch):
					print("mismatch")
				elif (ex.value.Kind == ParserResultKind.Match):
					if (pos == len(reader)):
						print("matched input")
					else:
						raise ParserException("Input not consumed.")
				elif (ex.value.Kind == ParserResultKind.LastMatch):
					if (pos == len(reader)):
						print("matched input by last character")
					else:
						raise ParserException("Input not consumed.")
				elif (ex.value.Kind == ParserResultKind.Collected):
					if (pos == len(reader)):
						print("match with collected data: {0}".format(ex.value.Value))
					else:
						raise ParserException("Input not consumed.")
				else:
					print("ParserObject.parse(): StopIteration at char={0}; return value: {1}".format(char, ex.value.Value))
					
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "End")
				return
		
		try:
			print("char=None")
			parser.send(None)
		except StopIteration as ex:
			if (ex.value.Kind == ParserResultKind.Mismatch):
				print("mismatch")
			elif (ex.value.Kind == ParserResultKind.Match):
				print("matched input")
			elif (ex.value.Kind == ParserResultKind.LastMatch):
				print("matched input by last character")
			elif (ex.value.Kind == ParserResultKind.Collected):
				print("match with collected data: {0}".format(ex.value.Value))
			else:
				print("ParserObject.parse(): StopIteration at char={0}; return value: {1}".format(char, ex.value.Value))
	
		parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
		parserTree.node("N{0}".format(NodeID.Value()), "End")
	
class Character(ParserObject):
	def __init__(self, char):
		# print("Keyword.__init__(char={0})".format(char))
		super().__init__()
		if not isinstance(char, str):	ParserException("Parameter 'char' is not a string.")
		if (len(char) != 1):					ParserException("Parameter 'char' is not a character.")
		self._character = char
		# print("Keyword.__init__(): _character={0}".format(self._character))
	
	def __add__(self, value):
		if isinstance(value, Character):
			lst = self._characterList.copy()
			lst.append(value._character)
			return Word(lst)
		elif isinstance(value, Word):
			lst = self._characterList.copy()
			lst.extend(value._characterList)
			return Word(lst)
		else:
			raise ParserException("Parameter 'value' is not a Character or Word.")
	
	def GetParser(self):
		print("Character.GetParser(): generate a parser for `{0}`".format(self._character))
		char = yield
		if (char == self._character):
			print("Character.GetParser: match")
			return ParserResult(ParserResultKind.LastMatch)
		else:
			print("Character.GetParser: mismatch")
			return ParserResult(ParserResultKind.Mismatch)
	
	def __str__(self):
		return "`{0}`".format(self._character)
		
class Keyword(ParserObject):
	def __init__(self, pattern):
		# print("Keyword.__init__(pattern={0})".format(pattern))
		super().__init__()
		if isinstance(pattern, str):
			self._keyword = pattern
		else:
			ParserException("Parameter 'pattern' is not a string.")
		# print("Keyword.__init__(): _keyword={0}".format(self._keyword))
	
	def CaseSensitive(self):
		raise NotImplementedError
		return self
	
	def CaseInsensitive(self):
		raise NotImplementedError
		return self
	
	def CaptialLetter(self):
		raise NotImplementedError
		return self
	
	def GetParser(self):
		print("Keyword.GetParser(): generate a parser for \"{0}\"".format(self._keyword))
		char = yield
		# check first n-1 characters
		for keywordChar in self._keyword[:-1]:
			if (char == keywordChar):
				char = yield
			else:
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "MISMATCH")
				print("Keyword.GetParser: mismatch")
				return ParserResult(ParserResultKind.Mismatch)
		# check last character
		if (char == self._keyword[-1]):
			parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
			parserTree.node("N{0}".format(NodeID.Value()), "\"{0}\"".format(self._keyword))
			print("Keyword.GetParser: completed")
			return ParserResult(ParserResultKind.LastMatch)
		else:
			parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
			parserTree.node("N{0}".format(NodeID.Value()), "MISMATCH")
			print("Keyword.GetParser: mismatch")
			return ParserResult(ParserResultKind.Mismatch)
	
	def __str__(self):
		return "\"{0}\"".format(self._keyword)
	
class Word(ParserObject):
	def __init__(self, param, minimum=0, maximum=0):
		# print("Word.__init__(param={0})".format(param))
		super().__init__()
		self._minimum =	minimum
		self._maximum = maximum
		
		if isinstance(param, str):
			if (len(param) == 1):
				self._characterList = [param]
			else:
				self._characterList = [char for char in param]
		elif isinstance(param, list):
			# check all list items if they are ParserObject objects
			for item in param:
				if not isinstance(item, str): raise ParserException("List item is not a string.")
				if (len(item) != 1):					raise ParserException("List item is not a character.")
			self._characterList = param
		else:
			raise ParserException("Type not supported for param.")
		
		# print("Word.__init__(): _characterList={0}".format(str(self._characterList)))
	
	def CaseSensitive(self):
		raise NotImplementedError
		return self
	
	def CaseInsensitive(self):
		raise NotImplementedError
		return self
	
	def SetRange(self, minimum=0, maximum=0):
		self._minimum = minimum
		self._maximum = maximum
	
	def __add__(self, value):
		if isinstance(value, Character):
			lst = self._characterList.copy()
			lst.append(value._character)
			return Word(lst)
		elif isinstance(value, Word):
			lst = self._characterList.copy()
			lst.extend(value._characterList)
			return Word(lst)
		else:
			raise ParserException("Parameter 'value' is not a Character or Word.")
	
	def __sub__(self, value):
		raise NotImplementedError()
	
	def __mul__(self, value):
		if isinstance(value, int):
			return Word(self._characterList, value, value)
		elif isinstance(value, tuple):
			if (len(value) != 2): raise ParserException("Parameter 'value' has too many tuple items.")
			return Word(self._characterList, value[0], value[1])
		else:
			raise ParserException("Parameter 'value' is not a int or tuple of ints.")
		
	def GetParser(self):
		print("Word.GetParser(): generate a parser for {0} with range {1},{2}".format(self.__str__(), self._minimum, self._maximum))
		buffer =	""
		char =		yield
		length =	0
		# for isInRange in ParserRange(self._minimum, self._maximum):
		while (True if (self._maximum == 0) else (length < self._maximum)):
			if (char is None):
				if (self._minimum <= length) and (length <= self._maximum):
					parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
					parserTree.node("N{0}".format(NodeID.Value()), "Word: {0}".format(buffer))
					print("Word.GetParser: completed1 and collected")
					return ParserResult(ParserResultKind.Collected, buffer)
				else:
					parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
					parserTree.node("N{0}".format(NodeID.Value()), "MISMATCH")
					print("Word.GetParser: completed1 with mismatch")
					return ParserResult(ParserResultKind.Mismatch)
			elif (char in self._characterList):
				buffer +=	char
				length +=	1
				char =		yield
			else:
				print("buffer='{0}' length={1} min={2} max={3}".format(buffer, length, self._minimum, self._maximum))
				if ((self._minimum <= length) and ((self._maximum == 0) or (length <= self._maximum))):
					parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
					parserTree.node("N{0}".format(NodeID.Value()), "Word: {0}".format(buffer))
					print("Word.GetParser: completed2 and collected")
					return ParserResult(ParserResultKind.Collected, buffer)
				else:
					parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
					parserTree.node("N{0}".format(NodeID.Value()), "MISMATCH")
					print("Word.GetParser: completed2 with mismatch")
					return ParserResult(ParserResultKind.Mismatch)
		
		
		if (self._minimum <= length) and (length <= self._maximum):
			parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
			parserTree.node("N{0}".format(NodeID.Value()), "Word: {0}".format(buffer))
			print("Word.GetParser: completed3 and collected")
			return ParserResult(ParserResultKind.Collected, buffer)
		else:
			parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
			parserTree.node("N{0}".format(NodeID.Value()), "MISMATCH")
			print("Word.GetParser: completed3 with mismatch")
			return ParserResult(ParserResultKind.Mismatch)
		
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			charList = "".join(self._characterList)
			charList = charList.replace("\r", "\\r")
			charList = charList.replace("\n", "\\n")
			charList = charList.replace("\t", "\\t")
			if (self._minimum > 0):
				if (self._maximum > 0):
					count = "{" + str(self._minimum) + "," + str(self._maximum) + "}"
				else:
					count = "{" + str(self._minimum) + ",*}"
			elif (self._maximum > 0):
				count = "{" + str(self._maximum) + "}"
			else:
				count = "{*}"
			return "[{0}]{1}".format(charList, count)

class All(ParserObject):
	def __init__(self):
		super().__init__()
	
	def __sub__(self, value):
		if isinstance(value, Character):
			return ExceptOf(value._character)
		elif isinstance(value, Word):
			return ExceptOf(value._characterList.copy())
		else:
			raise ParserException("Parameter 'value' is not a Character or Word.")
	
	def __mul__(self, value):
		if isinstance(value, int):
			return Any(value, value)
		elif isinstance(value, tuple):
			if (len(value) != 2): raise ParserException("Parameter 'value' has too many tuple items.")
			return Any(value[0], value[1])
		else:
			raise ParserException("Parameter 'value' is not a int or tuple of ints.")
			
	def GetParser(self):
		raise ParserException("All must not be used.")
	
	def __str__(self):
		return "ALL"

class Any(All):
	def __init__(self, minimum=0, maximum=0):
		super().__init__()
		if (maximum <= 0): raise ParserException("Parameter 'maximum' must be greater than 0")
		self._minimum =	minimum
		self._maximum = maximum
			
	def GetParser(self):
		print("Any.GetParser(): generate a parser for any character")
		buffer =	""
		char =		yield
		for isInRange in ParserRange(self._minimum, self._maximum):
			if (char is None):
				print("Any.GetParser: completed")
				return ParserResult(ParserResultKind.Collected, buffer) if isInRange else ParserResult(ParserResultKind.Mismatch)
			else:
				buffer += char
				char =		yield
		
		print("Any.GetParser: completed")
		return ParserResult(ParserResultKind.Collected, buffer)
	
	def __str__(self):
		if (self._minimum > 0):
			if (self._maximum > 0):
				count = "{" + str(self._minimum) + "," + str(self._maximum) + "}"
			else:
				count = "{" + str(self._minimum) + ",*}"
		else:
			count = "{" + str(self._maximum) + "}"
		return "ANY{0}".format(count)
		
class ExceptOf(All):
	def __init__(self, param):
		super().__init__()
		if isinstance(param, str):
			if (len(param) == 1):
				self._characterList = [param]
			else:
				self._characterList = [char for char in param]
		elif isinstance(param, list):
			for item in param:
				if not isinstance(item, str): raise ParserException("List item is not a string.")
				if (len(item) != 1):					raise ParserException("List item is not a character.")
			self._characterList = param
		else:
			raise ParserException("Type not supported for param.")
	
	def CaseSensitive(self):
		raise NotImplementedError
		return self
	
	def CaseInsensitive(self):
		raise NotImplementedError
		return self
	
	# TODO: how to define add and sub operations
	def __add__(self, value):
		raise NotImplementedError()
	
	# TODO: how to define add and sub operations	
	def __sub__(self, value):
		raise NotImplementedError()
			
	def GetParser(self):
		print("ExceptOf.GetParser(): generate a parser for {0}".format(self.__str__()))
		buffer =	""
		char =		yield
		while True:
			if (char is None):
				return ParserResult(ParserResultKind.Collected, buffer)
			elif (char not in self._characterList):
				buffer += char
				char =		yield
			else:
				return ParserResult(ParserResultKind.Collected, buffer)
	
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			return "[-{0}]".format("".join(self._characterList).replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t"))

class Forward(ParserObject):
	def __init__(self, name=None):
		super().__init__()
		self._name = name
		self._item = None
	
	def __lshift__(self, value):
		if not isinstance(value, ParserObject): raise ParserException("Parameter 'value' is no ParserObject.")
		self._item = value
		return self
	
	def GetParser(self):
		return self._item.GetParser()
	
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			return "FORWARD"
	
class Sequence(ParserObject):
	def __init__(self, *args):
		super().__init__()
	
		for item in args:
			if not isinstance(item, ParserObject): raise ParserException("Type '{0}' not supported for list item in 'args'.".format(type(item)))
			item.Parent = self
		self._sequence =	args
	
	def GetParser(self):
		parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
		parserTree.node("N{0}".format(NodeID.Value()), "Sequence Start: {0}".format(self.__str__()))
		print("Sequence.GetParser(): generate a parser for '{0}'".format(self.__str__()))
		char = yield
		for item in self._sequence[:-1]:
			parser = item.GetParser()
			# initialize generator by sending a None value as first value
			parser.send(None)
			try:
				while True:
					parser.send(char)
					char = yield
			except StopIteration as ex:
				if (ex.value.Kind == ParserResultKind.Mismatch):
					parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
					parserTree.node("N{0}".format(NodeID.Value()), "Sequence End: MISMATCH")
					return ParserResult(ParserResultKind.Mismatch)
				elif (ex.value.Kind == ParserResultKind.Match):
					char = yield
				elif (ex.value.Kind == ParserResultKind.LastMatch):
					char = yield
				elif (ex.value.Kind == ParserResultKind.Collected):
					print("collected={0}".format(ex.value.Value))
				else:
					print("Sequence::Generator: StopIteration at char='{0}' return value: {1}".format(char, ex.value))
					return ParserResult(ParserResultKind.Mismatch)
					
		# parse last item in the sequence
		parser = self._sequence[-1].GetParser()
		# initialize generator by sending a None value as first value
		parser.send(None)
		try:
			while True:
				parser.send(char)
				char = yield
		except StopIteration as ex:
			if (ex.value.Kind == ParserResultKind.Mismatch):
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "Sequence End: MISMATCH")
				return ParserResult(ParserResultKind.Mismatch)
			elif (ex.value.Kind == ParserResultKind.Match):
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "Sequence End: MATCH")
				print("Sequence.GetParser: completed  '{0}'".format(self.__str__()))
				return ParserResult(ParserResultKind.Match)
			elif (ex.value.Kind == ParserResultKind.LastMatch):
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "Sequence End: LASTMATCH")
				print("Sequence.GetParser: completed  '{0}'".format(self.__str__()))
				return ParserResult(ParserResultKind.LastMatch)
			elif (ex.value.Kind == ParserResultKind.Collected):
				parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
				parserTree.node("N{0}".format(NodeID.Value()), "Sequence End: COLLECTED '{0}'".format(ex.value.Value))
				print("collected={0}".format(ex.value.Value))
				print("Sequence.GetParser: completed  '{0}'".format(self.__str__()))
				return ParserResult(ParserResultKind.Collected)
			else:
				print("Sequence::Generator: StopIteration at char='{0}' return value: {1}".format(char, ex.value))
				return ParserResult(ParserResultKind.Mismatch)
	
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			return "(" + " -> ".join([str(item) for item in self._sequence]) + ")"
		
class Choice(ParserObject):
	def __init__(self, *args):
		super().__init__()
		
		for item in args:
			if not isinstance(item, ParserObject): raise ParserException("Type not supported for list item in 'args'.")
			item.Parent = self
		self._Choices =	args
	
	def GetParser(self):
		parserTree.edge("N{0}".format(NodeID.Value()), "N{0}".format(NodeID.Next()))
		parserTree.node("N{0}".format(NodeID.Value()), "Choice Start: {0}".format(self.__str__()))
		print("Choice.GetParser(): generate a parser for {0}".format(self.__str__()))
		
		parsers = []
		for item in self._Choices:
			p = item.GetParser()
			p.send(None)
			parsers.append((item, p))
		
		breaker =	False
		char =	yield
		while (len(parsers) != 0):
			disableList = []
			for t in parsers:
				item,p = t
				try:
					p.send(char)
				except StopIteration as ex:
					if (ex.value.Kind == ParserResultKind.Mismatch):
						disableList.append(t)
					elif (ex.value.Kind == ParserResultKind.Match):
						breaker = True
						break
					elif (ex.value.Kind == ParserResultKind.LastMatch):
						breaker = True
						break
					elif (ex.value.Kind == ParserResultKind.Collected):
						print("collected={0}".format(ex.value.Value))
						breaker = True
						break
					else:
						print("Choice::Generator: StopIteration at char='{0}' return value: {1}".format(char, ex.value))
						return ParserResult(ParserResultKind.Mismatch)
			for t in disableList:
				item,d = t
				print("disable {0}".format(str(item)))
				parsers.remove(t)
			if (breaker == True): break
			char = yield
		
		print("Choice.GetParser: completed")
		if ((len(parsers) == 1) and (breaker == True)):
			return ParserResult(ParserResultKind.Match)
		else:
			return ParserResult(ParserResultKind.Mismatch)
	
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			return "{" + " | ".join([str(item) for item in self._Choices]) + "}"

class Optional(ParserObject):
	pass
		
class Repeat(ParserObject):
	def __init__(self, arg, minimum=0, maximum=0):
		super().__init__()
		if not isinstance(arg, ParserObject): raise ParserException("Type not supported for list item in 'arg'.")
		self._item =				arg
		self._item.Parent =	self
		self._minimum =			minimum
		self._maximum =			maximum
	
	def __mul__(self, value):
		if isinstance(value, int):
			return Repeat(self._item, value, value)
		elif isinstance(value, tuple):
			if (len(value) != 2): raise ParserException("Parameter 'value' has too many tuple items.")
			return Repeat(self._item, value[0], value[1])
		else:
			raise ParserException("Parameter 'value' is not a int or tuple of ints.")
	
	def GetParser(self):
		print("Repeat.GetParser(): generate a parser for '{0}'".format(self.__str__()))
	
		char = yield
		for isInRange in ParserRange(self._minimum, self._maximum):
			# if (char is None):
				# print("Word.GetParser: completed")
				# return ParserResult(ParserResultKind.Collected, buffer) if isInRange else ParserResult(ParserResultKind.Mismatch)
			parser = self._item.GetParser()
			parser.send(None)
		
			try:
				while True:
					parser.send(char)
					char = yield
			except StopIteration as ex:
				if (ex.value.Kind == ParserResultKind.Mismatch):
					print("Repeat.GetParser: mismatch")
					return ParserResult(ParserResultKind.Mismatch)
				elif (ex.value.Kind == ParserResultKind.Match):
					# if isInRange:
						# return ParserResult(ParserResultKind.Match)
					# char = yield
					pass
				elif (ex.value.Kind == ParserResultKind.LastMatch):
					# if isInRange:
						# return ParserResult(ParserResultKind.LastMatch)
					# char = yield
					pass
				elif (ex.value.Kind == ParserResultKind.Collected):
					print("collected={0}".format(ex.value.Value))
					# if isInRange:
						# return ParserResult(ParserResultKind.Collected)
					# char = yield
					pass
				else:
					print("Repeat::Generator: StopIteration at char='{0}' return value: {1}".format(char, ex.value))
					return ParserResult(ParserResultKind.Mismatch)
			if (char is None):
				print("Repeat.GetParser: completed")
				return ParserResult(ParserResultKind.Match) if isInRange else ParserResult(ParserResultKind.Mismatch)
	
	def __str__(self):
		if (self._name is not None):
			return self._name
		else:
			return "{0}*".format(str(self._item))
		
class Characters:
	SingleQuote =						Character("'")
	DoubleQuote =						Character("\"")
	Dot =										Character(".")
	Comma =									Character(",")
	Colon =									Character(":")
	SemiColon =							Character(";")
	Slash =									Character("/")
	BackSlash =							Character("\\")
	Underline =							Character("_")
	Plus =									Character("+")
	Minus =									Character("-")
	Hash =									Character("#")
	Asterisk =							Character("*")
	Power =									Character("**")
	Apostrophe =						Character("'")
	BackTick =							Character("`")
	Space =									Character(" ")
	Null =									Character("\0")
	Bell =									Character("\b")
	CarrageReturn =					Character("\r")
	NewLine =								Character("\n")
	HorrizontalTabulator =	Character("\t")
	VerticalTabulator =			Character("\v")
	Escape =								Character("\e")
	
	OpeningBracket =				Character("[")
	ClosingBracket =				Character("]")
	OpeningParentheses =		Character("(")
	ClosingParentheses =		Character(")")
	OpeningBraces =					Character("{")
	ClosingBraces =					Character("}")
	OpeningChevron =				Character("<")
	ClosingChevron =				Character(">")
	EqualSign =							Character("=")
	ExclamationMark =				Character("!")
	QuestionMark =					Character("?")
	SectionSign =						Character("§")
	Dollar =								Character("$")
	Percent =								Character("%")
	Ampersand =							Character("&")
	Pipe =									Character("|")
	Tilde =									Character("~")
	Caret =									Character("^")
	Degree =								Character("°")
	At =										Character("@")
	
	# aliases
	Dash =									Minus
	Sharp =									Hash
	
	NUL =										Null
	Beep =									Bell
	HT =										HorrizontalTabulator
	VT =										VerticalTabulator
	CR =										CarrageReturn
	NL =										NewLine
	ESC =										Escape
	
	Tick =									Apostrophe
	LessThan =							OpeningChevron
	GreaterThan =						ClosingChevron

class CharacterClasses:
	LowerAlphaChars =				Word("abcdefghijklmnopqrstuvwxyz").SetName("a-z")
	UpperAlphaChars =				Word("ABCDEFGHIJKLMNOPQRSTUVWXYZ").SetName("A-Z")
	NumberChars =						Word("0123456789").SetName("0-9")
	WhiteSpaceChars =				Word(" \t")
	LineEnd =								Word("\r\n")

	BinaryDigits =					Word("01")
	OctalDigits =						Word("01234567").SetName("0-7")
	DecimalDigits =					NumberChars
	HexadecimalDigits =			Word("0123456789abcdefABCDEF").SetName("0-9a-fA-F")

	AlphaChars =						(LowerAlphaChars + UpperAlphaChars).SetName("a-zA-Z")
	AlphaNumChars =					(LowerAlphaChars + UpperAlphaChars + NumberChars).SetName("a-zA-Z0-9")

class Sequences:
	@staticmethod
	def SingleQuoted(*args):
		return Sequence(Characters.SingleQuote, *args, Characters.SingleQuote)
		
	@staticmethod
	def DoubleQuoted(*args):
		return Sequence(Characters.DoubleQuote, *args, Characters.DoubleQuote)
	

class Rules:
	WhiteSpace =						CharacterClasses.WhiteSpaceChars * (1,0)
	LineEnd =								CharacterClasses.LineEnd * (1,2)
	SingleQuotedString =		Sequences.SingleQuoted(CharacterClasses.AlphaNumChars)
	DoubleQuotedString =		Sequences.DoubleQuoted(CharacterClasses.AlphaNumChars)

class Identifiers:
	IntegerNumber =	(CharacterClasses.DecimalDigits * (1,0)).SetName("IntegerNumber")
	Name =					(CharacterClasses.AlphaNumChars * (1,0))
	Common =				(CharacterClasses.AlphaNumChars + Characters.Underline) * (1,0)
	Extended =			(CharacterClasses.AlphaNumChars + Characters.Underline + Characters.Dash) * (1,0)
	Restricted =		Sequence(((CharacterClasses.AlphaChars + Characters.Underline) * 1).SetName("FirstChar"), (CharacterClasses.AlphaNumChars + Characters.Underline).SetName("NextChars")).SetName("Id.Restricted")

class CommonKeywords:
	If =						Keyword("if")
	Then =					Keyword("then")
	ElIf =					Keyword("elif")
	ElsIf =					Keyword("elsif")
	ElseIf =				Keyword("elseif")
	Else =					Keyword("else")
	And =						Keyword("and")
	Or =						Keyword("or")
	Nand =					Keyword("nand")
	Nor =						Keyword("nor")
	Xor =						Keyword("xor")
	Xnor =					Keyword("xnor")
	Not =						Keyword("not")
	Abs =						Keyword("abs")
	Mod =						Keyword("mod")
	Rem =						Keyword("rem")
	Begin =					Keyword("begin")
	End =						Keyword("end")
	Const =					Keyword("const")
	Constant =			Keyword("constant")
	Public =				Keyword("public")
	Private =				Keyword("private")
	Friend =				Keyword("friend")
	Protected =			Keyword("protected")

class CommonOperators:
	Equal =					Keyword("=")
	Unequal_C =			Keyword("!=")
	Unequal_Basic =	Keyword("<>")
	Unequal_VHDL =	Keyword("/=")
	GreaterThan =		Keyword(">")
	GreaterEqual =	Keyword(">=")
	LessThan =			Keyword("<")
	LessEqual =			Keyword("<=")
	And =						Keyword("&&")
	Or =						Keyword("||")
	Xor =						Keyword("^")
	Not =						Keyword("!")
	BitAnd =				Keyword("&")
	BitOr =					Keyword("|")
	BitXor =				Keyword("^")
	BitNot =				Keyword("~")
	Mult =					Keyword("*")
	Div =						Keyword("/")
	IntDiv =				Keyword("\\")
	Mod =						Keyword("%")
	Pow =						Keyword("^")
	Plus =					Keyword("+")
	Minus =					Keyword("-")
	
FilenameChars =		(CharacterClasses.AlphaNumChars + Characters.Dot + Characters.Space + Characters.Underline + Characters.Dash).SetName("FilenameChars")
PathChars =				(FilenameChars + Characters.Slash + Characters.BackSlash).SetName("PathChars")

class FilesKeywords:
	If =						CommonKeywords.If
	Then =					CommonKeywords.Then
	ElseIf =				CommonKeywords.ElseIf
	Else =					CommonKeywords.Else
	End =						CommonKeywords.End
	
	Include =				Keyword("include")
	Library =				Keyword("library")
	VHDL =					Keyword("vhdl")
	
	
	Equal =					CommonOperators.Equal
	Unequal =				CommonOperators.Unequal_C
	GreaterThan =		CommonOperators.GreaterThan
	GreaterEqual =	CommonOperators.GreaterEqual
	LessThan =			CommonOperators.LessThan
	LessEqual =			CommonOperators.LessEqual
	And =						CommonKeywords.And
	Or =						CommonKeywords.Or
	Xor =						CommonKeywords.Xor
	Not =						CommonKeywords.Not
	
class FilesRules:
	Comment =				Sequence(Characters.Hash, All() - CharacterClasses.LineEnd)
	CommentLine =		Sequence(Rules.WhiteSpace, Comment)
	EmptyLine =			CharacterClasses.WhiteSpaceChars
	
	Include =				Sequence(FilesKeywords.Include,	Rules.WhiteSpace,																						Sequences.DoubleQuoted(PathChars))
	Library =				Sequence(FilesKeywords.Library,	Rules.WhiteSpace, Identifiers.Restricted, Rules.WhiteSpace, Sequences.DoubleQuoted(PathChars))
	VHDL =					Sequence(FilesKeywords.VHDL,		Rules.WhiteSpace, Identifiers.Restricted, Rules.WhiteSpace, Sequences.DoubleQuoted(PathChars))
	
	StatementList =			Forward("StatementList")
	
	# Expression =				Forward("Expression")
	# EqualExpression = 	Sequence(Characters.OpeningParentheses, Expression, Rules.WhiteSpace, FilesKeywords.Equal,		Rules.WhiteSpace, Expression, Characters.ClosingParentheses)
	# UnequalExpression = Sequence(Characters.OpeningParentheses, Expression, Rules.WhiteSpace, FilesKeywords.Unequal,	Rules.WhiteSpace, Expression, Characters.ClosingParentheses)
	# Expression <<=			Choice(Identifiers.Restricted, EqualExpression, UnequalExpression)
	
	Expression2 =					Forward("Expression2")
	EqualExpression2 = 		Sequence(Characters.OpeningParentheses, Identifiers.Restricted, Rules.WhiteSpace, FilesKeywords.Equal,		Rules.WhiteSpace, Identifiers.Restricted, Characters.ClosingParentheses)
	UnequalExpression2 =	Sequence(Characters.OpeningParentheses, Identifiers.Restricted, Rules.WhiteSpace, FilesKeywords.Unequal,	Rules.WhiteSpace, Identifiers.Restricted, Characters.ClosingParentheses)
	AndExpression2 =			Sequence(Characters.OpeningParentheses, EqualExpression2, Rules.WhiteSpace, FilesKeywords.And,	Rules.WhiteSpace, EqualExpression2, Characters.ClosingParentheses)
	Expression2 <<=				Choice(Identifiers.IntegerNumber, Identifiers.Restricted, EqualExpression2, UnequalExpression2, AndExpression2)
	
	# IfStmt =						Sequence(FilesKeywords.If,			Expression, FilesKeywords.Then)
	# ElseIfStmt =				Sequence(FilesKeywords.ElseIf,	Expression, FilesKeywords.Then)
	# ElseStmt =					FilesKeywords.Else
	# EndIf =							Sequence(FilesKeywords.End, Rules.WhiteSpace, FilesKeywords.If)
	# IfStatement =				Sequence(IfStmt, StatementList, ElseIfStmt, StatementList, ElseStmt, StatementList, EndIf)
	
	Statement =					Choice(CommentLine, Include, Library, VHDL)	#, IfStatement)
	StatementLine =			Sequence(Statement, Rules.LineEnd)
	StatementList <<=		Repeat(StatementLine)
	
	Document =					StatementList
	

print(FilesRules.Document)

Negative1 =				All() - Word("\n")
Negative =				Sequence(Negative1, Characters.NewLine, Keyword("blaze"))

StatementTest1 =	Choice(FilesKeywords.Include, FilesKeywords.Library, FilesKeywords.VHDL)
StatementTest2 =	Sequence(StatementTest1, Rules.LineEnd)
StatementTest3 =	Repeat(StatementTest2)



# input = "vhdl"
# print("="*80)
# print("parse keyword: {0}".format(input))
# try:
	# FilesKeywords.VHDL.parse(input)
# except ParserException as ex:
	# print(str(ex))

	
# input =	"poc"
# print("="*80)
# print("parse identifier: {0}".format(input))
# try:
	# CharacterClasses.LowerAlphaChars.parse(input)
# except ParserException as ex:
	# print(str(ex))

	
# input =	"pico\nblaze"
# print("="*80)
# print("parse identifier: {0}".format(input))
# try:
	# Negative.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "\"patrick\""
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# Rules.DoubleQuotedString.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "  # my comment"
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.CommentLine.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "vhdl    poc  \t\t  \"ocram_sdp.vhdl\""
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesKeywords.VHDL.parse(input)
# except ParserException as ex:
	# print(str(ex))
# try:
	# FilesRules.VHDL.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "include"
# print("="*80)
# print("parse statement test 1: {0}".format(input))
# try:
	# StatementTest1.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "include\n"
# print("="*80)
# print("parse statement test 2: {0}".format(input))
# try:
	# StatementTest2.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "include\nvhdl\n"
# print("="*80)
# print("parse statement test3: {0}".format(input))
# try:
	# StatementTest3.parse(input)
# except ParserException as ex:
	# print(str(ex))


# input = "Vendor"
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Expression.parse(input)
# except ParserException as ex:
	# print(str(ex))

input = "(Vendor = Xilinx)"
print("="*80)
print("parse string: {0}".format(input))
try:
	FilesRules.Expression2.parse(input)
except ParserException as ex:
	print(str(ex))

parserTree.render(view=True)

# input = "(Vendor = Xilinx)"
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Expression.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = "((Version = 2008) and (Vendor = Xilinx))"
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Expression2.parse(input, parserTree)
# except ParserException as ex:
	# print(str(ex))

# input = "((Version = 2008) and (Vendor = Xilinx))"
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Expression.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = """      #  my comment
# vhdl poc "file1.vhdl"
# include "common.files"
# library osvvm "osvvm/"
# """
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Document.parse(input)
# except ParserException as ex:
	# print(str(ex))

# input = """      #  my comment
# vhdl poc "file1.vhdl"
# include "common.files"
# library osvvm "osvvm/"
# if (vendor = xilinx) then
	# vhdl poc "xilinx.vhdl"
# else
	# vhdl poc "altera.vhdl"
# end if
# """
# print("="*80)
# print("parse string: {0}".format(input))
# try:
	# FilesRules.Document.parse(input)
# except ParserException as ex:
	# print(str(ex))





