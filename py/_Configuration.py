# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:         			Patrick Lehmann
# 
# Python Main Module:		Entry point to configure the local copy of this PoC repository.
# 
# Description:
# ------------------------------------
#		This is a python main module (executable) which:
#		- configures the PoC Library to your local environment,
#		- return the paths to tool chain files (e.g. ISE settings file)
#		- ...
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

from pathlib					import Path
from configparser			import ConfigParser, ExtendedInterpolation

from lib.Functions		import Exit
from Base.Exceptions	import *
from Base.Logging			import Logger, Severity
from Base.PoCBase			import CommandLineProgram
from collections			import OrderedDict


class Configuration(CommandLineProgram):
	headLine = "The PoC-Library - Repository Service Tool"
	
	__privateSections = [
		"Aldec", "Aldec.ActiveHDL", "Aldec.RivieraPRO",
		"Altera", "Altera.QuartusII", "Altera.ModelSim",
		"Lattice", "Lattice.Diamond", "Lattice.ActiveHDL", "Lattice.Symplify",
	]
	
	def __init__(self, debug, verbose, quiet):
		if quiet:			severity = Severity.Quiet
		elif debug:		severity = Severity.Debug
		elif verbose:	severity = Severity.Verbose
		else:					severity = Severity.Normal
		
		logger =			Logger(self, severity, printToStdOut=True)
		try:
			super(self.__class__, self).__init__(logger=logger)

			if		(self.Platform == "Windows"):	pass
			elif	(self.Platform == "Linux"):		pass
			else:																						raise PlatformNotSupportedException(self.Platform)
		
		except NotConfiguredException as ex:
			self._LogVerbose("Configuration file does not exists; creating a new one")
			
			self.pocConfig = ConfigParser(interpolation=ExtendedInterpolation())
			self.pocConfig.optionxform = str
			self.pocConfig['PoC'] = OrderedDict()
			self.pocConfig['PoC']['Version'] = '0.0.0'
			self.pocConfig['PoC']['InstallationDirectory'] = self.directories['PoCRoot'].as_posix()

			self.pocConfig['Aldec'] =									OrderedDict()
			self.pocConfig['Aldec.ActiveHDL'] =				OrderedDict()
			self.pocConfig['Aldec.RivieraPRO'] =			OrderedDict()
			self.pocConfig['Altera'] =								OrderedDict()
			self.pocConfig['Altera.QuartusII'] =			OrderedDict()
			self.pocConfig['Altera.ModelSim'] =				OrderedDict()
			self.pocConfig['Lattice'] =								OrderedDict()
			self.pocConfig['Lattice.Diamond'] =				OrderedDict()
			self.pocConfig['Lattice.ActiveHDL'] =			OrderedDict()
			self.pocConfig['Lattice.Symplify'] =			OrderedDict()
			self.pocConfig['GHDL'] =									OrderedDict()
			self.pocConfig['GTKWave'] =								OrderedDict()
			self.pocConfig['Mentor'] =								OrderedDict()
			self.pocConfig['Mentor.QuestaSIM'] =			OrderedDict()
			self.pocConfig['Xilinx'] =								OrderedDict()
			self.pocConfig['Xilinx.ISE'] =						OrderedDict()
			self.pocConfig['Xilinx.LabTools'] =				OrderedDict()
			self.pocConfig['Xilinx.Vivado'] =					OrderedDict()
			self.pocConfig['Xilinx.HardwareServer'] =	OrderedDict()
			self.pocConfig['Solutions'] =							OrderedDict()

			# Writing configuration to disc
			with self.files['PoCPrivateConfig'].open('w') as configFileHandle:
				self.pocConfig.write(configFileHandle)
			
			self._LogDebug("New configuration file created: %s" % self.files['PoCPrivateConfig'])
			
			# re-read configuration
			self.__ReadPoCConfiguration()
	
	def newSolution(self, solutionName):
		print("new solution: name=%s" % solutionName)
		print("solution here: %s" % self.directories['Working'])
		print("script root: %s" % self.directories['ScriptRoot'])
	
		raise NotImplementedException("Currently new solution should be created by hand.")
	
	def addSolution(self, solutionName):
		print("Adding existing solution '%s' to PoC Library." % solutionName)
		print()
		print("You can specify paths and file names relative to the current working directory")
		print("or as an absolute path.")
		print()
		print("Current working directory: %s" % self.directories['Working'])
		print()
		
		if (not self.pocConfig.has_section('Solutions')):
			self.pocConfig['Solutions'] = OrderedDict()
		
		if self.pocConfig.has_option('Solutions', solutionName):
			raise ExceptionBase("Solution is already registered in PoC Library.")
		
		# 
		solutionFileDirectoryName = input("Where is the solution file 'solution.ini' stored? [./py]: ")
		solutionFileDirectoryName = solutionFileDirectoryName if solutionFileDirectoryName != "" else "py"
	
		solutionFilePath = Path(solutionFileDirectoryName)
	
		if (solutionFilePath.is_absolute()):
			solutionFilePath = solutionFilePath / "solution.ini"
		else:
			solutionFilePath = ((self.directories['Working'] / solutionFilePath).resolve()) / "solution.ini"
			
		if (not solutionFilePath.exists()):
			raise ExceptionBase("Solution file '%s' does not exist." % str(solutionFilePath))
		
		self.pocConfig['Solutions'][solutionName] = solutionFilePath.as_posix()
	
		# write configuration
		self.writePoCConfiguration()
		# re-read configuration
		self.readPoCConfiguration()
	
