#! /usr/bin/env bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;

CocotbLibDir=lib/cocotb
#
# ---------------------------------------------
# work around for Darwin (Mac OS)
READLINK=readlink; if [[ $(uname) == "Darwin" ]]; then READLINK=greadlink; fi

# save working directory
WorkingDir=$(pwd)
ScriptDir="$(dirname $0)"
ScriptDir="$($READLINK -f $ScriptDir)"

PoCRootDir="$($READLINK -f $ScriptDir/..)"
PoC_sh=$PoCRootDir/poc.sh

# source shared file from precompile directory
source $PoCRootDir/tools/precompile/shared.sh


# command line argument processing
NO_COMMAND=1
PYTHON_VERSION="27"
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-c|--clean)
		CLEAN=TRUE
		;;
		-a|--all)
		COMPILE_ALL=TRUE
		NO_COMMAND=0
		;;
		--ghdl)
		COMPILE_FOR_GHDL=TRUE
		NO_COMMAND=0
		;;
		--questa)
		COMPILE_FOR_VSIM=TRUE
		NO_COMMAND=0
		;;
		-h|--help)
		HELP=TRUE
		NO_COMMAND=0
		;;
		--python)
		PYTHON_VERSION="$2"
		shift						# skip argument
		;;
		*)		# unknown option
		echo 1>&2 -e "${COLORED_ERROR} Unknown command line option '$key'.${ANSI_NOCOLOR}"
		exit -1
		;;
	esac
	shift # past argument or value
done

if [ $NO_COMMAND -eq 1 ]; then
	HELP=TRUE
fi

if [ "$HELP" == "TRUE" ]; then
	test $NO_COMMAND -eq 1 && echo 1>&2 -e "\n${COLORED_ERROR} No command selected.${ANSI_NOCOLOR}"
	echo ""
	echo "Synopsis:"
	echo "  Run PoC.sort.lru_cache as test example for Cocotb"
	echo "  - GHDL"
	echo "  - QuestaSim/ModelSim"
	echo "  on Linux."
	echo ""
	echo "Usage:"
	echo "  simulation.sh [-c] [--help|--all|--ghdl|--vsim] [<Options>]"
	echo ""
	echo "Common commands:"
	echo "  -h --help             Print this help page"
	# echo "  -c --clean            Remove all generated files"
	echo ""
	echo "Tool chain:"
	echo "  -a --all              Compile for all tool chains."
	echo "     --ghdl             Compile for GHDL."
	echo "     --questa           Compile for QuestaSim/ModelSim."
	echo ""
	echo "Options:"
	echo "     --python <Version> Use Python 2.7 or 3.x."
	echo ""
	exit 0
fi


if [ "$COMPILE_ALL" == "TRUE" ]; then
	COMPILE_FOR_GHDL=TRUE
	COMPILE_FOR_VSIM=TRUE
fi
case "py$PYTHON_VERSION" in
	py)		# default Python version
		PY_VERSION="2.7"
		;;
	py27|py2.7)
		PY_VERSION="2.7"
		;;
	py34|py3.4)
		PY_VERSION="3.4m"
		;;
	py35|py3.5)
		PY_VERSION="3.5m"
		;;
	*)		# unsupported Python version
		echo 1>&2 -e "${COLORED_ERROR} Unsupported Python version '$PYTHON_VERSION'.${ANSI_NOCOLOR}"
		exit -1
		;;
esac

# VHDL settings
VHDL_Library="poc"
# VHDL_TopLevel="sort_lru_list"
VHDL_TopLevel="sort_lru_cache"

SourceFiles=(
	"/d/git/PoC/tb/common/my_project.vhdl"
	"/d/git/PoC/tb/common/my_config_GENERIC.vhdl"
	"/d/git/PoC/src/common/utils.vhdl"
	"/d/git/PoC/src/common/config.vhdl"
	"/d/git/PoC/src/common/math.vhdl"
	"/d/git/PoC/src/common/strings.vhdl"
	"/d/git/PoC/src/common/vectors.vhdl"
	"/d/git/PoC/src/common/physical.vhdl"
	"/d/git/PoC/src/common/components.vhdl"
	"/d/git/PoC/src/common/protected.v08.vhdl"
	"/d/git/PoC/src/common/fileio.v08.vhdl"
	"/d/git/PoC/src/arith/arith.pkg.vhdl"
	"/d/git/PoC/src/arith/arith_prefix_and.vhdl"
	"/d/git/PoC/src/sort/$VHDL_TopLevel.vhdl"
)

PrecompiledDir=$($PoC_sh query CONFIG.DirectoryNames:PrecompiledFiles 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} Cannot get precompiled directory.${ANSI_NOCOLOR}"
	echo 1>&2 -e "${ANSI_RED}$PrecompiledDir${ANSI_NOCOLOR}"
	exit -1;
fi

# Get Cocotb installation directory
CocotbInstallDir=$PoCRootDir/$CocotbLibDir
COCOTB_PythonDir=$CocotbInstallDir/cocotb


LD_LIBRARY_PATH=/usr/lib
PYTHON_MODULE=${VHDL_TopLevel}_cocotb

