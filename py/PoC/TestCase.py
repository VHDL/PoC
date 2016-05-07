# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:					Patrick Lehmann
#
# Python Class:			TODO
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
# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module PoC.Query")


from collections	import OrderedDict
from enum					import Enum, unique


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
	def __init__(self, name, parent):
		self._name =     name
		self._parent =   parent

	@property
	def Name(self):       return self._name
	@property
	def Parent(self):     return self._parent


class TestGroup(TestElement):
	def __init__(self, name, parent):
		super().__init__(name, parent)

		self._parent =     None
		self._testGroups = OrderedDict()
		self._testCases =  OrderedDict()

	def __getitem__(self, item):
		try:
			return self._testCases[item]
		except:
			return self._testGroups[item]

	def __setitem__(self, key, value):
		if isinstance(value, TestGroup):
			self._testGroups[key] = value
		elif isinstance(value, TestCase):
			self._testGroups[key] = value
		else:
			raise ValueError("Parameter 'value' is not of type TestGroup or TestCase")

	def __len__(self):
		return sum([len(group) for group in self._testGroups.values()]) + len(self._testCases)

	@property
	def TestGroups(self): return self._testGroups
	@property
	def TestCases(self):  return self._testCases


class TestRoot(TestGroup):
	def __init__(self):
		super().__init__("PoC", None)

		self._testGroups['arith'] =         TestGroup("arith", self)
		self._testGroups['io'] =            TestGroup("io", self)
		self._testGroups['io']['ddrio'] =     TestGroup("ddrio", self['io'])
		self._testGroups['io']['iic'] =       TestGroup("iic", self['io'])
		self._testGroups['sort'] =          TestGroup("sort", self)
		self._testGroups['sort']['softnet'] = TestGroup("sortnet", self['sort'])

	@property
	def ISAllPassed(self):
		return False

	def AddTestCase(self, testcase):
		self._testGroups['arith'].TestCases[testcase.Name] = testcase


class TestCase(TestElement):
	def __init__(self, testbench):
		super().__init__(testbench.Parent.Name, None)
		self._testbench =		testbench
		self._testGroup =		None
		self._status =			Status.Unknown
		self._warnings =		[]
		self._errors =			[]

	@property
	def Parent(self):           return self._parent
	@Parent.setter
	def Parent(self, value):    self._parent = value

	@property
	def TestGroup(self):        return self._testGroup
	@TestGroup.setter
	def TestGroup(self, value): self._testGroup = value

	@property
	def Status(self):           return self._status


