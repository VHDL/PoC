

import functools

class CachedReadOnlyProperty:
	def __init__(self, func):
		self.func =		func
		self.__cache =	None
	
	def __call__(self, *args):
		if self.__cache is None:
			result = self.func(*args)
			self.__cache = result
		return self.__cache
	
	def __repr__(self):
		return self.func.__doc__
	
	def __get__(self, obj, objtype):
		functools.partial(self.__call__, obj)

def property(function):
	import sys
	import builtins
	
	keys = 'fget', 'fset', 'fdel'
	func_locals = {'doc' : function.__doc__}
	def probe_func(frame, event, arg):
		if event == 'return':
			locals = frame.f_locals
			func_locals.update(dict((k, locals.get(k)) for k in keys))
			sys.settrace(None)
		return probe_func
	sys.settrace(probe_func)
	function()
	return builtins.property(**func_locals)