# GHDL
# ==============================================================================
if [ "$COMPILE_FOR_GHDL" == "TRUE" ]; then
	# Get GHDL directories
	# <= $GHDLBinDir
	# <= $GHDLScriptDir
	# <= $GHDLDirName
	GetGHDLDirectories $PoC_sh

	GHDL_PrecompiledDir=$PoCRootDir/$PrecompiledDir/$GHDLDirName
	COCOTB_SharedDir=$GHDL_PrecompiledDir/cocotb

	# Assemble output directory
	DestDir=$PoCRootDir/temp/$GHDLDirName
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir
	
	GHDL_OPTIONS=("-fexplicit" "--work=$VHDL_Library" "--std=08" "-P../precompiled/ghdl/xilinx/")
	# GHDL_OPTIONS=("-fexplicit" "--work=$VHDL_Library" "--std=93c" "-P../precompiled/ghdl/xilinx/")
	
	echo -e "${YELLOW}Analyzing library '$VHDL_Library' with ghdl...${ANSI_NOCOLOR}"
	ERRORCOUNT=0
	for File in ${SourceFiles[@]}; do
		echo "  Analyzing '$File'..."
		$GHDLBinDir/ghdl -a ${GHDL_OPTIONS[@]} $File
		if [ $? -ne 0 ]; then
			let ERRORCOUNT++
		fi
	done
	
	echo "  Elaborating '$VHDL_Library.$VHDL_TopLevel'..."
	$GHDLBinDir/ghdl -e ${GHDL_OPTIONS[@]} $VHDL_TopLevel
	if [ $? -ne 0 ]; then
		let ERRORCOUNT++
	fi

	echo "  Copying Python modules..."
	cp $PoCRootDir/tb/common/*.py .
	cp $PoCRootDir/tb/sort/${VHDL_TopLevel}_cocotb.py .

	GHDL_OPTIONS=("--work=$VHDL_Library" "--std=08" "-P../precompiled/ghdl/xilinx/")
	echo "  Simulating '$VHDL_Library.$VHDL_TopLevel'..."
	export PYTHONPATH=$COCOTB_SharedDir:$CocotbInstallDir:$DestDir
	export LD_LIBRARY_PATH=$COCOTB_SharedDir:$LD_LIBRARY_PATH
	export MODULE=$PYTHON_MODULE
	export TESTCASE=
	export TOPLEVEL=$VHDL_TopLevel
	export TOPLEVEL_LANG=vhdl
	# CMD="$GHDLBinDir/ghdl -r ${GHDL_OPTIONS[@]} $VHDL_TopLevel --vpi=$COCOTB_SharedDir/libvpi.dll"
	CMD="$GHDLBinDir/ghdl -r ${GHDL_OPTIONS[@]} $VHDL_TopLevel --vpi=libvpi.dll"
	#CMD="./$VHDL_TopLevel.exe --vpi=$COCOTB_SharedDir/libvpi.dll"
	echo $CMD
	$CMD
	if [ $? -ne 0 ]; then
		let ERRORCOUNT++
	fi
	
	# print overall result
	echo -n "Simulation "
	if [ $ERRORCOUNT -gt 0 ]; then
		echo -e $COLORED_FAILED
	else
		echo -e $COLORED_SUCCESSFUL
	fi
	
	cd $WorkingDir
fi

# QuestaSim/ModelSim
# ==============================================================================
if [ "$COMPILE_FOR_VSIM" == "TRUE" ]; then
	# Get GHDL directories
	# <= $VSimBinDir
	# <= $VSimDirName
	GetVSimDirectories $PoC_sh

	VSim_PrecompiledDir=$PoCRootDir/$PrecompiledDir/$VSimDirName
	COCOTB_SharedDir=$VSim_PrecompiledDir/cocotb

	# Assemble output directory
	DestDir=$PoCRootDir/temp/$VSimDirName
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir

	# Compile libraries with vcom, executed in destination directory
	echo -e "${YELLOW}Creating library '$VHDL_Library' with vlib...${ANSI_NOCOLOR}"
	$VSimBinDir/vlib $VHDL_Library

	echo -e "${YELLOW}Compiling library '$VHDL_Library' with vcom...${ANSI_NOCOLOR}"
	ERRORCOUNT=0
	for File in ${SourceFiles[@]}; do
		echo "  Compiling '$File'..."
		$VSimBinDir/vcom -2008 -work $VHDL_Library $File
		if [ $? -ne 0 ]; then
			let ERRORCOUNT++
		fi
	done

	echo "  Copying Python modules..."
	cp $PoCRootDir/tb/common/*.py .
	cp $PoCRootDir/tb/sort/${VHDL_TopLevel}_cocotb.py .

	echo "vsim -onfinish exit -foreign \"cocotb_init libfli.so\" $VHDL_Library.$VHDL_TopLevel" > $VHDL_TopLevel.do
	echo "onbreak resume" >> $VHDL_TopLevel.do
	echo "run -all" >> $VHDL_TopLevel.do
	echo "quit" >> $VHDL_TopLevel.do

	echo "  Simulating '$VHDL_Library.$VHDL_TopLevel'..."
	PYTHONPATH=$COCOTB_SharedDir:$CocotbInstallDir:$DestDir LD_LIBRARY_PATH=$COCOTB_SharedDir:$LD_LIBRARY_PATH MODULE=$PYTHON_MODULE TESTCASE= TOPLEVEL=$VHDL_TopLevel TOPLEVEL_LANG=vhdl $VSimBinDir/vsim -c -t 1fs -do $VHDL_TopLevel.do 2>&1
	if [ $? -ne 0 ]; then
		let ERRORCOUNT++
	fi

	# print overall result
	echo -n "Simulation "
	if [ $ERRORCOUNT -gt 0 ]; then
		echo -e $COLORED_FAILED
	else
		echo -e $COLORED_SUCCESSFUL
	fi
	
	cd $WorkingDir
fi



