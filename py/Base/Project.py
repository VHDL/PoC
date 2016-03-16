# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
# Authors:				 	Patrick Lehmann
# 
# Python Module:		TODO
# 
# Description:
# ------------------------------------
#		TODO:
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
#
# load dependencies
from enum								import Enum, EnumMeta, unique
from pathlib						import Path

from lib.Functions			import merge
from Base.Exceptions		import *
from Base.VHDLParser		import VHDLParserMixIn
from Base.PoCConfig			import Board, Device
from Parser.FilesParser	import FilesParserMixIn

# ToDo nested filesets

@unique
class FileTypes(Enum):
	Any =									0
	Text =								1
	ProjectFile =					2
	FileListFile =				3
	ConstraintFile =			4
	SourceFile =					5
	VHDLSourceFile =			10
	VerilogSourceFile =		11

	def Extension(self):
		if   (self == FileTypes.Any):									raise BaseException("Generic file type.")
		elif (self == FileTypes.Text):								return "txt"
		elif (self == FileTypes.FileListFile):				return "files"
		elif (self == FileTypes.ConstraintFile):			raise BaseException("Generic file type.")
		elif (self == FileTypes.SourceFile):					raise BaseException("Generic file type.")
		elif (self == FileTypes.VHDLSourceFile):			return "vhdl"
		elif (self == FileTypes.VerilogSourceFile):		return "v"
		else:																					raise BaseException("This is not an enum member.")
		
	def __str__(self):
		return self.name

@unique
class Environment(Enum):
	Any =					0
	Simulation =	1
	Synthesis =		2
	
@unique
class ToolChain(Enum):
	Any =								 0
	Aldec_ActiveHDL =		10
	Altera_QuartusII =	20
	Altera_ModelSim =		21
	Lattice_LSE =				30
	GHDL_GTKWave =			40
	Mentor_QuestaSim =	50
	Xilinx_ISE =				60
	Xilinx_PlanAhead =	61
	Xilinx_Vivado =			62
	
@unique
class Tool(Enum):
	Any =								 0
	Aldec_aSim =				10
	Altera_QuartusII =	20
	Lattice_LSE =				30
	GHDL =							40
	GTKwave =						41
	Mentor_vSim =				50
	Xilinx_XST =				60
	Xilinx_CoreGen =		61
	Xilinx_Synth =			62
	Xilinx_iSim =				70
	Xilinx_xSim =				71

@unique
class VHDLVersion(Enum):
	Any =								 0
	VHDL87 =						87
	VHDL93 =						93
	VHDL02 =						2002
	VHDL08 =						2008
	
	@classmethod
	def parse(cls, value):
		for member in cls:
			if (member.value == value):
				return member
		raise ValueError("'{0}' is not a member of {1}.".format(str(value), cls.__name__))
	
