from lib.Parser import MatchingParserResult, MismatchingParserResult


class CodeDOMObject():
	@classmethod
	def GetParser(cls):
		raise NotImplementedError("Abstract method.")

	@classmethod
	def Parse(cls, generator):
		parser = cls.GetParser()
		parser.send(None)

		try:
			for block in generator:
				parser.send(block)
		except MatchingParserResult as ex:
			return ex.value
		except MismatchingParserResult as ex:
			print("ERROR: {0}".format(ex.value))


class Model(CodeDOMObject):
	def __init__(self):
		self._entities =      []
		self._packages =      []
		self._documents =     []

class Document(CodeDOMObject):
	def __init__(self):
		self._header =        ""
		self._entities =      []
		self._architectures = []
		self._packages =      []
		self._packagebodies = []




class Entity(CodeDOMObject):
	def __init__(self):
		self._genericList = GenericList()
		self._portList =    PortList()

class GenericList(CodeDOMObject):
	def __init__(self):
		self._generics = []

	def __bool__(self):
		return bool(self._generics)

class Generic(CodeDOMObject):
	def __init__(self):
		self._name =  ""
		self._type =  None

class PortList(CodeDOMObject):
	def __init__(self):
		self._ports = []

	def __bool__(self):
		return bool(self._ports)


class Port(CodeDOMObject):
	def __init__(self):
		self._name =  ""
		self._mode =  None
		self._type =  None

class Type(CodeDOMObject):
	pass

class ScalarType(Type):
	pass

class EnumeratedType(ScalarType):
	pass

class ArrayType(Type):
	pass

class Architecture(CodeDOMObject):
	pass

class Package(CodeDOMObject):
	pass

class PackageBody(CodeDOMObject):
	pass

class PortDeclaration(CodeDOMObject):
	pass

class GenericDeclaration(CodeDOMObject):
	pass
