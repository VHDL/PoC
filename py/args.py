
from copy			import copy
from pathlib	import Path

class CommandLineArgument(type):
	_value = None
	
	# def __new__(mcls, name, bases, nmspc):
		# print("CommandLineArgument.new: %s - %s" % (name, nmspc))
		# return super(CommandLineArgument, mcls).__new__(mcls, name, bases, nmspc)

class ExecutableArgument(CommandLineArgument):
	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if isinstance(value, str):			self._value = value
		elif isinstance(value, Path):		self._value = str(value)
		else:														raise ValueError("Parameter 'value' is not of type str or Path.")

	def __str__(self):
		if (self._value is None):				return ""
		else:														return self._value

	def AsArgument(self):
		if (self._value is None):				raise ValueError("Executable argument is still empty.")
		else:														return self._value

class StringArgument(CommandLineArgument):
	_pattern =	"{0}"

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:												self._value = str(value)
			except Exception as ex:			raise ValueError("Parameter 'value' cannot be converted to type str.") from ex

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._value)
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._value)
		else:													return None

class StringListArgument(CommandLineArgument):
	_pattern =	"{0}"

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, (tuple, list)):
			self._value = []
			try:
				for item in value:				self._value.append(str(value))
			except TypeError as ex:			raise ValueError("Item '{0}' in parameter 'value' cannot be converted to type str.".format(item)) from ex
		else:													raise ValueError("Parameter 'value' is no list or tuple.") from ex

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return " ".join([self._pattern.format(item) for item in self._value])
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return [self._pattern.format(item) for item in self._value]
		else:													return None

class PathArgument(CommandLineArgument):
	_PosixFormat = False

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):							self._value = None
		elif isinstance(value, Path):		self._value = value
		else:														raise ValueError("Parameter 'value' is not of type Path.")

	def __str__(self):
		if (self._value is None):				return ""
		elif (self._PosixFormat):				return "\"" + self._value.as_posix() + "\""
		else:														return "\"" + str(self._value) + "\""

	def AsArgument(self):
		if (self._value is None):				return None
		elif (self._PosixFormat):				return self._value.as_posix()
		else:														return str(self._value)

class FlagArgument(CommandLineArgument):
	_pattern =		"{0}"

	@property
	def Name(self):
		return self._name

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, bool):	self._value = value
		else:													raise ValueError("Parameter 'value' is not of type bool.")

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._name)
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._name)
		else:													return None

class ShortFlagArgument(FlagArgument):		_pattern =	"-{0}"
class LongFlagArgument(FlagArgument):			_pattern =	"--{0}"
class WindowsFlagArgument(FlagArgument):	_pattern =	"/{0}"

class ValuedFlagArgument(CommandLineArgument):
	_pattern = "{0}={1}"

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:												self._value = str(value)
			except Exception as ex:			raise ValueError("Parameter 'value' cannot be converted to type str.") from ex

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._pattern.format(self._name, self._value)
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return self._pattern.format(self._name, self._value)
		else:													return None

class ShortValuedFlagArgument(ValuedFlagArgument):	_pattern = "-{0}={1}"
class LongValuedFlagArgument(ValuedFlagArgument):		_pattern = "--{0}={1}"

class TupleArgument(CommandLineArgument):
	_switchPattern =	"{0}"
	_valuePattern =		"{0}"

	@property
	def Value(self):
		return self._value

	@Value.setter
	def Value(self, value):
		if (value is None):						self._value = None
		elif isinstance(value, str):	self._value = value
		else:
			try:												self._value = str(value)
			except TypeError as ex:			raise ValueError("Parameter 'value' cannot be converted to type str.") from ex

	def __str__(self):
		if (self._value is None):			return ""
		elif self._value:							return self._switchPattern.format(self._name) + " " + self._valuePattern.format(self._value)
		else:													return ""

	def AsArgument(self):
		if (self._value is None):			return None
		elif self._value:							return [self._switchPattern.format(self._name), self._valuePattern.format(self._value)]
		else:													return None

class ShortTupleArgument(TupleArgument):		_switchPattern = "-{0}"
class LongTupleArgument(TupleArgument):			_switchPattern = "--{0}"

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
		i = self.index(key)
		super().__getitem__(i).Value = None
	
	def ToArgumentList(self):
		result = []
		for item in self:
			arg = item.AsArgument()
			if (arg is None):						pass
			elif isinstance(arg, str):	result.append(arg)
			elif isinstance(arg, list):	result += arg
			else:												raise TypeError()
		return result


class Class0:
	def __init__(self, exe=None):
		self.Parameters[self.Executable] = exe
	
	class Executable(metaclass=ExecutableArgument):		pass
	class Flag1(metaclass=ShortFlagArgument):					_name = "flag1"
	class Flag2(metaclass=ShortFlagArgument):					_name = "flag2"
	class Flag3(metaclass=ShortFlagArgument):					_name = "flag3"
	
	Flag4 = ShortFlagArgument("Flag4", (), {"_name" : "flag4"})
	
	Parameters = CommandLineArgumentList(
		Executable,
		Flag1,
		Flag2,
		Flag3
	)

class Meta(type):
	def __new__(mcls, name, bases, members):
		for n in members :
			m = members[n]
			if isinstance(m, CommandLineArgumentList) :
				newMembers =	members.copy()
				# print("copy arg classes ...")
				for i,P in enumerate(bases[0].Parameters):
					# print("  copy " + P.__name__)
					p = copy(P)
					newMembers[P.__name__] =	p
					m.insert(i, p)

		return super(Meta, mcls).__new__(mcls, name, bases, newMembers)

	# def __init__(mcls, name, bases, members):
		# print("init: \n  " + "\n  ".join([(key + " -> " + str(members[key])) for key in members]))
	
class Class1(Class0, metaclass=Meta):
	def __init__(self, exe=None):
		# print(type(self.Parameters))
		self.Parameters[self.Executable] = exe

	class Flag5(metaclass=ShortFlagArgument):					_name = "verbose"
	class Flag6(metaclass=ShortFlagArgument):					_name = "foo"
	
	Parameters = CommandLineArgumentList(
		Flag5,
		Flag6
	)

class Class2(Class0, metaclass=Meta):
	def __init__(self, exe=None):
		self.Parameters[self.Executable] = exe
	
	class Flag5(metaclass=ShortFlagArgument):					_name = "debug"
	class Flag6(metaclass=ShortFlagArgument):					_name = "bar"
	
	Parameters = CommandLineArgumentList(
		Flag5,
		Flag6
	)

c0 = Class1("fuse.exe")
c0.Parameters[c0.Executable] =	"xsim.exe"



c1 = Class1("asim.exe")
c1.Parameters[c1.Flag1] =			True
c1.Parameters[c1.Flag5] =			True

print()
print(c0.Parameters.ToArgumentList())
print(c1.Parameters.ToArgumentList())

c2 = Class2("vsim.exe")
# c2.Parameters[t.Executable] =	"vsim.exe"
c2.Parameters[c2.Flag3] =			True
c2.Parameters[c2.Flag6] =			True


print()
print(c0.Parameters.ToArgumentList())
print(c1.Parameters.ToArgumentList())
print(c2.Parameters.ToArgumentList())