class Project():
	def __init__(self, name):
		# print("Project.__init__: name={0}".format(name))
		self._name =						name
		self._rootDirectory =		None
		self._fileSets =				{}
		self._defaultFileSet =	None
		
		self._board =						None
		self._device =					None
		self._environment =			Environment.Any
		self._toolChain =				ToolChain.Any
		self._tool =						Tool.Any
		self._vhdlVersion =			VHDLVersion.Any
		
		self.CreateFileSet("default", setDefault=True)
	
	@property
	def Name(self):
		return self._name
	
	@property
	def RootDirectory(self):
		return self._rootDirectory
	
	@RootDirectory.setter
	def RootDirectory(self, value):
		if isinstance(value, str):	value = Path(value)
		self._rootDirectory = value
	
	@property
	def Board(self):
		return self._board
	
	@Board.setter
	def Board(self, value):
		if isinstance(value, str):
			value = Board(value)
		elif (not isinstance(value, Board)):						raise ValueError("Parameter 'board' is not of type Board.")
		self._board =		value
		self._device =	value.Device
	
	@property
	def Device(self):
		return self._device
	
	@Device.setter
	def Device(self, value):
		if isinstance(value, (str, Device)):
			board = Board("custom", value)
		else:																						raise ValueError("Parameter 'device' is not of type str or Device.")
		self._board =		board
		self._device =	board.Device
	
	@property
	def Environment(self):
		return self._environment
	
	@Environment.setter
	def Environment(self, value):
		self._environment = value
	
	@property
	def ToolChain(self):
		return self._toolChain
	
	@ToolChain.setter
	def ToolChain(self, value):
		self._toolChain = value
	
	@property
	def Tool(self):
		return self._tool
	
	@Tool.setter
	def Tool(self, value):
		self._tool = value
	
	@property
	def VHDLVersion(self):
		return self._vhdlVersion
	
	@VHDLVersion.setter
	def VHDLVersion(self, value):
		self._vhdlVersion = value
	
	def CreateFileSet(self, name, setDefault=True):
		fs =											FileSet(name, project=self)
		self._fileSets[name] =		fs
		if (setDefault == True):
			self._defaultFileSet =	fs
	
	def AddFileSet(self, fileSet):
		if (not isinstance(fileSet, FileSet)):
			raise ValueError("Parameter 'fileSet' is not of type Base.Project.FileSet.")
		if (fileSet in self.FileSets):
			raise BaseException("Project already contains this fileSet.")
		if (fileSet.Name in self._fileSets.keys()):
			raise BaseException("Project already contains a fileset named ''.".format(fileSet.Name))
		fileSet.Project = self
		self._fileSets[fileSet.Name] = fileSet
		
		# TODO: assign all files to this project
	
	@property
	def FileSets(self):
		return [i for i in self._fileSets.values()]
		
	@property
	def DefaultFileSet(self):
		return self._defaultFileSet
	
	@DefaultFileSet.setter
	def DefaultFileSet(self, value):
		if isinstance(value, str):
			if (value not in self._fileSets.keys()):			raise BaseException("Fileset '{0}' is not in this project.".format(value))
			self._defaultFileSet = self._fileSets[value]
		elif isinstance(value, FileSet):
			if (value not in self.FileSets):							raise BaseException("Fileset '{0}' is not associated to this project.".format(value))
			self._defaultFileSet = value
		else:																						raise ValueError("Unsupported parameter type for 'value'.")
	
	def AddFile(self, file, fileSet = None):
		# print("Project.AddFile: file={0}".format(file))
		if (not isinstance(file, File)):								raise ValueError("Parameter 'file' is not of type Base.Project.File.")
		if (fileSet is None):
			if (self._defaultFileSet is None):						raise BaseException("Neither the parameter 'file' set nor a default file set is given.")
			fileSet = self._defaultFileSet
		elif isinstance(fileSet, str):
			fileSet = self._fileSets[fileSet]
		elif isinstance(fileSet, FileSet):
			if (fileSet not in self.FileSets):						raise BaseException("Fileset '{0}' is not associated to this project.".format(value))
		else:																						raise ValueError("Unsupported parameter type for 'fileSet'.")
		fileSet.AddFile(file)
		return file
		
	def AddSourceFile(self, file, fileSet = None):
		# print("Project.AddSourceFile: file={0}".format(file))
		if (not isinstance(file, SourceFile)):					raise ValueError("Parameter 'file' is not of type Base.Project.SourceFile.")
		if (fileSet is None):
			if (self._defaultFileSet is None):						raise BaseException("Neither the parameter 'file' set nor a default file set is given.")
			fileSet = self._defaultFileSet
		elif isinstance(fileSet, str):
			fileSet = self._fileSets[fileSet]
		elif isinstance(fileSet, FileSet):
			if (fileSet not in self.FileSets):						raise BaseException("Fileset '{0}' is not associated to this project.".format(value))
		else:																						raise ValueError("Unsupported parameter type for 'fileSet'.")
		fileSet.AddSourceFile(file)
		return file
	
	def Files(self, fileType=FileTypes.Any, fileSet=None):
		if (fileSet is None):
			if (self._defaultFileSet is None):						raise BaseException("Neither the parameter 'fileSet' set nor a default file set is given.")
			fileSet = self._defaultFileSet
		print("init Project.Files generator")
		for file in fileSet.Files:
			if (file.FileType == fileType):
				yield file
	
	def _GetVariables(self):
		result = {
			"ProjectName" :			self._name,
			"RootDirectory" :		str(self._rootDirectory),
			"Environment" :			self._environment.name,
			"ToolChain" :				self._toolChain.name,
			"Tool" :						self._tool.name,
			"VHDL" :						self._vhdlVersion.value
		}
		return merge(result, self._board._GetVariables(), self._device._GetVariables())
	
	def pprint(self):
		buffer =	"Project: {0}\n".format(self.Name)
		buffer +=	"  Settings:\n"
		buffer +=	"    Board: {0}\n".format(self._board.Name)
		buffer +=	"    Device: {0}\n".format(self._device.Name)
		for fileSet in self.FileSets:
			buffer += "  FileSet: {0}\n".format(fileSet.Name)
			for file in fileSet.Files:
				buffer += "    {0}\n".format(file.FileName)
		return buffer
	
	def __str__(self):
		return self._name

