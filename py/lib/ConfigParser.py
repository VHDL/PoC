

import re
from collections import ChainMap as _ChainMap
from configparser import ConfigParser, SectionProxy, Interpolation, MAX_INTERPOLATION_DEPTH
from configparser import NoSectionError, InterpolationDepthError, InterpolationSyntaxError, NoOptionError, InterpolationMissingOptionError


class ExtendedSectionProxy(SectionProxy):
	def __getitem__(self, key):
		if not self._parser.has_option(self._name, key):
			raise KeyError(self._name + ":" + key)
		return self._parser.get(self._name, key)

SectionProxy = ExtendedSectionProxy


class ExtendedInterpolation(Interpolation):
	"""
	Advanced variant of interpolation, supports the syntax used by
	`zc.buildout'. Enables interpolation between sections.
	"""

	_KEYCRE = re.compile(r"\$\{(?P<ref>[^}]+)\}")
	_KEYCRE2 = re.compile(r"\$\[(?P<ref>[^\]]+)\}")

	def before_get(self, parser, section, option, value, defaults):
		L = []
		self._interpolate_some(parser, option, L, value, section, defaults, 1)
		return ''.join(L)

	def before_set(self, parser, section, option, value):
		tmp_value = value.replace('$$', '') # escaped dollar signs
		tmp_value = self._KEYCRE.sub('', tmp_value) # valid syntax
		if '$' in tmp_value:
			raise ValueError("invalid interpolation syntax in %r at position %d" % (value, tmp_value.find('$')))
		return value

	def _interpolate_some(self, parser, option, accum, rest, section, map, depth):
		if depth > MAX_INTERPOLATION_DEPTH:			raise InterpolationDepthError(option, section, rest)

		print("interpolation begin: section={0} option={1}  accum='{2}'  rest='{3}'".format(section, option, accum, rest))

		while rest:
			beginPos = rest.find("$")
			if beginPos < 0:
				accum.append(rest)
				print("->" + "".join(accum))
				return
			if beginPos > 0:
				accum.append(rest[:beginPos])
				rest = rest[beginPos:]
			# p is no longer used
			if rest[1] == "$":
				accum.append("$")
				rest = rest[2:]
			elif rest[1] == "{":
				endPos = rest.find("}")
				nextPos = rest.rfind("$", None, endPos)
				# print("next={0}  end={1}".format(nextPos, endPos))
				if (endPos < 0):
					raise InterpolationSyntaxError(option, section, "bad interpolation variable reference %r" % rest)
				elif ((nextPos > 0) and (nextPos < endPos)):			# an embedded $
					L = []
					self._interpolate_some(parser, option, L, rest[nextPos:endPos+1], section, map, depth + 1)
					rest = rest[:nextPos] + "".join(L) + rest[endPos+1:]
					# print("new rest1='{0}'".format(rest))
				else:
					path = rest[2:endPos].split(':')
					rest = rest[endPos+1:]
					# print("new rest2='{0}'  path='{1}'".format(rest, path))

					sect = section
					opt = option
					try:
						if (len(path) == 1):
							opt = parser.optionxform(path[0])
							v = map[opt]
						elif (len(path) == 2):
							sect = path[0]
							opt = parser.optionxform(path[1])
							v = parser.get(sect, opt, raw=True)
						else:
							raise InterpolationSyntaxError(option, section, "More than one ':' found: %r" % (rest,))
					except (KeyError, NoSectionError, NoOptionError):
						raise InterpolationMissingOptionError(option, section, rest, ":".join(path)) from None

					# print("v='{0}'".format(v))

					if "$" in v:
						self._interpolate_some(parser, opt, accum, v, sect, dict(parser.items(sect, raw=True)), depth + 1)
					else:
						accum.append(v)
			else:
				raise InterpolationSyntaxError(option, section, "'$' must be followed by '$' or '{', found: %r" % (rest,))

		print("->" + "".join(accum))


class ExtendedConfigParser(ConfigParser):
	_DEFAULT_INTERPOLATION = ExtendedInterpolation()

	def _unify_values(self, section, vars):
		"""Create a sequence of lookups with 'vars' taking priority over
		the 'section' which takes priority over the DEFAULTSECT.

		"""
		sectiondict = {}
		try:
			sectiondict = self._sections[section]
		except KeyError:
			if section != self.default_section:
				raise NoSectionError(section)
		# Update with the entry specific variables
		vardict = {}
		if vars:
			for key, value in vars.items():
				if value is not None:
					value = str(value)
				vardict[self.optionxform(key)] = value
		prefix = section.split(".",1)[0] + ".DEFAULT"
		# print("searched for {0}".format(prefix))
		try:
			defaultdict = self._sections[prefix]
			return _ChainMap(vardict, sectiondict, defaultdict, self._defaults)
		except:
			return _ChainMap(vardict, sectiondict, self._defaults)

	def has_option(self, section, option):
		"""Check for the existence of a given option in a given section.
		If the specified `section' is None or an empty string, DEFAULT is
		assumed. If the specified `section' does not exist, returns False."""
		option = self.optionxform(option)
		if ((not section) or (section == self.default_section)):
			sect = self._defaults
		else:
			prefix = section.split(".", 1)[0] + ".DEFAULT"
			if ((prefix in self) and (option in self._sections[prefix])):
				return True
			if (section not in self._sections):
				return False
			else:
				sect = self._sections[section]
		return option in sect
