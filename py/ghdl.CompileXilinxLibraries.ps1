# configure Xilinx folder here
$SIMLIB = "C:\Xilinx\14.7\ISE_DS\ISE\vhdl\src"
$DestinationDirectory = "Xilinx"

# ---------------------------------------------
# save working directory
$WorkingDir = Get-Location

# define global GHDL options
$OPTIONS = ("-a", "-fexplicit", "-frelaxed-rules", "--warn-binding", "--no-vital-checks", "--mb-comments", "--ieee=synopsys", "--std=93c")

# create "Xilinx" directory and change to it
mkdir $DestinationDirectory
cd $DestinationDirectory

$Files = (
	"$SIMLIB\unisims\unisim_VPKG.vhd",
	"$SIMLIB\unisims\unisim_VCOMP.vhd")
& ghdl.exe $OPTIONS --work=unisim $Files

dir "$SIMLIB\unisims\primitive\*.vhd*" | foreach {
	Write-Host "Analysing primitive '$_.FullName' ..." -ForegroundColor Cyan
	& ghdl.exe $OPTIONS --work=unisim $_.FullName
}

Write-Host "--------------------------------------------------------------------------------"
Write-Host "Analyze complete" -ForegroundColor Green

# restore working directory
cd $WorkingDir