class FileSet:
	def __init__(self, name, project = None):
		# print("FileSet.__init__: name={0}  project={0}".format(name, project))
		self._name =		name
		self._project =	project
		self._files =		[]
	
	@property
	def Name(self):
		return self._name
	
	@property
	def Project(self):
		return self._project
	
	@Project.setter
	def Project(self, value):
		if not isinstance(value, Project):							raise ValueError("Parameter 'value' is not of type Base.Project.Project.")
		self._project = value
	
	@property
	def Files(self):
		return self._files
	
	def AddFile(self, file):
		# print("FileSet.AddFile: file={0}".format(file))
		if isinstance(file, str):
			file = Path(file)
			file = File(file, project=self._project, fileSet=self)
		elif isinstance(file, Path):
			file = File(file, project=self._project, fileSet=self)
		elif isinstance(file, SourceFile):
			self.AddSourceFile(file)
			return
		elif (not isinstance(file, File)):							raise ValueError("Unsupported parameter type for 'file'.")
		file.FileSet = self
		file.Project = self._project
		self._files.append(file)
		
	def AddSourceFile(self, file):
		# print("FileSet.AddSourceFile: file={0}".format(file))
		if isinstance(file, str):
			file = Path(file)
			file = SourceFile(file, project=self._project, fileSet=self)
		elif isinstance(file, Path):
			file = SourceFile(file, project=self._project, fileSet=self)
		elif (not isinstance(file, SourceFile)):				raise ValueError("Unsupported parameter type for 'file'.")
		file.FileSet = self
		file.Project = self._project
		self._files.append(file)
	
	def __str__(self):
		return self._name

class File():
	def __init__(self, file, project = None, fileSet = None):
		self._handle =	None
		self._content =	None
		
		if isinstance(file, str):
			file = Path(file)
		self._file =		file
		self._project =	project
		self._fileSet =	fileSet
	
	@property
	def Project(self):
		return self._project
	
	@Project.setter
	def Project(self, value):
		if not isinstance(value, Project):							raise ValueError("Parameter 'value' is not of type Base.Project.Project.")
		# print("File.Project(setter): value={0}".format(value))
		self._project = value
	
	@property
	def FileSet(self):
		return self._fileSet
	
	@FileSet.setter
	def FileSet(self, value):
		if (value is None):															raise ValueError("'value' is None")
		# print("File.FileSet(setter): value={0}".format(value))
		self._fileSet =	value
		self._project =	value.Project
	
	@property
	def FileType(self):
		return FileTypes.Unknown
	
	@property
	def FileName(self):
		return str(self._file)
	
	@property
	def FilePath(self):
		return self._file
	
	def Open(self):
		if (not self._file.exists()):										raise FileNotFoundError("File '{0}' not found.".format(str(self._file)))
		try:
			self._handle = self._file.open('r')
		except Exception as ex:
			raise BaseException("Error while opening file '{0}'.".format(str(self._file))) from ex
	
	def ReadFile(self):
		if self._handle is None:
			self.Open()
		try:
			self._content = self._handle.read()
		except Exception as ex:
			raise BaseException("Error while reading file '{0}'.".format(str(self._file))) from ex
	
	# interface method for FilesParserMixIn
	def _ReadContent(self):
		self.ReadFile()
	
	def __str__(self):
		return str(self._file)

