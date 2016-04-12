# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:					Patrick Lehmann
#
# Python Class:			Altera QuartusII specific classes
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
from Base.Exceptions import PlatformNotSupportedException

if __name__ != "__main__":
	# place library initialization code here
	pass
else:
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module ToolChains.Altera.QuartusII")


from collections									import OrderedDict
from pathlib											import Path

from Base.Executable							import Executable, ExecutableArgument, LongFlagArgument, ShortValuedFlagArgument, ShortTupleArgument, PathArgument, \
	ShortFlagArgument, CommandLineArgumentList
from Base.Configuration						import Configuration as BaseConfiguration, ConfigurationException
from Base.Project									import Project as BaseProject, ProjectFile
from Base.ToolChain								import ToolChainException


class QuartusIIException(ToolChainException):
	pass

class Configuration(BaseConfiguration):
	def manualConfigureForWindows(self) :
		# Ask for installed Altera Quartus-II
		isAlteraQuartusII = input('Is Altera Quartus-II installed on your system? [Y/n/p]: ')
		isAlteraQuartusII = isAlteraQuartusII if isAlteraQuartusII != "" else "Y"
		if (isAlteraQuartusII in ['p', 'P']) :
			pass
		elif (isAlteraQuartusII in ['n', 'N']) :
			self.pocConfig['Altera.QuartusII'] = OrderedDict()
		elif (isAlteraQuartusII in ['y', 'Y']) :
			alteraDirectory = input('Altera installation directory [C:\Altera]: ')
			quartusIIVersion = input('Altera QuartusII version number [15.0]: ')
			print()


			alteraDirectory = alteraDirectory if alteraDirectory != ""  else "C:\Altera"
			quartusIIVersion = quartusIIVersion if quartusIIVersion != ""  else "15.0"

			alteraDirectoryPath = Path(alteraDirectory)
			quartusIIDirectoryPath = alteraDirectoryPath / quartusIIVersion / "quartus"

			if not alteraDirectoryPath.exists() :    raise ConfigurationException(
				"Altera installation directory '%s' does not exist." % alteraDirectory)
			if not quartusIIDirectoryPath.exists() :  raise ConfigurationException(
				"Altera QuartusII version '%s' is not installed." % quartusIIVersion)

			self.pocConfig['Altera']['InstallationDirectory'] = alteraDirectoryPath.as_posix()
			self.pocConfig['Altera.QuartusII']['Version'] = quartusIIVersion
			self.pocConfig['Altera.QuartusII']['InstallationDirectory'] = '${Altera:InstallationDirectory}/${Version}'
			self.pocConfig['Altera.QuartusII']['BinaryDirectory'] = '${InstallationDirectory}/quartus/bin64'

			# Ask for installed Altera ModelSimAltera
			isAlteraModelSim = input('Is ModelSim - Altera Edition installed on your system? [Y/n/p]: ')
			isAlteraModelSim = isAlteraModelSim if isAlteraModelSim != "" else "Y"
			if (isAlteraModelSim in ['p', 'P']) :
				pass
			elif (isAlteraModelSim in ['n', 'N']) :
				self.pocConfig['Altera.ModelSim'] = OrderedDict()
			elif (isAlteraModelSim in ['y', 'Y']) :
				alteraModelSimVersion = input('ModelSim - Altera Edition version number [10.1e]: ')

				alteraModelSimDirectoryPath = alteraDirectoryPath / quartusIIVersion / "modelsim_ase"

				if not alteraModelSimDirectoryPath.exists() :  raise BaseException(
					"ModelSim - Altera Edition installation directory '%s' does not exist." % str(alteraModelSimDirectoryPath))

				self.pocConfig['Altera.ModelSim']['Version'] = alteraModelSimVersion
				self.pocConfig['Altera.ModelSim'][
					'InstallationDirectory'] = '${Altera:InstallationDirectory}/${Altera.QuartusII:Version}/modelsim_ase'
				self.pocConfig['Altera.ModelSim']['BinaryDirectory'] = '${InstallationDirectory}/win32aloem'
			else :
				raise ConfigurationException("unknown option")
		else :
			raise ConfigurationException("unknown option")

	def manualConfigureForLinux(self) :
		# Ask for installed Altera Quartus-II
		isAlteraQuartusII = input('Is Altera Quartus-II installed on your system? [Y/n/p]: ')
		isAlteraQuartusII = isAlteraQuartusII if isAlteraQuartusII != "" else "Y"
		if (isAlteraQuartusII in ['p', 'P']) :
			pass
		elif (isAlteraQuartusII in ['n', 'N']) :
			self.pocConfig['Altera.QuartusII'] = OrderedDict()
		elif (isAlteraQuartusII in ['y', 'Y']) :
			alteraDirectory = input('Altera installation directory [/opt/Altera]: ')
			quartusIIVersion = input('Altera QuartusII version number [15.0]: ')
			print()

			alteraDirectory = alteraDirectory if alteraDirectory != ""  else "/opt/Altera"
			quartusIIVersion = quartusIIVersion if quartusIIVersion != ""  else "15.0"

			alteraDirectoryPath = Path(alteraDirectory)
			quartusIIDirectoryPath = alteraDirectoryPath / quartusIIVersion / "quartus"

			if not alteraDirectoryPath.exists() :    raise ConfigurationException(
				"Altera installation directory '%s' does not exist." % alteraDirectory)
			if not quartusIIDirectoryPath.exists() :  raise ConfigurationException(
				"Altera QuartusII version '%s' is not installed." % quartusIIVersion)

			self.pocConfig['Altera']['InstallationDirectory'] = alteraDirectoryPath.as_posix()
			self.pocConfig['Altera.QuartusII']['Version'] = quartusIIVersion
			self.pocConfig['Altera.QuartusII']['InstallationDirectory'] = '${Altera:InstallationDirectory}/${Version}'
			self.pocConfig['Altera.QuartusII']['BinaryDirectory'] = '${InstallationDirectory}/quartus/bin'

			# Ask for installed Altera ModelSimAltera
			isAlteraModelSim = input('Is ModelSim - Altera Edition installed on your system? [Y/n/p]: ')
			isAlteraModelSim = isAlteraModelSim if isAlteraModelSim != "" else "Y"
			if (isAlteraModelSim in ['p', 'P']) :
				pass
			elif (isAlteraModelSim in ['n', 'N']) :
				self.pocConfig['Altera.ModelSim'] = OrderedDict()
			elif (isAlteraModelSim in ['y', 'Y']) :
				alteraModelSimVersion = input('ModelSim - Altera Edition version number [10.1e]: ')

				alteraModelSimDirectoryPath = alteraDirectoryPath / quartusIIVersion / "modelsim_ase"

				if not alteraModelSimDirectoryPath.exists() :  raise BaseException(
					"ModelSim - Altera Edition installation directory '%s' does not exist." % str(alteraModelSimDirectoryPath))

				self.pocConfig['Altera.ModelSim']['Version'] = alteraModelSimVersion
				self.pocConfig['Altera.ModelSim'][
					'InstallationDirectory'] = '${Altera:InstallationDirectory}/${Altera.QuartusII:Version}/modelsim_ase'
				self.pocConfig['Altera.ModelSim']['BinaryDirectory'] = '${InstallationDirectory}/bin'
			else :
				raise ConfigurationException("unknown option")
		else :
			raise ConfigurationException("unknown option")


