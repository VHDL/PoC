

$Simulator =					"questa"															# questa, ...
$Language =						"vhdl"																# all, vhdl, verilog
$DestDir =						"D:/git/PoC/temp/QuestaSim"						# Output directory
$SimulatorDir =				"C:/Mentor/QuestaSim64/10.4c/win64"		# Path to the simulators bin directory
$TargetArchitecture =	"all"																	# all, virtex5, virtex6, virtex7, ...


compxlib.exe -s $Simulator -l $Language -dir $DestDir -p $SimulatorDir -arch $TargetArchitecture -lib unisim -lib simprim -lib xilinxcorelib -intstyle ise
