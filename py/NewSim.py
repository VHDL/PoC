
from colorama					import init

init(convert=True)

from Base.PoCConfig		import *
from Base.Project			import FileTypes
from Base.PoCProject	import *

PoCRoot =		r"G:\git\PoC"
# PoCRoot =		r"D:\git\PoC"
InputFile =	PoCRoot + r"\tb\sim\sim_ClockGenerator_tb.files"


# create a project
pocProject = PoCProject("sim_ClockGenerator_tb")

# configure the project
pocProject.RootDirectory =	PoCRoot
pocProject.Board =					"KC705"
pocProject.Environment =		Environment.Simulation
pocProject.ToolChain =			ToolChain.GHDL_GTKWave
pocProject.Tool =						Tool.GHDL
pocProject.VHDLVersion =		VHDLVersion.VHDL93#08

# add a *.files file
fileListFile = pocProject.AddFile(FileListFile(InputFile))
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
