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
		
	def run(self, pocEntity, device):
		#from pathlib import Path
		import os
		#import re
		import shutil
		import subprocess
		import textwrap
	
		self.printNonQuiet(str(pocEntity))
		self.printNonQuiet("  preparing compiler environment...")

		# TODO: improve / resolve board to device
		deviceString = self.host.netListConfig['BOARDS'][device]
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


		# TODO: verbose print run instructions
		
		
		
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
		cgContentFileContent = textwrap.dedent('''\
			<?xml version="1.0" encoding="UTF-8"?>
			<spirit:design xmlns:spirit="http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xilinx="http://www.xilinx.com" >
				 <spirit:vendor>xilinx.com</spirit:vendor>
				 <spirit:library>project</spirit:library>
				 <spirit:name>coregen</spirit:name>
				 <spirit:version>1.0</spirit:version>
				 <spirit:componentInstances>
						<spirit:componentInstance>
							 <spirit:instanceName>{name}</spirit:instanceName>
							 <spirit:displayName>VIO (ChipScope Pro - Virtual Input/Output)</spirit:displayName>
							 <spirit:componentRef spirit:vendor="xilinx.com" spirit:library="ip" spirit:name="chipscope_vio" spirit:version="1.05.a" />
							 <spirit:configurableElementValues>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.COMPONENT_NAME">{name}</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.SYNCHRONOUS_INPUT_PORT_WIDTH">256</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.EXAMPLE_DESIGN">false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.CONSTRAINT_TYPE">external</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ENABLE_SYNCHRONOUS_INPUT_PORT">true</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ENABLE_SYNCHRONOUS_OUTPUT_PORT">true</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ASYNCHRONOUS_OUTPUT_PORT_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ENABLE_ASYNCHRONOUS_OUTPUT_PORT">false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ENABLE_ASYNCHRONOUS_INPUT_PORT">false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.INVERT_CLOCK_INPUT">false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.SYNCHRONOUS_OUTPUT_PORT_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.ASYNCHRONOUS_INPUT_PORT_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_ASYNC_IN_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_SYNC_IN">1</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_ASYNC_OUT_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_CONSTRAINT_TYPE">external</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_SYNC_OUT_WIDTH">8</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_EXAMPLE_DESIGN">false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_INV_CLK">0</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_SYNC_IN_WIDTH">256</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_ASYNC_IN">0</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_SYNC_OUT">1</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.COMPONENT_NAME">{name}</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_XCO_LIST">Component_Name={name};Enable_Synchronous_Input_Port=true;Enable_Synchronous_Output_Port=true;Enable_Asynchronous_Input_Port=false;Enable_Asynchronous_Output_Port=false;Synchronous_Input_Port_Width=256;Synchronous_Output_Port_Width=8;Asynchronous_Input_Port_Width=8;Asynchronous_Output_Port_Width=8;Invert_Clock_Input=false</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_SYNC_CLK">1</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_USE_ASYNC_OUT">0</spirit:configurableElementValue>
									<spirit:configurableElementValue spirit:referenceId="MODELPARAM_VALUE.C_SRL16_TYPE">2</spirit:configurableElementValue>
							 </spirit:configurableElementValues>
							 <spirit:vendorExtensions>
									<xilinx:instanceProperties>
										 <xilinx:projectOptions>
												<xilinx:projectName>coregen</xilinx:projectName>
												<xilinx:outputDirectory>./</xilinx:outputDirectory>
												<xilinx:workingDirectory>./temp/</xilinx:workingDirectory>
												<xilinx:subWorkingDirectory>./temp/_cg/</xilinx:subWorkingDirectory>
										 </xilinx:projectOptions>
										 <xilinx:part>
												<xilinx:device>{device}</xilinx:device>
												<xilinx:deviceFamily>{devicefamily}</xilinx:deviceFamily>
												<xilinx:package>{package}</xilinx:package>
												<xilinx:speedGrade>{speedgrade}</xilinx:speedGrade>
										 </xilinx:part>
										 <xilinx:flowOptions>
												<xilinx:busFormat>BusFormatAngleBracketNotRipped</xilinx:busFormat>
												<xilinx:designEntry>VHDL</xilinx:designEntry>
												<xilinx:asySymbol>false</xilinx:asySymbol>
												<xilinx:flowVendor>Other</xilinx:flowVendor>
												<xilinx:addPads>false</xilinx:addPads>
												<xilinx:removeRPMs>false</xilinx:removeRPMs>
												<xilinx:createNDF>false</xilinx:createNDF>
												<xilinx:implementationFileType>Ngc</xilinx:implementationFileType>
												<xilinx:formalVerification>false</xilinx:formalVerification>
										 </xilinx:flowOptions>
										 <xilinx:simulationOptions>
												<xilinx:simulationModel>Behavioral</xilinx:simulationModel>
												<xilinx:simulationLanguage>VHDL</xilinx:simulationLanguage>
												<xilinx:foundationSym>false</xilinx:foundationSym>
										 </xilinx:simulationOptions>
										 <xilinx:packageInfo>
												<xilinx:sourceCoreCreationDate>2013-10-13+14:13</xilinx:sourceCoreCreationDate>
										 </xilinx:packageInfo>
									</xilinx:instanceProperties>
									<xilinx:generationHistory>
										 <xilinx:fileSet>
												<xilinx:name>apply_current_project_options_generator</xilinx:name>
										 </xilinx:fileSet>
										 <xilinx:fileSet>
												<xilinx:name>model_parameter_resolution_generator</xilinx:name>
										 </xilinx:fileSet>
										 <xilinx:fileSet>
												<xilinx:name>ip_xco_generator</xilinx:name>
												<xilinx:file>
													 <xilinx:name>./{name}.xco</xilinx:name>
													 <xilinx:userFileType>xco</xilinx:userFileType>
													 <xilinx:timeStamp>Wed Jun 11 10:06:45 GMT 2014</xilinx:timeStamp>
													 <xilinx:checkSum>0x709EE3F7</xilinx:checkSum>
													 <xilinx:generationId>generationID_1879581046</xilinx:generationId>
												</xilinx:file>
										 </xilinx:fileSet>
									</xilinx:generationHistory>
							 </spirit:vendorExtensions>
						</spirit:componentInstance>
				 </spirit:componentInstances>
				 <spirit:vendorExtensions>
						<xilinx:instanceProperties>
							 <xilinx:projectOptions>
									<xilinx:projectName>coregen</xilinx:projectName>
									<xilinx:outputDirectory>./</xilinx:outputDirectory>
									<xilinx:workingDirectory>./temp/</xilinx:workingDirectory>
									<xilinx:subWorkingDirectory>./temp/_cg/</xilinx:subWorkingDirectory>
							 </xilinx:projectOptions>
							 <xilinx:part>
									<xilinx:device>{device}</xilinx:device>
									<xilinx:deviceFamily>{devicefamily}</xilinx:deviceFamily>
									<xilinx:package>{package}</xilinx:package>
									<xilinx:speedGrade>{speedgrade}</xilinx:speedGrade>
							 </xilinx:part>
							 <xilinx:flowOptions>
									<xilinx:busFormat>BusFormatAngleBracketNotRipped</xilinx:busFormat>
									<xilinx:designEntry>VHDL</xilinx:designEntry>
									<xilinx:asySymbol>false</xilinx:asySymbol>
									<xilinx:flowVendor>Other</xilinx:flowVendor>
									<xilinx:addPads>false</xilinx:addPads>
									<xilinx:removeRPMs>false</xilinx:removeRPMs>
									<xilinx:createNDF>false</xilinx:createNDF>
									<xilinx:implementationFileType>Ngc</xilinx:implementationFileType>
									<xilinx:formalVerification>false</xilinx:formalVerification>
							 </xilinx:flowOptions>
							 <xilinx:simulationOptions>
									<xilinx:simulationModel>Behavioral</xilinx:simulationModel>
									<xilinx:simulationLanguage>VHDL</xilinx:simulationLanguage>
									<xilinx:foundationSym>false</xilinx:foundationSym>
							 </xilinx:simulationOptions>
						</xilinx:instanceProperties>
				 </spirit:vendorExtensions>
			</spirit:design>
			''').format(**{
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
		self.printVerbose('  cp "%s" "%s"' % (str(xcoInputFilePath), str(tempCoreGenPath)))
		shutil.copy(str(xcoInputFilePath), str(xcoFilePath), follow_symlinks=True)
		
		# change working directory to temporary CoreGen path
		self.printVerbose('  cd "%s"' % str(tempCoreGenPath))
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
		self.printVerbose('%s -r -b "%s" -p .' % (str(coreGenExecutablePath), str(xcoFilePath)))
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
		
		self.printDebug("Copy ngc file to '%s'" % str(ngcOutputFilePath))
		self.printVerbose('  cp "%s" "%s"' % (str(ngcFilePath), str(ngcOutputFilePath)))
		shutil.copy(str(ngcFilePath), str(ngcOutputFilePath))
		
		if not vhdlFilePath.exists():
			raise PoCCompilerException("No *.vhd file found after synthesis.")
		
		self.printDebug("Copy vhd file to '%s'" % str(vhdlOutputFilePath))
		self.printVerbose('  cp "%s" "%s"' % (str(vhdlFilePath), str(vhdlOutputFilePath)))
		shutil.copy(str(vhdlFilePath), str(vhdlOutputFilePath))
		
		print("ngc: " + str(ngcOutputFilePath))
		print("dev: " + device)
		print("return ...")
		return
		
#  c:\Xilinx\14.7\ISE_DS\ISE\bin\nt64\coregen.exe -r -b lcd_ChipScopeVIO.xco -p .
		
		# report the next steps in execution
		if (self.getVerbose()):
			print("  Commands to be run:")
			print("  1. Change working directory to temporary directory.")
			print("  2. Parse filelist and write CoreGen project file.")
			print("  3. Compile and Link source files to an executable simulation file.")
			print("  4. Simulate in tcl batch mode.")
			print("  ----------------------------------------")
		
		# change working directory to temporary CoreGen path
		self.printVerbose('  cd "%s"' % str(tempCoreGenPath))
		os.chdir(str(tempCoreGenPath))

		# parse project filelist
		regExpStr =	 r"\s*(?P<Keyword>(vhdl|xilinx))"				# Keywords: vhdl, xilinx
		regExpStr += r"\s+(?P<VHDLLibrary>[_a-zA-Z0-9]+)"		#	VHDL library name
		regExpStr += r"\s+\"(?P<VHDLFile>.*?)\""						# VHDL filename without "-signs
		regExp = re.compile(regExpStr)

		self.printDebug("Reading filelist '%s'" % str(fileFilePath))
		CoreGenProjectFileContent = ""
		with fileFilePath.open('r') as prjFileHandle:
			for line in prjFileHandle:
				regExpMatch = regExp.match(line)
				
				if (regExpMatch is not None):
					if (regExpMatch.group('Keyword') == "vhdl"):
						vhdlFilePath = self.host.Directories["PoCRoot"] / regExpMatch.group('VHDLFile')
					elif (regExpMatch.group('Keyword') == "xilinx"):
						vhdlFilePath = self.host.Directories["ISEInstallation"] / "ISE/vhdl/src" / regExpMatch.group('VHDLFile')
					vhdlLibraryName = regExpMatch.group('VHDLLibrary')
					CoreGenProjectFileContent += "vhdl %s \"%s\"\n" % (vhdlLibraryName, str(vhdlFilePath))
		
		# write CoreGen project file
		self.printDebug("Writing CoreGen project file to '%s'" % str(prjFilePath))
		with prjFilePath.open('w') as configFileHandle:
			configFileHandle.write(CoreGenProjectFileContent)


		# running coreGen
		# ==========================================================================
		self.printNonQuiet("  running coreGen...")
		# assemble coreGen command as list of parameters
		parameterList = [
			str(coreGenExecutablePath),
			('work.%s' % testbenchName),
			'--incremental',
			'-prj',	str(prjFilePath),
			'-o',		str(exeFilePath)
		]
		self.printDebug("call coreGen: %s" % str(parameterList))
		self.printVerbose('%s work.%s --incremental -prj "%s" -o "%s"' % (str(coreGenExecutablePath), testbenchName, str(prjFilePath), str(exeFilePath)))
		linkerLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
		if self.showLogs:
			print("coreGen log (coreGen)")
			print("--------------------------------------------------------------------------------")
			print(linkerLog)
			print()
		
		# running simulation
		self.printNonQuiet("  running simulation...")
		parameterList = [str(exeFilePath), '-tclbatch', str(tclFilePath)]
		self.printDebug("call simulation: %s" % str(parameterList))
		self.printVerbose('%s -tclbatch "%s"' % (str(exeFilePath), str(tclFilePath)))
		simulatorLog = subprocess.check_output(parameterList, stderr=subprocess.STDOUT, universal_newlines=True)
		
		if self.showLogs:
			print("simulator log")
			print("--------------------------------------------------------------------------------")
			print(simulatorLog)
			print("--------------------------------------------------------------------------------")		
	
		print()
		try:
			result = self.checkSimulatorOutput(simulatorLog)
			
			if (result == True):
				print("Testbench '%s': PASSED" % testbenchName)
			else:
				print("Testbench '%s': FAILED" % testbenchName)
				
		except PoCSimulatorException as ex:
			raise PoCTestbenchException("PoC.ns.module", testbenchName, "'SIMULATION RESULT = [PASSED|FAILED]' not found in simulator output.") from ex
	