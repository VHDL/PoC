# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:               Patrick Lehmann
# 
# Python Main Module:    Entry point to the post-processing tools.
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
#
# 	def run(self, showLogs, showReport):
#
# 		self.compileRegExp()
# 		print("-- process -------------------------")
# 		results = self.process()
# 		print("-- analyze -------------------------")
# 		self.analyze(results)
#
# 	def process(self):
# 		activeProcessors = []
# 		processorResults = {}
# 		for processor in self.processors:
# 			processorResults[processor['Name']] = []
#
# 		with self.Files["XSTReport"].open('r') as xstReportFileHandle:
# 			for line in xstReportFileHandle:
# 				#print("Line: " + line[:-1])
# 				for processor in self.processors:
# 					regExpMatch = processor['RegExp'].match(line)
# 					if (regExpMatch is not None):
# 						activeProcessor = ActiveProcessor(processor['Name'], processor['Extractor'].createGenerator())
# 						activeProcessor.send(None)
# 						activeProcessors.append(activeProcessor)
#
# 				for ap in activeProcessors:
# 					try:
# 						ap.send(line)
# 					except StopIteration as ex:
# 						processorResults[str(ap)].append(ex.value)
# 						activeProcessors.remove(ap)
#
# 			# cleaning up after looping all lines
# 			for ap in activeProcessors:
# 				ap.close()
#
# 		return processorResults
#
# 	def analyze(self, processorResults):
# 		for (key, value) in processorResults.items():
# 			if (key == "WarningExtractor"):
# 				print("Warnings (%i):" % len(value))
# 				self.analyzeWarnings(value)
# #				for i in value:
# #					print(i)
# 			elif (key == "ErrorExtractor"):
# 				print("Errors (%i):" % len(value))
# #				for i in value:
# #					print(i)
# 			elif (key == "FSMTokenFileExtractor"):
# 				self.analyzeFSMEncodings(value)
#
# 	def analyzeWarnings(self, warnings):
# 		import re
#
# 		regExpString = r"(?P<Process>\w+)\((?P<WarningID>\d+)\)"
# 		regExp = re.compile(regExpString)
#
# 		criticalWarningsFilterList = []
#
# 		keys = self.projectConfig.options('CriticalWarnings')
# 		for key in keys:
# 			regExpMatch = regExp.match(key)
# 			if (regExpMatch is not None):
# 				criticalWarningsFilterList.append({
# 					'Process' :    regExpMatch.group('Process'),
# 					'WarningID' :  int(regExpMatch.group('WarningID')),
# 					'Pattern' :    self.projectConfig['CriticalWarnings'][key]
# 				})
# 			else:
# 				print("ERROR: '%s'" % key)
#
#
# 		for warning in warnings:
# 			for filter in criticalWarningsFilterList:
# 				if ((warning['Process'] == filter['Process']) and
# 						(warning['WarningID'] == filter['WarningID']) and
# 						(re.compile(filter['Pattern']).match(warning['Message']) is not None)):
# 					#print("%s(%i): %s" % (warning['Process'], warning['WarningID'], warning['Message']))
# 					print(warning['Message'])
#
#
#
# 	def analyzeFSMEncodings(self, stateMachines):
# 		import re
#
# 		print("FSMs found: (%i)" % len(stateMachines))
#
# 		for fsm in stateMachines:
# 			key = "%s/%s" % (fsm['Path'], fsm['Signal'])
# 			self.printVerbose("  States: %2i    Path: %s" % (len(fsm['Encodings']), key))
#
# 			if (not self.projectConfig.has_option('FSM-Paths', key)):
# 				continue
#
# 			# resolve section
# 			section = self.projectConfig['FSM-Paths'][key]
#
# 			tokenFile = self.projectConfig[section]['TokenFileName']
# 			tokenFilePath = self.Directories['SolutionRoot'] / tokenFile
#
# 			replacementRules =  self.projectConfig[section]['Replacements']
# 			ruleList = replacementRules.split("\n")
#
# 			# prepare output string
# 			tokenFileContent = ""
#
# 			for enc in fsm['Encodings']:
# 				if (enc['StateEncoding'] is not None):
# 					tokenFileContent += "%s=%X\n" % (enc['StateName'], enc['StateEncoding'])
# 				else:
# 					tokenFileContent += "#%s=unreached\n" % enc['StateName']
#
# 			for rule in ruleList:
# 				[pattern, replacement] = rule.split(" -> ")
# 				#print("search: %s    replace with: %s" % (pattern[1:-1], replacement[1:-1]))
# 				tokenFileContent = re.sub(pattern[1:-1], replacement[1:-1], tokenFileContent)
#
# 			# Writing token file
# 			self.printVerbose("    Writing token file to '%s'" % str(tokenFilePath))
# 			with tokenFilePath.open('w') as tokenFileHandle:
# 				tokenFileHandle.write(tokenFileContent)
#
# 	def compileRegExp(self):
# 		import re
#
# 		for processor in self.processors:
# 			processor['RegExp'] = re.compile(processor['RegExpString'])
#
# 	def enableFSMTokenFileExtraction(self):
# 		ext = XSTFSMTokenFileExtractor.Extractor
# 		self.processors.append({
# 			'Name' :          ext.__name__,
# 			'RegExpString' :  ext.getInitializationRegExpString(),
# 			'RegExp' :        None,
# 			'Extractor' :      ext
# 		})
#
# 	def enableErrorExtraction(self):
# 		ext = XSTErrorExtractor.Extractor
# 		self.processors.append({
# 			'Name' :          ext.__name__,
# 			'RegExpString' :  ext.getInitializationRegExpString(),
# 			'RegExp' :        None,
# 			'Extractor' :      ext
# 		})
#
# 	def enableWarningExtraction(self):
# 		ext = XSTWarningExtractor.Extractor
# 		self.processors.append({
# 			'Name' :          ext.__name__,
# 			'RegExpString' :  ext.getInitializationRegExpString(),
# 			'RegExp' :        None,
# 			'Extractor' :      ext
# 		})
#
# class ActiveProcessor(object):
# 	Name =      ""
# 	Processor =  None
#
# 	def __init__(self, Name, Processor):
# 		self.Name = Name
# 		self.Processor = Processor
#
# 	def __str__(self):
# 		return self.Name
#
# 	def send(self, obj):
# 		return self.Processor.send(obj)
#
# 	def close(self):
# 		return self.Processor.close()
#
