
import re

from Base.Simulator import BaseExtractor
from Processor.Exceptions import *

class Extractor(BaseExtractor):

	@classmethod
	def getInitializationRegExpString(cls):
		return r"Optimizing FSM <.+?> on signal <.+?> with \w+ encoding\."
	
	@classmethod
	def getStartRegExpString(cls):
		# parse project filelist
		str	 = r"Optimizing FSM "										# start of line
		str += r"<(?P<FSMPath>.+?)/FSM_\d+>"				#	FSM path
		str += r" on signal "												# 
		str += r"<(?P<SignalName>\w+)\[\d+:\d+\]>"	#	state signal name
		str += r" with "														# 
		str += r"(?P<Encoding>\w+)"									#	FSM encoding
		str += r" encoding\."												# 
		return str
	
	@classmethod
	def getLineRegExpString(cls):
		return r"[-]+"
	
	@classmethod
	def getHeadingsRegExpString(cls):
		return r" State\s+\| Encoding"
	
	@classmethod
	def getEncodingRegExpString(cls):
		str = r" (?P<StateName>[_a-z0-9]+)"							# 
		str += r"\s+\| "																# 
		str += r"(?P<StateEncoding>([01]+|unreached))"	# 
		return str
	
	@classmethod
	def createGenerator(cls):
		startRegExp =			re.compile(cls.getStartRegExpString())
		lineRegExp =			re.compile(cls.getLineRegExpString())
		headingsRegExp =	re.compile(cls.getHeadingsRegExpString())
		encodingRegExp =	re.compile(cls.getEncodingRegExpString())
		
		# prepare result structure
		result = {
			'Path' :				"",
			'Signal' :			"",
			'XSTEncoding' :	"",
			'Encodings' :		[]
		}
	
		# Get first line -> check pattern
		line = yield
		regExpMatch = startRegExp.match(line)
		if (regExpMatch is not None):
			result['Path'] =					regExpMatch.group('FSMPath')
			result['Signal'] =				regExpMatch.group('SignalName')
			result['XSTEncoding'] =		regExpMatch.group('Encoding')
		else:
			raise ProcessorException("Line does not match.")
					
		# Found FSMName -> check for delimiter line
		line = yield
		regExpMatch = lineRegExp.match(line)
		if (regExpMatch is None):
			raise ProcessorException("Line does not match. Line: '%s'" % line)
			
		# Found delimiter line -> check for headings
		line = yield
		regExpMatch = headingsRegExp.match(line)
		if (regExpMatch is None):
			raise ProcessorException("Line does not match.")
			
		# Found headings -> check for delimiter line
		line = yield
		regExpMatch = lineRegExp.match(line)
		if (regExpMatch is None):
			raise ProcessorException("Line does not match.")
			
		# Found delimiter line -> read encodings
		while (True):
			line = yield
			regExpMatch = encodingRegExp.match(line)
			if (regExpMatch is not None):
				stateEncoding = regExpMatch.group('StateEncoding')
				result['Encodings'].append({
					'StateName' :			regExpMatch.group('StateName'),
					'StateEncoding' :	None if (stateEncoding == "unreached") else int(stateEncoding, 2)
				})
			
			else:
				regExpMatch = lineRegExp.match(line)
				if (regExpMatch is not None):
					break;
				else:
					raise ProcessorException("Line does not match.")
					
		# Found last delimiter line
		return result
