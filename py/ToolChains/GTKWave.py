# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:				 	Patrick Lehmann
#
# Python Class:			GTKWave specific classes
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
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module ToolChains.GTKWave")


from Base.Executable				import *


class Configuration:
	__vendor =		None
	__shortName =	"GTKWave"
	__LongName =	"GTKWave"
	__privateConfiguration = {
		"Windows": {
			"GTKWave": {
				"Version":								"3.3.70",
				"InstallationDirectory":	None,
				"BinaryDirectory":				"${InstallationDirectory}/bin"
			}
		},
		"Linux": {
			"GTKWave": {
				"Version":								"3.3.70",
				"InstallationDirectory":	None,
				"BinaryDirectory":				"${InstallationDirectory}"
			}
		}
	}

	def IsSupportedPlatform(self, Platform):
		return (Platform in self.__privateConfiguration)

	def GetSections(self, Platform):
		pass

	def manualConfigureForWindows(self) :
		# Ask for installed GTKWave
		isGTKW = input('Is GTKWave installed on your system? [Y/n/p]: ')
		isGTKW = isGTKW if isGTKW != "" else "Y"
		if (isGTKW in ['p', 'P']) :
			pass
		elif (isGTKW in ['n', 'N']) :
			self.pocConfig['GTKWave'] = OrderedDict()
		elif (isGTKW in ['y', 'Y']) :
			gtkwDirectory = input('GTKWave installation directory [C:\Program Files (x86)\GTKWave]: ')
			gtkwVersion = input('GTKWave version number [3.3.61]: ')
			print()

			gtkwDirectory = gtkwDirectory if gtkwDirectory != "" else "C:\Program Files (x86)\GTKWave"
			gtkwVersion = gtkwVersion if gtkwVersion != "" else "3.3.61"

			gtkwDirectoryPath = Path(gtkwDirectory)
			gtkwExecutablePath = gtkwDirectoryPath / "bin" / "gtkwave.exe"

			if not gtkwDirectoryPath.exists() :  raise BaseException(
				"GTKWave installation directory '%s' does not exist." % gtkwDirectory)
			if not gtkwExecutablePath.exists() :  raise BaseException("GTKWave is not installed.")

			self.pocConfig['GTKWave']['Version'] = gtkwVersion
			self.pocConfig['GTKWave']['InstallationDirectory'] = gtkwDirectoryPath.as_posix()
			self.pocConfig['GTKWave']['BinaryDirectory'] = '${InstallationDirectory}/bin'
		else :
			raise BaseException("unknown option")

	def manualConfigureForLinux(self) :
		# Ask for installed GTKWave
		isGTKW = input('Is GTKWave installed on your system? [Y/n/p]: ')
		isGTKW = isGTKW if isGTKW != "" else "Y"
		if (isGTKW in ['p', 'P']) :
			pass
		elif (isGTKW in ['n', 'N']) :
			self.pocConfig['GTKWave'] = OrderedDict()
		elif (isGTKW in ['y', 'Y']) :
			gtkwDirectory = input('GTKWave installation directory [/usr/bin]: ')
			gtkwVersion = input('GTKWave version number [3.3.61]: ')
			print()

			gtkwDirectory = gtkwDirectory if gtkwDirectory != "" else "/usr/bin"
			gtkwVersion = gtkwVersion if gtkwVersion != "" else "3.3.61"

			gtkwDirectoryPath = Path(gtkwDirectory)
			gtkwExecutablePath = gtkwDirectoryPath / "gtkwave"

			if not gtkwDirectoryPath.exists() :  raise BaseException(
				"GTKWave installation directory '%s' does not exist." % gtkwDirectory)
			if not gtkwExecutablePath.exists() :  raise BaseException("GTKWave is not installed.")

			self.pocConfig['GTKWave']['Version'] = gtkwVersion
			self.pocConfig['GTKWave']['InstallationDirectory'] = gtkwDirectoryPath.as_posix()
			self.pocConfig['GTKWave']['BinaryDirectory'] = '${InstallationDirectory}'
		else :
			raise BaseException("unknown option")



class GTKWave(Executable):
	def __init__(self, platform, binaryDirectoryPath, version, defaultParameters=[]):
		if (platform == "Windows"):			executablePath = binaryDirectoryPath/ "gtkwave.exe"
		elif (platform == "Linux"):			executablePath = binaryDirectoryPath/ "gtkwave"
		else:																						raise PlatformNotSupportedException(self._platform)
		super().__init__(platform, executablePath, defaultParameters)

		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =			version

		self._dumpFile =		None
		self._saveFile =		None

	@property
	def BinaryDirectoryPath(self):
		return self._binaryDirectoryPath

	@property
	def Version(self):
		return self._version

	@property
	def DumpFile(self):
		return self._dumpFile
	@DumpFile.setter
	def DumpFile(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._dumpFile is None):
			self._defaultParameters.append("--dump={0}".format(value))
			self._dumpFile = value
		elif (self._dumpFile != value):
			self._defaultParameters.remove("--dump={0}".format(self._dumpFile))
			self._defaultParameters.append("--dump={0}".format(value))
			self._dumpFile = value

	@property
	def SaveFile(self):
		return self._saveFile
	@SaveFile.setter
	def SaveFile(self, value):
		if (not isinstance(value, str)):								raise ValueError("Parameter 'value' is not of type str.")
		if (self._saveFile is None):
			self._defaultParameters.append("--save={0}".format(value))
			self._saveFile = value
		elif (self._saveFile != value):
			self._defaultParameters.remove("--save={0}".format(self._saveFile))
			self._defaultParameters.append("--save={0}".format(value))
			self._saveFile = value

	def View(self, dumpFile):
		if isinstance(dumpFile, str):			self.DumpFile = dumpFile
		elif isinstance(dumpFile, Path):	self.DumpFile = str(dumpFile)
		else:																						raise ValueError("Parameter 'dumpFile' has an unsupported type.")

		self._LogDebug("call gtkwave: {0}".format(str(self._defaultParameters)))
		self._LogVerbose("    command: {0}".format(" ".join(self._defaultParameters)))

		_indent = "    "
		print(_indent + "GTKWave messages for '{0}.{1}'".format("??????"))  # self.VHDLLibrary, topLevel))
		print(_indent + "-" * 80)
		try:
			self.StartProcess(parameterList)
			for line in self.GetReader():
				print(_indent + line)
		except Exception as ex:
			raise ex  # SimulatorException() from ex
		print(_indent + "-" * 80)

