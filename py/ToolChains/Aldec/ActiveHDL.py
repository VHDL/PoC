# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:				 	Patrick Lehmann
#
# Python Class:			Aldec Active-HDL specific classes
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
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module ToolChains.Aldec.ActiveHDL")


from Base.Exceptions							import ToolChainException, PlatformNotSupportedException
from Base.Logging									import LogEntry, Severity
from Base.Executable							import *


class ActiveHDLException(ToolChainException):
	pass

class Configuration:
	pass


class ActiveHDLMixIn:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self._logger =							logger

class ActiveHDL(ActiveHDLMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		ActiveHDLMixIn.__init__(self, platform, binaryDirectoryPath, version, logger)

	def GetVHDLLibraryTool(self):
		return ActiveHDLVHDLLibraryTool(self._platform, self._binaryDirectoryPath, self._version, logger=self._logger)

	def GetVHDLCompiler(self):
		return VHDLCompiler(self._platform, self._binaryDirectoryPath, self._version, logger=self._logger)

	def GetSimulator(self):
		return StandaloneSimulator(self._platform, self._binaryDirectoryPath, self._version, logger=self._logger)


class VHDLCompiler(Executable, ActiveHDLMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		ActiveHDLMixIn.__init__(self, platform, binaryDirectoryPath, version, logger=logger)

		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vcom.exe"
		# elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vcom"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class FlagNoRangeCheck(metaclass=LongFlagArgument):
		_name =		"norangecheck"
		_value =	None

	class SwitchVHDLVersion(metaclass=ShortValuedFlagArgument):
		_pattern =	"-{1}"
		_name =			""
		_value =		None

	class SwitchVHDLLibrary(metaclass=ShortTupleArgument):
		_name =		"work"
		_value =	None

	class ArgSourceFile(metaclass=PathArgument):
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		FlagNoRangeCheck,
		SwitchVHDLVersion,
		SwitchVHDLLibrary,
		ArgSourceFile
	)

	# -reorder                      enables automatic file ordering
  # -O[0 | 1 | 2 | 3]             set optimization level
	# -93                                conform to VHDL 1076-1993
  # -2002                              conform to VHDL 1076-2002 (default)
  # -2008                              conform to VHDL 1076-2008
	# -relax                             allow 32-bit integer literals
  # -incr                              switching compiler to fast incremental mode

	def Compile(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		_indent = "    "
		print(_indent + "acom messages for '{0}.{1}'".format("??????", "??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)


class StandaloneSimulator(Executable, ActiveHDLMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		ActiveHDLMixIn.__init__(self, platform, binaryDirectoryPath, version, logger=logger)

		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vsimsa.exe"
		# elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vsimsa"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	class SwitchBatchCommand(metaclass=ShortTupleArgument):
		_name =		"do"
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		SwitchBatchCommand
	)

	def Simulate(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		self._LogDebug("    tcl commands: {0}".format(self.Parameters[self.SwitchBatchCommand]))

		_indent = "    "
		try:
			self.StartProcess(parameterList)
		except Exception as ex:
			raise ActiveHDLException("Failed to launch vsimsa run.") from ex

		hasOutput = False
		try:
			filter = SimulatorFilter(self.GetReader())
			iterator = iter(filter)

			line = next(iterator)
			line.Indent(2)
			hasOutput = True
			vhdlLibraryName =	"?????"
			topLevel =				"?????"
			self._LogNormal(_indent + "vsimsa messages for '{0}.{1}'".format(vhdlLibraryName, topLevel))
			self._LogNormal(_indent + "-" * 80)
			self._Log(line)

			while True:
				line = next(iterator)
				line.Indent(2)
				self._Log(line)

		except StopIteration as ex:
			pass
		except ActiveHDLException:
			raise
		except Exception as ex:
			raise ActiveHDLException("Error while executing vsimsa.") from ex
		finally:
			if hasOutput:
				print(_indent + "-" * 80)


class Simulator(Executable, ActiveHDLMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		ActiveHDLMixIn.__init__(self, platform, binaryDirectoryPath, version, logger=logger)

		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vsimsa.exe"
		# elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vsimsa"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	# class FlagVerbose(metaclass=ShortFlagArgument):
	# 	_name =		"v"
	# 	_value =	None
	#
	# class FlagOptimization(metaclass=ShortFlagArgument):
	# 	_name =		"vopt"
	# 	_value =	None
	#
	# class FlagCommandLineMode(metaclass=ShortFlagArgument):
	# 	_name =		"c"
	# 	_value =	None
	#
	# class SwitchTimeResolution(metaclass=ShortTupleArgument):
	# 	_name =		"t"
	# 	_value =	None

	class SwitchBatchCommand(metaclass=ShortTupleArgument):
		_name =		"do"

	# class SwitchTopLevel(metaclass=ShortValuedFlagArgument):
	# 	_name =		""
	# 	_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		# FlagVerbose,
		# FlagOptimization,
		# FlagCommandLineMode,
		# SwitchTimeResolution,
		SwitchBatchCommand
		# SwitchTopLevel
	)

	# units = ("fs", "ps", "us", "ms", "sec", "min", "hr")

	def Simulate(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))
		self._LogDebug("    tcl commands: {0}".format(self.Parameters[self.SwitchBatchCommand]))

		_indent = "    "
		print(_indent + "vsimsa messages for '{0}.{1}'".format("??????", "??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)


class ActiveHDLVHDLLibraryTool(Executable, ActiveHDLMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		ActiveHDLMixIn.__init__(self, platform, binaryDirectoryPath, version, logger=logger)

		if (self._platform == "Windows"):		executablePath = binaryDirectoryPath / "vlib.exe"
		# elif (self._platform == "Linux"):		executablePath = binaryDirectoryPath / "vlib"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

	class Executable(metaclass=ExecutableArgument):
		_value =	None

	# class FlagVerbose(metaclass=FlagArgument):
	# 	_name =		"-v"
	# 	_value =	None

	class SwitchLibraryName(metaclass=StringArgument):
		_value =	None

	Parameters = CommandLineArgumentList(
		Executable,
		# FlagVerbose,
		SwitchLibraryName
	)

	def CreateLibrary(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		_indent = "    "
		print(_indent + "alib messages for '{0}.{1}'".format("??????", "??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)

					# # assemble acom command as list of parameters
					# parameterList = [
						# str(aComExecutablePath),
						# '-O3',
						# '-relax',
						# '-l', 'acom.log',
						# vhdlStandard,
						# '-work', vhdlLibraryName,
						# str(vhdlFilePath)
					# ]
		# parameterList = [
			# str(aSimExecutablePath)#,
			# # '-vopt',
			# # '-t', '1fs',
		# ]


def SimulatorFilter(gen):
	#warningRegExpPattern =	".+?:\d+:\d+:warning: .*"		# <Path>:<line>:<column>:warning: <message>
	#errorRegExpPattern =		".+?:\d+:\d+: .*"  					# <Path>:<line>:<column>: <message>

	#warningRegExp =	re_compile(warningRegExpPattern)
	#errorRegExp =		re_compile(errorRegExpPattern)

	lineno = 0
	for line in gen:
		if (lineno < 2):
			lineno += 1
			if ("Linking in memory" in line):
				yield LogEntry(line, Severity.Verbose)
			elif ("Starting simulation" in line):
				yield LogEntry(line, Severity.Verbose)
		else:
			yield LogEntry(line, Severity.Normal)
