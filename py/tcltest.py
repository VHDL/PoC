
from pathlib        import Path
from subprocess      import Popen		as Subprocess_Popen
from subprocess      import PIPE			as Subprocess_Pipe
from subprocess      import STDOUT		as Subprocess_StdOut

class Executable:
	_POC_BOUNDARY = "====== POC BOUNDARY ======"

	def __init__(self, executablePath):
		self._process =    None

		if isinstance(executablePath, str):              executablePath = Path(executablePath)
		elif (not isinstance(executablePath, Path)):    raise ValueError("Parameter 'executablePath' is not of type str or Path.")
		if (not executablePath.exists()):                raise Exception("Executable '{0!s}' not found.".format(executablePath)) from FileNotFoundError(str(executablePath))

		# prepend the executable
		self._executablePath =    executablePath

	@property
	def Path(self):
		return self._executablePath

	def StartProcess(self, parameterList):
		# start child process
		parameterList.insert(0, str(self._executablePath))
		self._process = Subprocess_Popen(parameterList, stdin=Subprocess_Pipe, stdout=Subprocess_Pipe, stderr=Subprocess_StdOut, universal_newlines=True, bufsize=16)

	def Send(self, line):
		self._process.stdin.write(line)
		self._process.stdin.flush()

	def SendBoundary(self):
		self._process.stdin.write("puts \"{0}\"\n".format(self._POC_BOUNDARY))
		self._process.stdin.flush()

	def Terminate(self):
		self._process.terminate()

	def GetReader(self):
		try:
			# for line in self._process.stdout.readlines():
			for line in iter(self._process.stdout.readline, ""):
				yield line[:-1]
		except Exception as ex:
			raise ex
		# finally:
			# self._process.terminate()


tclShell = Executable(r"C:\Lattice\diamond\3.7_x64\bin\nt64\pnmainc.exe")
print("starting process: {0!s}".format(tclShell.Path))
tclShell.StartProcess([])
reader = tclShell.GetReader()
iterator = iter(reader)
print("sending boundary")
tclShell.SendBoundary()
for line in iterator:
	print(line)
	if (line == tclShell._POC_BOUNDARY):
		break
print("pnmainc.exe is ready...")
print("sending synthesis -f arith_prng.prj")
tclShell.Send("synthesis -f arith_prng.prj\n")
print("sending boundary")
tclShell.SendBoundary()
for line in iterator:
	print(line)
	if (line == tclShell._POC_BOUNDARY):
		break
print("pnmainc.exe is ready...")
print("sending: exit")
tclShell.Send("exit\n")
print("reading output")
for line in iterator:
	print(line)
print("done")
