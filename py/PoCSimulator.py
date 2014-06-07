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


#from pathlib import Path
#import os

#import re
#import shutil
#import string
#import subprocess
#import sys
#import textwrap

class PoCSimulator(object):
#	from platform import system
	
	__debug = False
	__verbose = False
#	__platform = system()

	def __init__(self, debug, verbose):
		self.__debug = debug
		self.__verbose = verbose

	def printDebug(self, message):
		if (self.__debug):
			print("DEBUG: " + message)
			
	def printVerbose(self, message):
		if (self.__verbose):
			print(message)

#	def getNamespaceForPrefix(self, namespacePrefix):
#		return self.__tbConfig['NamespacePrefixes'][namespacePrefix]
	
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
	
import PoCBase

class PoCSimulatorException(PoCBase.PoCException):
	def __init__(self, message):
		super(self.__class__, self).__init__()
		self.message = message

	def __str__(self):
		return self.message
	
class PoCTestbenchException(PoCSimulatorException):
	def __init__(self, pocEntity, testbench, message):
		super(self.__class__, self).__init__(message)
		self.pocEntity = pocEntity
		self.testbench = testbench
