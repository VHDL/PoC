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
	print("                  PoC Library - Python Class PoCXCOCompiler             ")
	print("========================================================================")
	print()
	print("This is no executable file!")
	exit(1)

import PoCCompiler

class PoCXCOCompiler(PoCCompiler.PoCCompiler):

	executables = {}

	def __init__(self, host, showLogs, showReport):
		super(self.__class__, self).__init__(host, showLogs, showReport)

		self.__executables = {
			'CoreGen' :	("coregen.exe"	if (host.platform == "Windows") else "coregen")
		}
		
	def run(self, pocEntity, deviceString):
		#from pathlib import Path
		import os
		#import re
		import shutil
		import subprocess
		import textwrap
	
		self.printNonQuiet(str(pocEntity))
		self.printNonQuiet("  preparing compiler environment...")

		# TODO: improve / resolve board to device
		deviceSection = "Device." + deviceString
		
		# create temporary directory for CoreGen if not existent
		tempCoreGenPath = self.host.Directories["coreGenTemp"]
		if not (tempCoreGenPath).exists():
			self.printVerbose("Creating temporary directory for core generator files.")
			self.printDebug("Temporary directors: %s" % str(tempCoreGenPath))
			tempCoreGenPath.mkdir(parents=True)

		# create output directory for CoreGen if not existent
		coreGenOutputPath = self.host.Directories["PoCNetList"] / deviceString
		if not (coreGenOutputPath).exists():
			self.printVerbose("Creating temporary directory for core generator files.")
			self.printDebug("Temporary directors: %s" % str(coreGenOutputPath))
			coreGenOutputPath.mkdir(parents=True)
			
		# add the key Device to section SPECIAL at runtime to change interpolation results
		self.host.netListConfig['SPECIAL'] = {}
		self.host.netListConfig['SPECIAL']['Device'] = deviceString
			
		# setup all needed paths to execute coreGen
		coreGenExecutablePath =		self.host.Directories["ISEBinary"] / self.__executables['CoreGen']
		
		# read netlist settings from configuration file
		ipCoreName =					self.host.netListConfig[str(pocEntity)]['IPCoreName']
		xcoInputFilePath =		self.host.Directories["PoCRoot"] / self.host.netListConfig[str(pocEntity)]['CoreGeneratorFile']
		ngcOutputFilePath =		self.host.Directories["PoCRoot"] / self.host.netListConfig[str(pocEntity)]['NetListOutputFile']
		vhdlOutputFilePath =	self.host.Directories["PoCRoot"] / self.host.netListConfig[str(pocEntity)]['VHDLEntityOutputFile']
		cgcTemplateFilePath =	self.host.Directories["PoCNetList"] / "template.cgc"
		cgpFilePath =					tempCoreGenPath / "coregen.cgp"
		cgcFilePath =					tempCoreGenPath / "coregen.cgc"
		xcoFilePath =					tempCoreGenPath / xcoInputFilePath.name
		ngcFilePath =					tempCoreGenPath / (xcoInputFilePath.stem + ".ngc")
		vhdlFilePath =				tempCoreGenPath / (xcoInputFilePath.stem + ".vhd")


		# report the next steps in execution
		if (self.getVerbose()):
			print("  Commands to be run:")
			print("  1. Write CoreGen project file into temporary directory.")
			print("  2. Write CoreGen content file into temporary directory.")
			print("  3. Copy IPCore's *.xco file into temporary directory.")
			print("  4. Change working directory to temporary directory.")
			print("  5. Run Xilinx Core Generator (coregen).")
			print("  6. Copy resulting files into output directory.")
			print("  ----------------------------------------")
		
		
		# write CoreGenerator project file
		cgProjectFileContent = textwrap.dedent('''\
			SET addpads = false
			SET asysymbol = false
			SET busformat = BusFormatAngleBracketNotRipped
			SET createndf = false
			SET designentry = VHDL
			SET device = %s
			SET devicefamily = %s
			SET flowvendor = Other
			SET formalverification = false
			SET foundationsym = false
			SET implementationfiletype = Ngc
			SET package = %s
			SET removerpms = false
			SET simulationfiles = Behavioral
			SET speedgrade = %s
			SET verilogsim = false
			SET vhdlsim = true
			SET workingdirectory = %s
			''' % (
				self.host.netListConfig[deviceSection]['Device'],
				self.host.netListConfig[deviceSection]['DeviceFamily'],
				self.host.netListConfig[deviceSection]['Package'],
				self.host.netListConfig[deviceSection]['SpeedGrade'],
				(".\\temp\\" if self.host.platform == "Windows" else "./temp/")
			))

		self.printDebug("Writing CoreGen project file to '%s'" % str(cgpFilePath))
		with cgpFilePath.open('w') as cgpFileHandle:
			cgpFileHandle.write(cgProjectFileContent)

		# write CoreGenerator content? file
		self.printDebug("Reading CoreGen content file to '%s'" % str(cgcTemplateFilePath))
		with cgcTemplateFilePath.open('r') as cgcFileHandle:
			cgContentFileContent = cgcFileHandle.read()
			
		cgContentFileContent = cgContentFileContent.format(**{
			'name' : "lcd_ChipScopeVIO",
			'device' : self.host.netListConfig[deviceSection]['Device'],
			'devicefamily' : self.host.netListConfig[deviceSection]['DeviceFamily'],
			'package' : self.host.netListConfig[deviceSection]['Package'],
			'speedgrade' : self.host.netListConfig[deviceSection]['SpeedGrade']
		})

		self.printDebug("Writing CoreGen content file to '%s'" % str(cgcFilePath))
		with cgcFilePath.open('w') as cgcFileHandle:
			cgcFileHandle.write(cgContentFileContent)
		
		# copy xco file into temporary directory
		self.printDebug("Copy CoreGen xco file to '%s'" % str(xcoFilePath))
		self.printVerbose('    cp "%s" "%s"' % (str(xcoInputFilePath), str(tempCoreGenPath)))
		shutil.copy(str(xcoInputFilePath), str(xcoFilePath), follow_symlinks=True)
		
		# change working directory to temporary CoreGen path
		self.printVerbose('    cd "%s"' % str(tempCoreGenPath))
		os.chdir(str(tempCoreGenPath))
		
		# running CoreGen
		# ==========================================================================
		self.printNonQuiet("  running CoreGen...")
		# assemble CoreGen command as list of parameters
		parameterList = [
			str(coreGenExecutablePath),
			'-r',
			'-b', str(xcoFilePath),
			'-p', '.'
		]
		self.printDebug("call coreGen: %s" % str(parameterList))
		self.printVerbose('    %s -r -b "%s" -p .' % (str(coreGenExecutablePath), str(xcoFilePath)))
		if (self.dryRun == False):
			coreGenLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
			if self.showLogs:
				print("Core Generator log (CoreGen)")
				print("--------------------------------------------------------------------------------")
				print(coreGenLog)
				print()
		
		# copy resulting files into PoC's netlist directory
		if not ngcFilePath.exists():
			raise PoCCompilerException("No *.ngc file found after synthesis.")
		
		self.printVerbose('  copy result files into output directory...')
		self.printDebug("Copy ngc file to '%s'" % str(ngcOutputFilePath))
		self.printVerbose('    cp "%s" "%s"' % (str(ngcFilePath), str(ngcOutputFilePath)))
		shutil.copy(str(ngcFilePath), str(ngcOutputFilePath))
		
		if not vhdlFilePath.exists():
			raise PoCCompilerException("No *.vhd file found after synthesis.")
		
		self.printDebug("Copy vhd file to '%s'" % str(vhdlOutputFilePath))
		self.printVerbose('    cp "%s" "%s"' % (str(vhdlFilePath), str(vhdlOutputFilePath)))
		shutil.copy(str(vhdlFilePath), str(vhdlOutputFilePath))
		