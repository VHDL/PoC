# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Python Class:			TODO
# 
# Authors:				 	Patrick Lehmann
# 
# Description:
# ------------------------------------
#		TODO:
#		- 
#		- 
#
# License:
# ==============================================================================
# Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

# entry point
if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from sys import exit

	print("========================================================================")
	print("                  PoC Library - Python Class PoCSimulator               ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)

import PoC
from libDecorators import property

class PoCSimulator(object):
	__host =				None
	
	__debug =				False
	__verbose =			False
	__quiet =				False
	__showLogs =		False
	__showReport =	False

	def __init__(self, host, showLogs, showReport):
		self.__host =				host
		self.__debug =			host.debug
		self.__verbose =		host.verbose
		self.__quiet =			host.quiet
		self.__showLogs =		showLogs
		self.__showReport =	showReport

	# class properties
	# ============================================================================
	@property
	def debug():
		def fget(self):
			return self.__debug
	
	@property
	def verbose():
		def fget(self):
			return self.__verbose
	
	@property
	def quiet():
		def fget(self):
			return self.__quiet	

	@property
	def host():
		def fget(self):
			return self.__host
	
	@property
	def showLogs():
		def fget(self):
			return self.__showLogs
	
	@property
	def showReport():
		def fget(self):
			return self.__showReport

	# print messages
	# ============================================================================
	def printDebug(self, message):
		if (self.debug):
			print("DEBUG: " + message)
	
	def printVerbose(self, message):
		if (self.verbose):
			print(message)
	
	def printNonQuiet(self, message):
		if (not self.quiet):
			print(message)

	def checkSimulatorOutput(self, simulatorOutput):
		matchPos = simulatorOutput.find("SIMULATION RESULT = ")
		if (matchPos >= 0):
			if (simulatorOutput[matchPos + 20 : matchPos + 26] == "PASSED"):
				return True
			elif (simulatorOutput[matchPos + 20: matchPos + 26] == "FAILED"):
				return False
			else:
				raise PoCSimulatorException()
		else:
			raise PoCSimulatorException()


class PoCSimulatorTestbench(object):
	pocEntity = None
	testbenchName = ""
	simulationResult = False
	
	def __init__(self, pocEntity, testbenchName):
		self.pocEntity = pocEntity
		self.testbenchName = testbenchName

class PoCSimulatorTestbenchGroup(object):
	pocEntity = None
	members = {}
	
	def __init__(self, pocEntity):
		self.pocEntity = pocEntity
	
	def add(self, pocEntity, testbench):
		self.members[str(pocEntity)] = testbench
		
	def __getitem__(self, key):
		return self.members[key]
	
		
class PoCSimulatorException(PoC.PoCException):
	def __init__(self, message=""):
		super().__init__(message)
		self.message = message
	
class PoCTestbenchException(PoCSimulatorException):
	def __init__(self, pocEntity, testbench, message):
		super().__init__(message)
		self.pocEntity = pocEntity
		self.testbench = testbench
