# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:         		 Patrick Lehmann
# 
# Python Main Module:  Entry point to the post-processing tools.
# 
# Description:
# ------------------------------------
#    This is a python main module (executable) which:
#    - ...
#    - ...
#
# License:
# ==============================================================================
# Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

from pathlib import Path

from lib.Functions import Exit
from Base.Exceptions import *
from Base.PoCBase import CommandLineProgram
from PoC.Entity import *
from PoC.Config import *
from Processor import *
from Processor.Exceptions import *
from Processor.XST import *

class PostProcessor(CommandLineProgram):
	headLine = "The PoC Library - PostProcessor Frontend"

	#__netListConfigFileName = "configuration.ini"
	dryRun = False
	#netListConfig = None
	
	processors = []
	
	def __init__(self, debug, verbose, quiet):
		from configparser import ConfigParser, ExtendedInterpolation
		
		super(self.__class__, self).__init__(debug, verbose, quiet)

		if not ((self.platform == "Windows") or (self.platform == "Linux")):
			raise PlatformNotSupportedException(self.platform)
		
		# hard coded
		projectName = "StreamDBTest_ML505"
	
		projectConfigurationFilePath =	self.Directories["SolutionRoot"] / self.config[projectName]['ConfigurationFile']
		xstReportFilePath =							self.Directories["SolutionRoot"] / self.config[projectName]['XSTReportFile']
		
		self.Files["ProjectConfiguration"]	= projectConfigurationFilePath
		self.Files["XSTReport"]	=							xstReportFilePath
		
		print("project ini: " + str(projectConfigurationFilePath))
		
		if not projectConfigurationFilePath.exists():
			raise NotConfiguredException("Project configuration file does not exist. (%s)" % str(projectConfigurationFilePath))
		if not xstReportFilePath.exists():							raise Exception("Compiler report file does not exist. (%s)" % str(xstReportFilePath))

		self.printDebug("Reading project configuration from '%s'" % str(projectConfigurationFilePath))		
		self.projectConfig = ConfigParser(interpolation=ExtendedInterpolation())
		self.projectConfig.optionxform = str
		self.projectConfig.read([str(self.Files["Configuration"]), str(projectConfigurationFilePath)])
	
		self.projectConfig['PROJECT']['Name'] = self.config[projectName]['ProjectName']
		
		self.Directories['ChipScope'] =	self.Directories['SolutionRoot'] / self.projectConfig['Directories']['ChipScopeDirectory']
		self.Directories['TokenFile'] =	self.Directories['SolutionRoot'] / self.projectConfig['Directories']['TokenFileDirectory']
			
	def run(self, showLogs, showReport):
		
		self.compileRegExp()
		print("-- process -------------------------")
		results = self.process()
		print("-- analyze -------------------------")
		self.analyze(results)
		
	def process(self):
		activeProcessors = []
		processorResults = {}
		for processor in self.processors:
			processorResults[processor['Name']] = []
		
		with self.Files["XSTReport"].open('r') as xstReportFileHandle:
			for line in xstReportFileHandle:
				#print("Line: " + line[:-1])
				for processor in self.processors:
					regExpMatch = processor['RegExp'].match(line)
					if (regExpMatch is not None):
						activeProcessor = ActiveProcessor(processor['Name'], processor['Extractor'].createGenerator())
						activeProcessor.send(None)
						activeProcessors.append(activeProcessor)
					
				for ap in activeProcessors:
					try:
						ap.send(line)
					except StopIteration as ex:
						processorResults[str(ap)].append(ex.value)
						activeProcessors.remove(ap)
			
			# cleaning up after looping all lines
			for ap in activeProcessors:
				ap.close()
		
		return processorResults
		
	def analyze(self, processorResults):
		for (key, value) in processorResults.items():
			if (key == "WarningExtractor"):
				print("Warnings (%i):" % len(value))
				self.analyzeWarnings(value)
