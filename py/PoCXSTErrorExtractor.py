
import re

from Base import Extractor
from Processor import ProcessorException

class ErrorExtractor(Extractor):

	@classmethod
	def getInitializationRegExpString(cls):
		return r".*?ERROR:.*"
	
	@classmethod
	def getStartRegExpString(cls):
		# parse project filelist
		str	 = r".*?"									# start of line
		str += r"ERROR:"							#	FSM path
		str += r"(?P<Process>\w+):"		# 
		str += r"(?P<ErrorID>\d+)"		#	state signal name
		str += r" - "									# 
		str += r"(?P<Message>.*)"			#	FSM encoding
		return str
	
	@classmethod
	def createGenerator(cls):
		startRegExp =			re.compile(cls.getStartRegExpString())		# move out
		
		line = yield
		regExpMatch = startRegExp.match(line)
		if (regExpMatch is not None):
			result = {
				'Process' :			regExpMatch.group('Process'),
				'ErrorID' :			int(regExpMatch.group('ErrorID')),
				'Message' :			regExpMatch.group('Message')
			}
			return result
		else:
			raise ProcessorException("Line does not match.")