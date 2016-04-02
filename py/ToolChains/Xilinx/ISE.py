# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:				 	Patrick Lehmann
#
# Python Class:			Xilinx ISE specific classes
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
	Exit.printThisIsNoExecutableFile("PoC Library - Python Module ToolChains.Xilinx.ISE")


class Configuration:
	__vendor =		"Xilinx"
	__shortName = "ISE"
	__LongName =	"Xilinx ISE"
	__privateConfiguration = {
		"Windows": {
			"Xilinx": {
				"InstallationDirectory":	"C:/Xilinx"
			},
			"Xilinx.ISE": {
				"Version":								"14.7",
				"InstallationDirectory":	"${Xilinx:InstallationDirectory}/${Version}/ISE_DS",
				"BinaryDirectory":				"${InstallationDirectory}/ISE/bin/nt64"
			}
		},
		"Linux": {
			"Xilinx": {
				"InstallationDirectory":	"/opt/Xilinx"
			},
			"Xilinx.ISE": {
				"Version":								"14.7",
				"InstallationDirectory":	"${Xilinx:InstallationDirectory}/${Version}/ISE_DS",
				"BinaryDirectory":				"${InstallationDirectory}/ISE/bin/lin64"
			}
		}
	}

	def IsSupportedPlatform(self, Platform):
		return (Platform in self.__privateConfiguration)

	def GetSections(self, Platform):
		pass

	def manualConfigureForWindows(self):
		# Ask for installed Xilinx ISE
		isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
		isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
		if (isXilinxISE in ['p', 'P']):
			pass
		elif (isXilinxISE in ['n', 'N']):
			self.pocConfig['Xilinx.ISE'] = OrderedDict()
		elif (isXilinxISE in ['y', 'Y']):
			xilinxDirectory = input('Xilinx installation directory [C:\Xilinx]: ')
			iseVersion = input('Xilinx ISE version number [14.7]: ')
			print()

			xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "C:\Xilinx"
			iseVersion = iseVersion if iseVersion != "" else "14.7"

			xilinxDirectoryPath = Path(xilinxDirectory)
			iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"

			if not xilinxDirectoryPath.exists():  raise BaseException(
				"Xilinx installation directory '%s' does not exist." % xilinxDirectory)
			if not iseDirectoryPath.exists():      raise BaseException(
				"Xilinx ISE version '%s' is not installed." % iseVersion)

			self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
			self.pocConfig['Xilinx.ISE']['Version'] = iseVersion
			self.pocConfig['Xilinx.ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
			self.pocConfig['Xilinx.ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/nt64'
		else:
			raise BaseException("unknown option")

	def manualConfigureForLinux(self):
		# Ask for installed Xilinx ISE
		isXilinxISE = input('Is Xilinx ISE installed on your system? [Y/n/p]: ')
		isXilinxISE = isXilinxISE if isXilinxISE != "" else "Y"
		if (isXilinxISE in ['p', 'P']):
			pass
		elif (isXilinxISE in ['n', 'N']):
			self.pocConfig['Xilinx.ISE'] = OrderedDict()
		elif (isXilinxISE in ['y', 'Y']):
			xilinxDirectory = input('Xilinx installation directory [/opt/Xilinx]: ')
			iseVersion = input('Xilinx ISE version number [14.7]: ')
			print()

			xilinxDirectory = xilinxDirectory if xilinxDirectory != "" else "/opt/Xilinx"
			iseVersion = iseVersion if iseVersion != "" else "14.7"

			xilinxDirectoryPath = Path(xilinxDirectory)
			iseDirectoryPath = xilinxDirectoryPath / iseVersion / "ISE_DS/ISE"

			if not xilinxDirectoryPath.exists():  raise BaseException(
				"Xilinx installation directory '%s' does not exist." % xilinxDirectory)
			if not iseDirectoryPath.exists():      raise BaseException(
				"Xilinx ISE version '%s' is not installed." % iseVersion)

			self.pocConfig['Xilinx']['InstallationDirectory'] = xilinxDirectoryPath.as_posix()
			self.pocConfig['Xilinx.ISE']['Version'] = iseVersion
			self.pocConfig['Xilinx.ISE']['InstallationDirectory'] = '${Xilinx:InstallationDirectory}/${Version}/ISE_DS'
			self.pocConfig['Xilinx.ISE']['BinaryDirectory'] = '${InstallationDirectory}/ISE/bin/lin64'
		else:
			raise BaseException("unknown option")