#				for i in value:
#					print(i)
			elif (key == "ErrorExtractor"):
				print("Errors (%i):" % len(value))
#				for i in value:
#					print(i)
			elif (key == "FSMTokenFileExtractor"):
				self.analyzeFSMEncodings(value)

	def analyzeWarnings(self, warnings):
		import re
		
		regExpString = r"(?P<Process>\w+)\((?P<WarningID>\d+)\)"
		regExp = re.compile(regExpString)
	
		criticalWarningsFilterList = []
	
		keys = self.projectConfig.options('CriticalWarnings')
		for key in keys:
			regExpMatch = regExp.match(key)
			if (regExpMatch is not None):
				criticalWarningsFilterList.append({
					'Process' :		regExpMatch.group('Process'),
					'WarningID' :	int(regExpMatch.group('WarningID')),
					'Pattern' :		self.projectConfig['CriticalWarnings'][key]
				})
			else:
				print("ERROR: '%s'" % key)
	
	
		for warning in warnings:
			for filter in criticalWarningsFilterList:
				if ((warning['Process'] == filter['Process']) and
						(warning['WarningID'] == filter['WarningID']) and
						(re.compile(filter['Pattern']).match(warning['Message']) is not None)):
					#print("%s(%i): %s" % (warning['Process'], warning['WarningID'], warning['Message']))
					print(warning['Message'])
					
			
				
	def analyzeFSMEncodings(self, stateMachines):
		import re
		
		print("FSMs found: (%i)" % len(stateMachines))
		
		for fsm in stateMachines:
			key = "%s/%s" % (fsm['Path'], fsm['Signal'])
			self.printVerbose("  States: %2i    Path: %s" % (len(fsm['Encodings']), key))
			
			if (not self.projectConfig.has_option('FSM-Paths', key)):
				continue
			
			# resolve section
			section = self.projectConfig['FSM-Paths'][key]
			
			tokenFile = self.projectConfig[section]['TokenFileName']
			tokenFilePath = self.Directories['SolutionRoot'] / tokenFile
			
			replacementRules =	self.projectConfig[section]['Replacements']
			ruleList = replacementRules.split("\n")
			
			# prepare output string
			tokenFileContent = ""
			
			for enc in fsm['Encodings']:
				if (enc['StateEncoding'] is not None):
					tokenFileContent += "%s=%X\n" % (enc['StateName'], enc['StateEncoding'])
				else:
					tokenFileContent += "#%s=unreached\n" % enc['StateName']
		
			for rule in ruleList:
				[pattern, replacement] = rule.split(" -> ")
				#print("search: %s    replace with: %s" % (pattern[1:-1], replacement[1:-1]))
				tokenFileContent = re.sub(pattern[1:-1], replacement[1:-1], tokenFileContent)
				
			# Writing token file
			self.printVerbose("    Writing token file to '%s'" % str(tokenFilePath))
			with tokenFilePath.open('w') as tokenFileHandle:
				tokenFileHandle.write(tokenFileContent)
		
	def compileRegExp(self):
		import re
		
		for processor in self.processors:
			processor['RegExp'] = re.compile(processor['RegExpString'])
					
	def enableFSMTokenFileExtraction(self):
		ext = XSTFSMTokenFileExtractor.Extractor
		self.processors.append({
			'Name' :					ext.__name__,
			'RegExpString' :	ext.getInitializationRegExpString(),
			'RegExp' :				None,
			'Extractor' :			ext
		})
	
	def enableErrorExtraction(self):
		ext = XSTErrorExtractor.Extractor
		self.processors.append({
			'Name' :					ext.__name__,
			'RegExpString' :	ext.getInitializationRegExpString(),
			'RegExp' :				None,
			'Extractor' :			ext
		})
	
	def enableWarningExtraction(self):
		ext = XSTWarningExtractor.Extractor
		self.processors.append({
			'Name' :					ext.__name__,
			'RegExpString' :	ext.getInitializationRegExpString(),
			'RegExp' :				None,
			'Extractor' :			ext
		})

