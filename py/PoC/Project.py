

class Project(object):
	pass

class File(object):
	pass

class ProjectFile(File):
	pass

class SourceFile(File):
	pass

class ConstraintFile(File):
	pass

class HDLFile(object):
	pass

class VHDLSourceFile(SourceFile, HDLFile):
	pass

class VerilogSourceFile(SourceFile, HDLFile):
	pass