class QuartusIIMixIn:
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		self._platform =						platform
		self._binaryDirectoryPath =	binaryDirectoryPath
		self._version =							version
		self._logger =							logger


class QuartusII(QuartusIIMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		QuartusIIMixIn.__init__(self, platform, binaryDirectoryPath, version, logger)

	def GetMap(self):
		return Map(self._platform, self._binaryDirectoryPath, self._version, logger=self._logger)


class Map(Executable, QuartusIIMixIn):
	def __init__(self, platform, binaryDirectoryPath, version, logger=None):
		QuartusIIMixIn.__init__(self, platform, binaryDirectoryPath, version, logger)

		if (platform == "Windows") :			executablePath = binaryDirectoryPath / "xst.exe"
		elif (platform == "Linux") :			executablePath = binaryDirectoryPath / "xst"
		else :														raise PlatformNotSupportedException(platform)
		Executable.__init__(self, platform, executablePath, logger=logger)

		self.Parameters[self.Executable] = executablePath

		self._hasOutput =		False
		self._hasWarnings =	False
		self._hasErrors =		False

	@property
	def HasWarnings(self):	return self._hasWarnings
	@property
	def HasErrors(self):		return self._hasErrors

	class Executable(metaclass=ExecutableArgument) :
		pass

	class SwitchIntStyle(metaclass=ShortTupleArgument):
		_name = "intstyle"

	class SwitchXstFile(metaclass=ShortFlagArgument) :
		_name = "ifn"

	class SwitchReportFile(metaclass=ShortTupleArgument) :
		_name = "ofn"

	Parameters = CommandLineArgumentList(
			Executable,
			SwitchIntStyle,
			SwitchXstFile,
			SwitchReportFile
	)

	def Compile(self) :
		parameterList = self.Parameters.ToArgumentList()
		self._LogVerbose("    command: {0}".format(" ".join(parameterList)))

		try:
			self.StartProcess(parameterList)
		except Exception as ex:
			raise ISEException("Failed to launch xst.") from ex

		self._hasOutput = False
		self._hasWarnings = False
		self._hasErrors = False
		try:
			iterator = iter(XstFilter(self.GetReader()))

			line = next(iterator)
			self._hasOutput = True
			self._LogNormal("    xst messages for '{0}'".format(self.Parameters[self.ArgSourceFile]))
			self._LogNormal("    " + ("-" * 76))

			while True:
				self._hasWarnings |= (line.Severity is Severity.Warning)
				self._hasErrors |= (line.Severity is Severity.Error)

				line.Indent(2)
				self._Log(line)
				line = next(iterator)

		except StopIteration as ex:
			pass
		except ISEException:
			raise
		# except Exception as ex:
		#	raise GHDLException("Error while executing GHDL.") from ex
		finally:
			if self._hasOutput:
				self._LogNormal("    " + ("-" * 76))

class QuartusProject(BaseProject):
	def __init__(self, name):
		super().__init__(name)


class QuartusProjectFile(ProjectFile):
	def __init__(self, file):
		super().__init__(file)