class ActiveProcessor(object):
	Name =			""
	Processor =	None
	
	def __init__(self, Name, Processor):
		self.Name = Name
		self.Processor = Processor
		
	def __str__(self):
		return self.Name
		
	def send(self, obj):
		return self.Processor.send(obj)
	
	def close(self):
		return self.Processor.close()
	
# main program
def main():
	print("=" * 80)
	print("{: ^80s}".format("The PoC Library - PostProcessor Frontend"))
	print("=" * 80)
	print()
	
	try:
		import argparse
		import textwrap
		
		# create a command line argument parser
		argParser = argparse.ArgumentParser(
			formatter_class = argparse.RawDescriptionHelpFormatter,
			description = textwrap.dedent('''\
				This is the PoC Library NetList Service Tool.
				'''),
			add_help=False)

		# add arguments
		group1 = argParser.add_argument_group('Verbosity')
		group1.add_argument('-D', 																											help='enable script wrapper debug mode',	action='store_const', const=True, default=False)
		group1.add_argument('-d',																		dest="debug",				help='enable debug mode',									action='store_const', const=True, default=False)
		group1.add_argument('-v',																		dest="verbose",			help='print out detailed messages',				action='store_const', const=True, default=False)
		group1.add_argument('-q',																		dest="quiet",				help='run in quiet mode',									action='store_const', const=True, default=False)
		group1.add_argument('-r',																		dest="showReport",	help='show report',												action='store_const', const=True, default=False)
		group1.add_argument('-l',																		dest="showLog",			help='show logs',													action='store_const', const=True, default=False)
		group2 = argParser.add_argument_group('Commands')
		group21 = group2.add_mutually_exclusive_group(required=True)
		group21.add_argument('-h', '--help',												dest="help",				help='show this help message and exit',		action='store_const', const=True, default=False)
		group211 = group21.add_mutually_exclusive_group()
		group211.add_argument(		 '--tokenfiles', metavar="<FSM>", dest="tokenFiles",	help='extraxt FSM encodings for ChipScope token files (*.tok)')

		# parse command line options
		args = argParser.parse_args()
		
	except Exception as ex:
		Exit.printException(ex)
		
	try:
		PP = PostProcessor(args.debug, args.verbose, args.quiet)
		#netList.dryRun = True
	
		if (args.help == True):
			argParser.print_help()
			return
		elif (args.tokenFiles is not None):
			PP.enableFSMTokenFileExtraction()
			PP.enableWarningExtraction()
			PP.enableErrorExtraction()
			PP.run(args.showLog, args.showReport)
			#PP.extractTokenFiles(args.tokenFiles, args.showLog, args.showReport)
		else:
			argParser.print_help()
		
	except ProcessorException as ex:
		from colorama import Fore, Back, Style
		print(Fore.RED + "ERROR:" + Fore.RESET + " %s" % ex.message)
		if isinstance(ex.__cause__, FileNotFoundError):
			print(Fore.YELLOW + "  FileNotFound:" + Fore.RESET + " '%s'" % str(ex.__cause__))
		print()
		print(Fore.RESET + Back.RESET + Style.RESET_ALL)
		exit(1)

	except EnvironmentException as ex:					Exit.printEnvironmentException(ex)
	except NotConfiguredException as ex:				Exit.printNotConfiguredException(ex)
	except PlatformNotSupportedException as ex:	Exit.printPlatformNotSupportedException(ex)
	except BaseException as ex:									Exit.printBaseException(ex)
	except NotImplementedException as ex:				Exit.printNotImplementedException(ex)
	except Exception as ex:											Exit.printException(ex)
			
# entry point
if __name__ == "__main__":
	Exit.versionCheck((3,4,0))
	main()
else:
	Exit.printThisIsNoLibraryFile(PostProcessor.headLine)
