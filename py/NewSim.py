
from Base.PoCConfig		import *
from Base.Project			import FileTypes
from Base.PoCProject	import *

# PoCRoot =		r"H:\Austausch\PoC"
PoCRoot =		r"D:\git\PoC"
InputFile =	PoCRoot + r"\tb\sim\sim_ClockGenerator_tb.files"


# create a project
pocProject = PoCProject("sim_ClockGenerator_tb")
pocProject.SetRootDirectory(PoCRoot)

# configure the project
board = Board("KC705")
pocProject.SetBoard(board)

# add a *.files file
fileListFile = FileListFile(InputFile)
pocProject.AddFile(fileListFile)

#fileListFile.Parse()
#fileListFile.CopyFilesToFileSet()

print("=" * 160)
# for vhdlFile in pocProject.GetFiles(fileType=FileTypes.VHDLSourceFile):
	# if ("config" in str(vhdlFile)):
		# vhdlFile.Parse()
		# print(vhdlFile.pprint("  "))
	# else:
		# print(vhdlFile)

print("=" * 160)
print(pocProject.pprint())
