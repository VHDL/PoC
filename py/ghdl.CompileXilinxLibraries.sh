# configure Xilinx folder here
SIMLIB="/opt/Xilinx/14.7/ISE_DS/ISE/vhdl/src"
DestinationDirectory="Xilinx"

# define color escape codes
# ---------------------------------------------
RED='\e[0;31m'			# Red
GREEN='\e[1;32m'		# Green
YELLOW='\e[1;33m'		# Yellow
CYAN='\e[1;36m'			# Cyan
NOCOLOR='\e[0m'			# No Color

# save working directory
WorkingDir=$(pwd)

# define global GHDL options
OPTIONS=("-a" "-fexplicit" "-frelaxed-rules" "--warn-binding" "--no-vital-checks" "--mb-comments" "--ieee=synopsys" "--std=93c")

# create "Xilinx" directory and change to it
mkdir $DestinationDirectory
cd $DestinationDirectory

echo "$($CYAN)Analysing packages ...$($NOCOLOR)"
Files=("$SIMLIB/unisims/unisim_VPKG.vhd" "$SIMLIB/unisims/unisim_VCOMP.vhd")
ghdl $OPTIONS --work=unisim $Files

dir "$SIMLIB/unisims/primitive/*.vhd*" | foreach {
do
	echo "$($CYAN)Analysing primitive '$FullName' ...$($NOCOLOR)"
	ghdl.exe $OPTIONS --work=unisim $FullName
done

echo "--------------------------------------------------------------------------------"
echo "$($GREEN)Analyze complete$($NOCOLOR)"

# restore working directory
cd $WorkingDir