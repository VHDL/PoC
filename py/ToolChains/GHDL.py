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


class Configuration:
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
