# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:				 	Patrick Lehmann
#
# Python Class:			GHDL specific classes
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
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module ToolChains.GHDL")


from Base.Executable				import *


class Configuration:
	__vendor =		None
	__shortName = "GTKWave"
	__LongName =	"GTKWave"
	__privateConfiguration = {
		"Windows": {
			"GHDL": {
				"Version":								"0.34dev",
				"InstallationDirectory":	None,
				"BinaryDirectory":				"${InstallationDirectory}/bin",
				"Backend":								"mcode"
			}
		},
		"Linux": {
			"GHDL": {
				"Version":								"0.34dev",
				"InstallationDirectory":	None,
				"BinaryDirectory":				"${InstallationDirectory}",
				"Backend":								"llvm"
			}
		}
	}

	def IsSupportedPlatform(self, Platform):
		return (Platform in self.__privateConfiguration)

	def GetSections(self, Platform):
		pass

	def manualConfigureForWindows(self):
		# Ask for installed GHDL
		isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
		isGHDL = isGHDL if isGHDL != "" else "Y"
		if (isGHDL  in ['p', 'P']):
			pass
		elif (isGHDL in ['n', 'N']):
			self.pocConfig['GHDL'] = OrderedDict()
		elif (isGHDL in ['y', 'Y']):
			ghdlDirectory =	input('GHDL installation directory [C:\Program Files (x86)\GHDL]: ')
			ghdlVersion =		input('GHDL version number [0.31]: ')
			print()

			ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "C:\Program Files (x86)\GHDL"
			ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"

			ghdlDirectoryPath = Path(ghdlDirectory)
			ghdlExecutablePath = ghdlDirectoryPath / "bin" / "ghdl.exe"

			if not ghdlDirectoryPath.exists():	raise BaseException("GHDL installation directory '%s' does not exist." % ghdlDirectory)
			if not ghdlExecutablePath.exists():	raise BaseException("GHDL is not installed.")

			self.pocConfig['GHDL']['Version'] = ghdlVersion
			self.pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
			self.pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}/bin'
			self.pocConfig['GHDL']['Backend'] = 'mcode'
		else:
			raise BaseException("unknown option")

	def manualConfigureForLinux(self):
		# Ask for installed GHDL
		isGHDL = input('Is GHDL installed on your system? [Y/n/p]: ')
		isGHDL = isGHDL if isGHDL != "" else "Y"
		if (isGHDL  in ['p', 'P']):
			pass
		elif (isGHDL in ['n', 'N']):
			self.pocConfig['GHDL'] = OrderedDict()
		elif (isGHDL in ['y', 'Y']):
			ghdlDirectory =	input('GHDL installation directory [/usr/bin]: ')
			ghdlVersion =		input('GHDL version number [0.31]: ')
			print()

			ghdlDirectory = ghdlDirectory if ghdlDirectory != "" else "/usr/bin"
			ghdlVersion = ghdlVersion if ghdlVersion != "" else "0.31"

			ghdlDirectoryPath = Path(ghdlDirectory)
			ghdlExecutablePath = ghdlDirectoryPath / "ghdl"

			if not ghdlDirectoryPath.exists():	raise BaseException("GHDL installation directory '%s' does not exist." % ghdlDirectory)
			if not ghdlExecutablePath.exists():	raise BaseException("GHDL is not installed.")

			self.pocConfig['GHDL']['Version'] = ghdlVersion
			self.pocConfig['GHDL']['InstallationDirectory'] = ghdlDirectoryPath.as_posix()
			self.pocConfig['GHDL']['BinaryDirectory'] = '${InstallationDirectory}'
			self.pocConfig['GHDL']['Backend'] = 'llvm'
		else:
			raise BaseException("unknown option")


