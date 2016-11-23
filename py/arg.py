class CommandLineArgument(type):
	_value = None

	# def __new__(mcls, name, bases, nmspc):
		# print("CommandLineArgument.new: %s - %s" % (name, nmspc))
		# return super(CommandLineArgument, mcls).__new__(mcls, name, bases, nmspc)

class FlagArgument(CommandLineArgument):
	# def __new__(mcls, name, bases, nmspc):
		# print("FlagArgument.new: %s - %s" % (name, nmspc))
		# return super(FlagArgument, mcls).__new__(mcls, name, bases, nmspc)

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):
			self._value = None
		elif isinstance(value, bool):
			self._value = value
		else:
			raise ValueError("Parameter 'value' is not of type bool.")

	def __str__(self):
		if (self._value is None):
			return ""
		elif self._value:
			return self._name
		else:
			return ""

	def AsArgument(self):
		if (self._value is None):
			return None
		elif self._value:
			return self._name
		else:
			return None

class StringArgument(CommandLineArgument):
	# def __new__(mcls, name, bases, nmspc):
		# print("FlagArgument.new: %s - %s" % (name, nmspc))
		# return super(FlagArgument, mcls).__new__(mcls, name, bases, nmspc)

	@property
	def Value(self):
		return self._value
	@Value.setter
	def Value(self, value):
		if (value is None):
			self._value = None
		elif isinstance(value, str):
			self._value = value
		else:
			raise ValueError("Parameter 'value' is not of type str.")

	def __str__(self):
		if (self._value is None):
			return ""
		elif self._value:
			return self._name + str(self._value)
		else:
			return ""

	def AsArgument(self):
		if (self._value is None):
			return None
		elif self._value:
			return self._name + str(self._value)
		else:
			return None

class CommandLineArgumentList(list):
	def __init__(self, *args):
		super().__init__()
		for arg in args:
			self.append(arg)

	def __getitem__(self, key):
		i = self.index(key)
		return super().__getitem__(i).Value

	def __setitem__(self, key, value):
		i = self.index(key)
		super().__getitem__(i).Value = value

	def __delitem__(self, key):
		raise TypeError("'CommandLineArgumentList' object doesn't support item deletion")

	def ToArgumentList(self):
		result = []
		for item in self:
			arg = item.AsArgument()
			if (arg is None):           pass
			elif isinstance(arg, str):  result.append(arg)
			elif isinstance(arg, list): result += arg
			else:                       raise TypeError()
		return result

class VerboseFlag(metaclass=FlagArgument):
	_name =    "-v"
	_value =  None

# print("str:  " + VerboseFlag.__str__(VerboseFlag))
# print("repr: " + repr(VerboseFlag))

# VerboseFlag.Value = True
# print("str:  " + VerboseFlag.__str__())
# print("repr: " + repr(VerboseFlag))

# VerboseFlag.Value = False
# print("str:  " + str(VerboseFlag))
# print("repr: " + repr(VerboseFlag))

# VerboseFlag.Value = None
# print("str:  " + str(VerboseFlag))
# print("repr: " + repr(VerboseFlag))

class LibrarySwitch(metaclass=StringArgument):
	_name =    "-work="
	_value =  None

# print("str:  " + str(LibrarySwitch))
# print("repr: " + repr(LibrarySwitch))

# LibrarySwitch.Value = "poc"
# print("str:  " + str(LibrarySwitch))
# print("repr: " + repr(LibrarySwitch))

# LibrarySwitch.Value = "test"
# print("str:  " + str(LibrarySwitch))
# print("repr: " + repr(LibrarySwitch))

# LibrarySwitch.Value = None
# print("str:  " + str(LibrarySwitch))
# print("repr: " + repr(LibrarySwitch))


# entry point
if __name__ == "__main__":
	args = CommandLineArgumentList(VerboseFlag, LibrarySwitch)
	args[VerboseFlag] =    True
	args[LibrarySwitch] =  "poc"

	print("Verbose: " + str(args[VerboseFlag]))
	print("'" + ("' '".join(args.ToArgumentList())) + "'")

	args[LibrarySwitch] =  "test"
	print("'" + ("' '".join(args.ToArgumentList())) + "'")

	args[LibrarySwitch] =  None
	print("'" + ("' '".join(args.ToArgumentList())) + "'")

	args[VerboseFlag] =    False
	print("'" + ("' '".join(args.ToArgumentList())) + "'")