class ProjectFile(File):
	def __init__(self, file, project = None, fileSet = None):
		File.__init__(self, file, project=project, fileSet=fileSet)
		
	@property
	def FileType(self):
		return FileTypes.ProjectFile
	
	def __str__(self):
		return "Project file: '{0}".format(str(self._file))

class FileListFile(File, FilesParserMixIn):
	def __init__(self, file, project = None, fileSet = None):
		File.__init__(self, file, project=project, fileSet=fileSet)
		FilesParserMixIn.__init__(self)
		
		self._classFileListFile =		FileListFile
		self._classVHDLSourceFile =	VHDLSourceFile
	
	@property
	def FileType(self):
		return FileTypes.FileListFile
	
	def Parse(self):
		# print("FileListFile.Parse:")
		if (self._fileSet is None):											raise BaseException("File '{0}' is not associated to a fileset.".format(str(self._file)))
		if (self._project is None):											raise BaseException("File '{0}' is not associated to a project.".format(str(self._file)))
		if (self._project.RootDirectory is None):				raise BaseException("No RootDirectory configured for this project.")
			
		# prepare FilesParserMixIn environment
		self._rootDirectory = self.Project.RootDirectory
		self._variables =			self.Project._GetVariables()
		self._Parse()
		self._Resolve()
	
	def CopyFilesToFileSet(self):
		for file in self._files:
			self._fileSet.AddFile(file)
		
	def __str__(self):
		return "FileList file: '{0}".format(str(self._file))
		
class SourceFile(File):
	def __init__(self, file, project = None, fileSet = None):
		File.__init__(self, file, project=project, fileSet=fileSet)
	
	@property
	def FileType(self):
		return FileTypes.SourceFile
	
	def __str__(self):
		return "Source file: '{0}".format(str(self._file))

class ConstraintFile(File):
	def __init__(self, file, project = None, fileSet = None):
		File.__init__(self, file, project=project, fileSet=fileSet)
	
	@property
	def FileType(self):
		return FileTypes.ConstraintFile
	
	def __str__(self):
		return "Constraint file: '{0}".format(str(self._file))

class HDLFileMixIn():
	def __init__(self):
		pass

class VHDLSourceFile(SourceFile, HDLFileMixIn, VHDLParserMixIn):
	def __init__(self, file, project = None, fileSet = None):
		SourceFile.__init__(self, file, project=project, fileSet=fileSet)
		HDLFileMixIn.__init__(self)
		VHDLParserMixIn.__init__(self)
	
	@property
	def FileType(self):
		return FileTypes.VHDLSourceFile
	
	def Parse(self):
		self._Parse()
	
	def __str__(self):
		return "VHDL file: '{0}".format(str(self._file))

class VerilogSourceFile(SourceFile, HDLFileMixIn):
	def __init__(self, file, project = None, fileSet = None):
		SourceFile.__init__(self, file, project=project, fileSet=fileSet)
		HDLFileMixIn.__init__(self)
	
	@property
	def FileType(self):
		return FileTypes.VerilogSourceFile
	
	def __str__(self):
		return "Verilog file: '{0}".format(str(self._file))

