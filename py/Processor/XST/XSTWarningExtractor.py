

from Base.Simulator import BaseExtractor
from Base.Processor import ProcessorException, PostProcessorException

class Extractor(BaseExtractor):

	@classmethod
	def getInitializationRegExpString(cls):
		return r".*?WARNING:.*"
	
	@classmethod
	def getStartRegExpString(cls):
		# parse project filelist
		str  = r".*?"									# start of line
		str += r"WARNING:"						#	FSM path
		str += r"(?P<Process>\w+):"		# 
		str += r"(?P<WarningID>\d+)"	#	state signal name
		str += r" - "									# 
		str += r"(?P<Message>.*)"			#	FSM encoding
		return str
	
	@classmethod
	def createGenerator(cls):
		import re
		
		startRegExp =			re.compile(cls.getStartRegExpString())		# move out
		
		line = yield
		regExpMatch = startRegExp.match(line)
		if (regExpMatch is not None):
			result = {
				'Process' :			regExpMatch.group('Process'),
				'WarningID' :		int(regExpMatch.group('WarningID')),
				'Message' :			regExpMatch.group('Message')
			}
			return result
		else:
			raise ProcessorException("Line does not match.")
