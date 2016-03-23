# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 	Patrick Lehmann
# 
# Python Class:			TODO
# 
# Description:
# ------------------------------------
#		TODO:
#		- 
#		- 
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
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module Base.Executable")

# load dependencies
from enum										import Enum, unique
from colorama								import Fore as Foreground
from pathlib								import Path
from subprocess							import check_output	as Subprocess_Run
from subprocess							import STDOUT				as Subprocess_StdOut

from Base.Exceptions				import *
from Base.Logging						import ILogable

class CommandLineArgument(type):
	_value = None
	
	# def __new__(mcls, name, bases, nmspc):
		# print("CommandLineArgument.new: %s - %s" % (name, nmspc))
		# return super(CommandLineArgument, mcls).__new__(mcls, name, bases, nmspc)

class ExecutableArgument(CommandLineArgument):
	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if isinstance(value, str):			self._value = value
		elif isinstance(value, Path):		self._value = str(value)
		else:														raise ValueError("Parameter 'value' is not of type str or Path.")

	def __str__(self):
		if (self._value is None):		return ""
		else:												return self._value

	def AsArgument(self):
		if (self._value is None):		raise ValueError("Executable argument is still empty.")
		else:												return self._value

class PathArgument(CommandLineArgument):
	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):
			self._value = None
		elif isinstance(value, str):
			self._value = value
		elif isinstance(value, Path):
			self._value = str(value)
		else:
			raise ValueError("Parameter 'value' is not of type str or Path.")

	def __str__(self):
		if (self._value is None):			return ""
		else:													return "\"" + self._value + "\""

	def AsArgument(self):
		if (self._value is None):			return None
		else:													return self._value

class FlagArgument(CommandLineArgument):
	_pattern =		"{0}"

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, bool):	self._value = value
		else:													raise ValueError("Parameter 'value' is not of type bool.")
	
	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._name)
		else:													return ""
	
	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._name)
		else:													return None

class ShortFlagArgument(FlagArgument):
	_pattern =	"-{0}"

class LongFlagArgument(FlagArgument):
	_pattern =	"--{0}"

class StringArgument(CommandLineArgument):
	_pattern =	"{0}"
	_value =		None

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:
				self._value = str(value)
			except Exception as ex:
				raise ValueError("Parameter 'value' cannot be converted to type str.") from ex

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._value)
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._value)
		else:													return None


class ValuedFlagArgument(CommandLineArgument):
	_pattern = "-{0}={1}"

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:
				self._value = str(value)
			except Exception as ex:
				raise ValueError("Parameter 'value' cannot be converted to type str.") from ex
	
	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._name, self._value)
		else:													return ""
	
	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._name, self._value)
		else:													return None

class TupleArgument(CommandLineArgument):
	_pattern1 = "-{0}"
	_pattern2 = "{0}"

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:
				self._value = str(value)
			except Exception as ex:
				raise ValueError("Parameter 'value' cannot be converted to type str.") from ex
	
	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern1.format(self._name) + " " + self._pattern2.format(self._value)
		else:													return ""
	
	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return [self._pattern1.format(self._name), self._pattern2.format(self._value)]
		else:													return None

class CommandLineArgumentList(list):
	def __init__(self, *args):
		super().__init__()
		for arg in args:
			self.append(arg)

	def __getitem__(self, key):
		i = self.index(key)
		return super().__getitem__(i).Value
	
	def __setitem__(self, key, value):
		i = self.index(key)
		super().__getitem__(i).Value = value
	
	def __delitem__(self, key):
		raise TypeError("'CommandLineArgumentList' object doesn't support item deletion")
	
	def ToArgumentList(self):
		result = []
		for item in self:
			arg = item.AsArgument()
			if (arg is None):						pass
			elif isinstance(arg, str):	result.append(arg)
			elif isinstance(arg, list):	result += arg
			else:												raise TypeError()
		return result

class Executable(ILogable):
	def __init__(self, platform, executablePath, defaultParameters=[], logger=None):
		ILogable.__init__(self, logger)
		
		self._platform = platform
		
		if isinstance(executablePath, str):							executablePath = Path(executablePath)
		elif (not isinstance(executablePath, Path)):		raise ValueError("Parameter 'executablePath' is not of type str or Path.")
		# if (not executablePath.exists()):								raise SimulatorException("Executable '{0}' can not be found.".format(str(executablePath))) from FileNotFoundError(str(executablePath))
		
		# prepend the executable
		defaultParameters.insert(0, str(executablePath))
		
		self._executablePath =		executablePath
		self._defaultParameters =	defaultParameters
	
	@property
	def Path(self):
		return self._executablePath
	
	@property
	def DefaultParameters(self):
		return self._defaultParameters
	
	@DefaultParameters.setter
	def DefaultParameters(self, value):
		self._defaultParameters = value
	
	def StartProcess(self, parameterList):
		# return "blubs"
		return Subprocess_Run(parameterList, stderr=Subprocess_StdOut, shell=False, universal_newlines=True)

# class PoCSimulatorTestbench(object):
	# pocEntity = None
	# testbenchName = ""
	# simulationResult = False
	
	# def __init__(self, pocEntity, testbenchName):
		# self.pocEntity = pocEntity
		# self.testbenchName = testbenchName

# class PoCSimulatorTestbenchGroup(object):
	# pocEntity = None
	# members = {}
	
	# def __init__(self, pocEntity):
		# self.pocEntity = pocEntity
	
	# def add(self, pocEntity, testbench):
		# self.members[str(pocEntity)] = testbench
		
	# def __getitem__(self, key):
		# return self.members[key]
	