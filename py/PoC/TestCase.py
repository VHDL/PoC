from enum import Enum, unique


@unique
class Status(Enum):
	Unknown =							0
	SystemError =					1
	AnalyzeError =				2
	ElaborationError =		3
	SimulationError =			4
	SimulationFailed =		10
	SimulationNoAsserts =	15
	SimulationSuccess =		20


class TestElement:
	def __init__(self):
		self._testGroup = 	None
		self._testGroups = 	[]
		self._testCases =		[]

	@property
	def TestGroup(self):	return self._testGroup
	@property
	def TestGroups(self):	return self._testGroups
	@property
	def TestCases(self):	return self._testCases


class TestGroup(TestElement):
	def __init__(self):
		super().__init__()


class TestCase:
	def __init__(self):
		self._testbench =		None
		self._testGroup =		None
		self._status =			Status.Unknwon
		self._warnings =		[]
		self._errors =			[]