class GHDL(Executable):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		if (platform == "Windows"):			executablePath = binaryDirectoryPath/ "ghdl.exe"
		elif (platform == "Linux"):			executablePath = binaryDirectoryPath/ "ghdl"
		else:																						raise PlatformNotSupportedException(platform)
		super().__init__(platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

		if (platform == "Windows"):
			if (backend not in ["mcode"]):								raise SimulatorException("GHDL for Windows does not support backend '{0}'.".format(backend))
		elif (platform == "Linux"):
			if (backend not in ["gcc", "llvm", "mcode"]):	raise SimulatorException("GHDL for Linux does not support backend '{0}'.".format(backend))

		self._binaryDirectoryPath =	binaryDirectoryPath
		self._backend =							backend
		self._version =							version

	@property
	def BinaryDirectoryPath(self):
		return self._binaryDirectoryPath

	@property
	def Backend(self):
		return self._backend

	@property
	def Version(self):
		return self._version

	class Executable(metaclass=ExecutableArgument):
		pass

	class CmdAnalyze(metaclass=ShortFlagArgument):
		_name =		"a"

	class CmdElaborate(metaclass=ShortFlagArgument):
		_name =		"e"

	class CmdRun(metaclass=ShortFlagArgument):
		_name =		"r"

	class FlagVerbose(metaclass=ShortFlagArgument):
		_name =		"v"

	class FlagExplicit(metaclass=ShortFlagArgument):
		_name =		"fexplicit"

	class FlagRelaxedRules(metaclass=ShortFlagArgument):
		_name =		"frelaxed-rules"

	class FlagWarnBinding(metaclass=LongFlagArgument):
		_name =		"warn-binding"

	class FlagNoVitalChecks(metaclass=LongFlagArgument):
		_name =		"no-vital-checks"

	class FlagMultiByteComments(metaclass=LongFlagArgument):
		_name =		"mb-comments"

	class FlagSynBinding(metaclass=LongFlagArgument):
		_name =		"syn-binding"

	class FlagPSL(metaclass=ShortFlagArgument):
		_name =		"fpsl"

	class SwitchIEEEFlavor(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"ieee"

	class SwitchVHDLVersion(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"std"

	class SwitchVHDLLibrary(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"work"

	class ArgListLibraryReferences(metaclass=ValuedFlagListArgument):
		_pattern =	"-{0}{1}"
		_name =			"P"

	class ArgSourceFile(metaclass=PathArgument):
		pass

	class ArgTopLevel(metaclass=StringArgument):
		pass

	Parameters = CommandLineArgumentList(
		Executable,
		CmdAnalyze,
		CmdElaborate,
		CmdRun,
		FlagVerbose,
		FlagExplicit,
		FlagRelaxedRules,
		FlagWarnBinding,
		FlagNoVitalChecks,
		FlagMultiByteComments,
		FlagSynBinding,
		FlagPSL,
		SwitchIEEEFlavor,
		SwitchVHDLVersion,
		SwitchVHDLLibrary,
		ArgListLibraryReferences,
		ArgSourceFile,
		ArgTopLevel
	)

	class SwitchIEEEAsserts(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"ieee-asserts"

	class SwitchVCDWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"vcd"

	class SwitchVCDGZWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"vcdgz"

	class SwitchFastWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"fst"

	class SwitchGHDLWaveform(metaclass=ShortValuedFlagArgument):
		_pattern =	"--{0}={1}"
		_name =			"wave"

	RunOptions = CommandLineArgumentList(
		SwitchIEEEAsserts,
		SwitchVCDWaveform,
		SwitchVCDGZWaveform,
		SwitchFastWaveform,
		SwitchGHDLWaveform
	)

	def GetGHDLAnalyze(self):
		ghdl = GHDLAnalyze(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		for param in ghdl.Parameters:
			if (param is not ghdl.Executable):
				ghdl.Parameters[param] = None
		ghdl.Parameters[ghdl.CmdAnalyze] = True
		return ghdl

	def GetGHDLElaborate(self):
		ghdl = GHDLElaborate(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		for param in ghdl.Parameters:
			if (param is not ghdl.Executable):
				ghdl.Parameters[param] = None
		ghdl.Parameters[ghdl.CmdElaborate] = True
		return ghdl

	def GetGHDLRun(self):
		ghdl = GHDLRun(self._platform, self._binaryDirectoryPath, self._version, self._backend, logger=self.Logger)
		for param in ghdl.Parameters:
			if (param is not ghdl.Executable):
				ghdl.Parameters[param] = None
		ghdl.Parameters[ghdl.CmdRun] =			True
		return ghdl


class GHDLAnalyze(GHDL):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, logger=logger)

	def Analyze(self):
		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		_indent = "    "
		print(_indent + "ghdl analyze messages for '{0}.{1}'".format("??????", "??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)


class GHDLElaborate(GHDL):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, logger=logger)

	def Elaborate(self):
		if (self._backend == "mcode"):		return

		parameterList = self.Parameters.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		_indent = "    "
		print(_indent + "ghdl elaboration messages for '{0}.{1}'".format("??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)

class GHDLRun(GHDL):
	def __init__(self, platform, binaryDirectoryPath, version, backend, logger=None):
		super().__init__(platform, binaryDirectoryPath, version, backend, logger=logger)

	def Run(self):
		parameterList = self.Parameters.ToArgumentList()
		parameterList += self.RunOptions.ToArgumentList()

		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		_indent = "    "
		print(_indent + "ghdl run messages for '{0}.{1}'".format("??????", "??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)
