
from Base.PoCConfig		import *
from Base.Project			import FileTypes
from Base.PoCProject	import *

pocProject = PoCProject("sim_ClockGenerator_tb")
pocProject.SetRootDirectory(r"H:\Austausch\PoC")

board = Board("KC705")
pocProject.SetBoard(board)

fileListFile = FileListFile(r"H:\Austausch\PoC\tb\sim\sim_ClockGenerator_tb.files")
pocProject.AddFile(fileListFile)

fileListFile.Parse()
fileListFile.CopyFilesToFileSet()

print("=" * 160)
# for vhdlFile in pocProject.GetFiles(fileType=FileTypes.VHDLSourceFile):
	# if ("config" in str(vhdlFile)):
		# vhdlFile.Parse()
		# print(vhdlFile.pprint("  "))
	# else:
		# print(vhdlFile)

print("=" * 160)
print(pocProject.pprint())
