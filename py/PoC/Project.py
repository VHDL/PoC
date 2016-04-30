# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t; python-indent-offset: 2 -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
# Authors:					Patrick Lehmann
#
# Python Class:			TODO
#
# Description:
# ------------------------------------
#		TODO:
#		-
#		-
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
	from lib.Functions import Exit
	Exit.printThisIsNoExecutableFile("The PoC-Library - Python Module PoC.Project")


# load dependencies
from lib.Decorators			import ILazyLoadable, LazyLoadTrigger
from Base.Exceptions		import CommonException
from Base.Project				import Project as BaseProject, File, FileTypes, VHDLSourceFile, VerilogSourceFile, CocotbSourceFile  #, ProjectFile
from Parser.FilesParser	import FilesParserMixIn
from Parser.RulesParser	import RulesParserMixIn
from PoC								import __POC_SOLUTION_KEYWORD__


class Base(ILazyLoadable):
	def __init__(self, name, host, configSection, parent):
		ILazyLoadable.__init__(self)

		self._name = name
		self._host = host
		self._configSection = configSection
		self._parent = parent

		self._Load()

	@property
	def Name(self):                return self._name
	@property
	def Parent(self):              return self._parent
	@property
	def ConfigSectionName(self):  return self._sectionName

	def _Load(self):
		pass


class Repository(Base):
	def __init__(self, host):
		self._host =			host

		self._solutions =	{}

		for sln in self._host.PoCConfig['SOLUTION.Solutions']:
			if (self._host.PoCConfig['SOLUTION.Solutions'][sln] == __POC_SOLUTION_KEYWORD__):
				sectionName = "SOLUTION.{0}".format(sln)
				if (len(self._host.PoCConfig[sectionName]) != 0):
					self._solutions[sln] = Solution(self._host, sectionName)

	@property
	@LazyLoadTrigger
	def Solutions(self):			return self._solutions.values()

	@property
	@LazyLoadTrigger
	def SolutionNames(self):	return self._solutions.keys()


	def GetSolutions(self):
		for sln in self._host.PoCConfig['SOLUTION.Solutions']:
			if (self._host.PoCConfig['SOLUTION.Solutions'][sln] == __POC_SOLUTION_KEYWORD__):
				sectionName = "SOLUTION.{0}".format(sln)
				if (len(self._host.PoCConfig[sectionName]) != 0):
					yield sln

	def GetSolutionNames(self):
		for sln in self._host.PoCConfig['SOLUTION.Solutions']:
			if (self._host.PoCConfig['SOLUTION.Solutions'][sln] == __POC_SOLUTION_KEYWORD__):
				sectionName = "SOLUTION.{0}".format(sln)
				if (len(self._host.PoCConfig[sectionName]) != 0):
					yield sln

class Solution(Base):
	def __init__(self, name, host, configSection, parent):
		self._name =					name
		self._host =					host
		self._configSection =	configSection
		self._parent =				parent

	def _Initialize(self):
		pass

	def GetSolutionNames(self):
		for sln in self._host.PoCConfig['SOLUTION.Solutions']:
			if (self._host.PoCConfig['SOLUTION.Solutions'][sln] == "Solution"):
				sectionName = "SOLUTION.{0}".format(sln)
				if (len(self._host.PoCConfig[sectionName]) != 0):
					yield sln


class Project(BaseProject):
	def __init__(self, name):
		super().__init__(name)

#class PoCProjectFile(ProjectFile):
#	def __init__(self, file):
#		ProjectFile.__init__(self, file)


class FileListFile(File, FilesParserMixIn):
	_FileType = FileTypes.FileListFile

	def __init__(self, file, project = None, fileSet = None):
		super().__init__(file, project=project, fileSet=fileSet)
		FilesParserMixIn.__init__(self)

		self._variables =								None

		# self.__classInclude
		self._classFileListFile =				FileListFile
		self._classVHDLSourceFile =			VHDLSourceFile
		self._classVerilogSourceFile =	VerilogSourceFile
		self._classCocotbSourceFile =		CocotbSourceFile

	def Parse(self):
		# print("FileListFile.Parse:")
		if (self._fileSet is None):											raise CommonException("File '{0!s}' is not associated to a fileset.".format(self._file))
		if (self._project is None):											raise CommonException("File '{0!s}' is not associated to a project.".format(self._file))
		if (self._project.RootDirectory is None):				raise CommonException("No RootDirectory configured for this project.")

		# prepare FilesParserMixIn environment
		self._rootDirectory = self.Project.RootDirectory
		self._variables =			self.Project.GetVariables()
		self._Parse()
		self._Resolve()

	def CopyFilesToFileSet(self):
		for file in self._files:
			self._fileSet.AddFile(file)

	def CopyExternalLibraries(self):
		for lib in self._libraries:
			self._project.AddExternalVHDLLibraries(lib)

	def __str__(self):
		return "FileList file: '{0!s}".format(self._file)


class RulesFile(File, RulesParserMixIn):
	_FileType = FileTypes.RulesFile

	def __init__(self, file, project = None, fileSet = None):
		super().__init__(file, project=project, fileSet=fileSet)
		RulesParserMixIn.__init__(self)

		self._variables =								None

	def Parse(self):
		if (self._fileSet is None):											raise CommonException("File '{0!s}' is not associated to a fileset.".format(self._file))
		if (self._project is None):											raise CommonException("File '{0!s}' is not associated to a project.".format(self._file))
		if (self._project.RootDirectory is None):				raise CommonException("No RootDirectory configured for this project.")

		# prepare FilesParserMixIn environment
		self._rootDirectory = self.Project.RootDirectory
		self._variables =			self.Project.GetVariables()
		self._Parse()
		self._Resolve()

	def __str__(self):
		return "FileList file: '{0!s}".format(self._file)

