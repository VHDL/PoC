
from Base.Exceptions	import *
from Base.Project			import *

class ISEProject(Project):
	def __init__(self, name):
		Project.__init__(self, name)

class ISEProjectFile(ProjectFile):
	def __init__(self, file):
		ProjectFile.__init__(self, file)

class UserConstraintFile(ConstraintFile):
	def __init__(self, file):
		ConstraintFile.__init__(self, file)

