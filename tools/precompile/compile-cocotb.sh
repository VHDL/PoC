#! /usr/bin/env bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:					Patrick Lehmann
#
#	Bash Script:			Compile Cocotb simulation libraries
#
# Description:
# ------------------------------------
#	This bash script compiles Cocotb simulation libraries into a local directory.
#
# License:
# ==============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#											Chair of VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# configure script here
CocotbLibDir=lib/cocotb

# work around for Darwin (Mac OS)
READLINK=readlink; if [[ $(uname) == "Darwin" ]]; then READLINK=greadlink; fi

# Save working directory
WorkingDir=$(pwd)
ScriptDir="$(dirname $0)"
ScriptDir="$($READLINK -f $ScriptDir)"

PoCRootDir="$($READLINK -f $ScriptDir/../..)"
PoCRootDir="/d/git/PoC"
PoC_sh=$PoCRootDir/poc.sh

# source shared file from precompile directory
source $ScriptDir/shared.sh


# command line argument processing
NO_COMMAND=1
PYTHON_VERSION="27"
# VHDL93=0
# VHDL2008=0
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
		# --vhdl93)
		# VHDL93=1
		# ;;
		# --vhdl2008)
		# VHDL2008=1
		# ;;
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
	echo "  Script to compile the Altera Quartus simulation libraries for"
	echo "  - GHDL"
	echo "  - QuestaSim/ModelSim"
	echo "  on Linux."
	echo ""
	echo "Usage:"
	echo "  compile-altera.sh [-c] [--help|--all|--ghdl|--questa] [<Options>]"
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

uname="$(uname -s)"
case $uname in
	*MINGW32*)	MinGW="mingw32";	LIBEXT=".dll";;
	*MINGW64*)	MinGW="mingw64";	LIBEXT=".dll";;
	*Linux*)											LIBEXT=".so";;
	*)		# unsupported Python version
		echo 1>&2 -e "${COLORED_ERROR} Unsupported platform version '$uname'.${ANSI_NOCOLOR}"
		exit -1
		;;
esac

PrecompiledDir=$($PoC_sh query CONFIG.DirectoryNames:PrecompiledFiles 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} Cannot get precompiled directory.${ANSI_NOCOLOR}"
	echo 1>&2 -e "${ANSI_RED}$PrecompiledDir${ANSI_NOCOLOR}"
	exit -1;
fi

# Get Cocotb installation directory
CocotbInstallDir=$PoCRootDir/$CocotbLibDir

COCOTB_IncludeDir=$CocotbInstallDir/include
COCOTB_SourceDir=$CocotbInstallDir/lib

# GHDL
# ==============================================================================
if [ "$COMPILE_FOR_GHDL" == "TRUE" ]; then
	# Get GHDL directories
	# <= $GHDLBinDir
	# <= $GHDLScriptDir
	# <= $GHDLDirName
	GetGHDLDirectories $PoC_sh

	# Assemble output directory
	DestDir=$PoCRootDir/$PrecompiledDir/$GHDLDirName
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir

	# clean cocotb directory
	if [ -d $DestDir/cocotb ]; then
		echo -e "${ANSI_YELLOW}Cleaning library 'cocotb' ...${ANSI_NOCOLOR}"
		rm -rf cocotb
	fi

	# Cocotb paths and settings
	COCOTB_BuildDir=$DestDir/cocotb
	COCOTB_ObjDir=$COCOTB_BuildDir
	COCOTB_SharedDir=$COCOTB_BuildDir

	mkdir -p $COCOTB_ObjDir
	mkdir -p $COCOTB_SharedDir

	COCOTB_INCLUDE_SEARCH_DIR="-I$COCOTB_IncludeDir"
	COCOTB_LIBRARY_SEARCH_DIR="-L$COCOTB_SharedDir"

	# System and Linux paths and settings
	System_IncludeDir="/usr/include"
	System_IncludeDir2="/c/msys64/$MinGW/include"
	# System_Executables="/usr/bin"
	# System_Executables2="/c/msys64/mingw32/bin"
	System_Executables2="/c/msys64/$MinGW/bin"
	System_Libraries="/usr/lib"
	System_Libraries2="/c/msys64/$MinGW/lib"

	LINUX_INCLUDE_SEARCH_DIR="-I$System_IncludeDir2 -I$System_IncludeDir"
	LINUX_LIBRARY_SEARCH_DIR="-L$System_Libraries2 -L$System_Libraries"

	# Python paths and settings
	PY_LIBRARY="python$PY_VERSION"
	PYTHON_DEFINES="-DPYTHON_SO_LIB=lib$PY_LIBRARY$LIBEXT"
	PYTHON_INCLUDE_SEARCH_DIR="-I$System_IncludeDir2/$PY_LIBRARY"
	PYTHON_LIBRARY_SEARCH_DIR=
	PYTHON_LIBRARY="-l$PY_LIBRARY"

	GHDL_LIBRARY_SEARCH_DIR="-L/c/Tools/GHDL/0.34dev-mingw32-llvm/lib/ghdl"
	GHDL_LIBRARY="-lgrt"

	# Common CC and LD variables
	CC_WARNINGS="-Wcast-qual -Wcast-align -Wwrite-strings -Wall -Wno-unused-parameter"  # -Werror
	LD_WARNINGS="-Wstrict-prototypes -Waggregate-return"
	CC_DEBUG="-g -DDEBUG"
	CC_DEFINES=""	# -DMODELSIM
	CC_FLAGS="-fno-common"   # -fpic not supported in MinGW

	CXX_WARNINGS=$CC_WARNINGS
	CXX_DEBUG=$CC_DEBUG
	CXX_FLAGS=$CC_FLAGS

	# Configure executables
	CC="gcc"
	CXX="g++"
	LD="gcc"

  echo -e "${ANSI_YELLOW}Compiling 'libcocotbutils$LIBEXT'...${ANSI_NOCOLOR}"
	CC_DEFINES=$CC_DEFINES
	CC_WARNINGS=$CC_WARNINGS
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES=
	CMD="$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/cocotb_utils.o $COCOTB_SourceDir/utils/cocotb_utils.c"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	CMD="$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES -o $COCOTB_SharedDir/libcocotbutils$LIBEXT $COCOTB_ObjDir/cocotb_utils.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	echo -e "${ANSI_YELLOW}Compiling 'libgpilog$LIBEXT'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES -DFILTER"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"	# $LINUX_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
	CMD="$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/gpi_logging.o $COCOTB_SourceDir/gpi_log/gpi_logging.c"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	CMD="$LD -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES -o $COCOTB_SharedDir/libgpilog$LIBEXT $COCOTB_ObjDir/gpi_logging.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	echo -e "${ANSI_YELLOW}Compiling 'libcocotb$LIBEXT'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"	# $LINUX_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
	CMD="$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR             -o $COCOTB_ObjDir/gpi_embed.o $COCOTB_SourceDir/embed/gpi_embed.c"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	CMD="$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES -o $COCOTB_SharedDir/libcocotb$LIBEXT $COCOTB_ObjDir/gpi_embed.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	echo -e "${ANSI_YELLOW}Compiling 'libgpi$LIBEXT'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING -DLIB_EXT=so -DSINGLETON_HANDLES"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	LD_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lcocotbutils -lgpilog -lcocotb -lstdc++"
	CMD="$CXX -c $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDE_SEARCH_DIR -o $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_SourceDir/gpi/GpiCbHdl.cpp"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	CMD="$CXX -c $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDE_SEARCH_DIR -o $COCOTB_ObjDir/GpiCommon.o $COCOTB_SourceDir/gpi/GpiCommon.cpp"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	CMD="$LD -shared $CC_DEBUG $LD_LINKER_ARGS $LD_WARNINGS                               -o $COCOTB_SharedDir/libgpi$LIBEXT $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_ObjDir/GpiCommon.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	echo -e "${ANSI_YELLOW}Compiling 'libsim$LIBEXT'...${ANSI_NOCOLOR}"
	GCC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	GCC_WARNINGS="$CC_WARNINGS"
	GCC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
	# ---- simulatormodule.o ----
	CMD="$CC  -c $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDES           -o $COCOTB_ObjDir/simulatormodule.o $COCOTB_SourceDir/simulator/simulatormodule.c"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	# ---- libsim.dll ----
	CMD="$LD  -shared $CC_DEBUG $LD_LINKER_ARGS $LD_WARNINGS                              -o $COCOTB_SharedDir/libsim$LIBEXT $COCOTB_ObjDir/simulatormodule.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi

	echo -e "${ANSI_YELLOW}Copying 'libghdlvpi$LIBEXT'...${ANSI_NOCOLOR}"
	cp $COCOTB_SharedDir/../libghdlvpi.dll $COCOTB_SharedDir

	# echo -e "${ANSI_YELLOW}Compiling 'libghdl$LIBEXT'...${ANSI_NOCOLOR}"
	# GCC_DEFINES=
	# GCC_WARNINGS=
	# GCC_INCLUDES=
	# LD_LIBRARY_SEARCH_DIR=
	# LD_LIBRARIES=
	# # ---- libghdl.o ----
	# CMD="$CC  -c $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDES           -o $COCOTB_ObjDir/ghdl.o $COCOTB_SourceDir/ghdl/ghdl.c"
	# echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	# $CMD
	# if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	# # ---- libsim.dll ----
	# CMD="$LD  -shared $CC_DEBUG $LD_LINKER_ARGS $LD_WARNINGS                              -o $COCOTB_SharedDir/libghdl$LIBEXT $COCOTB_ObjDir/ghdl.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	# echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	# $CMD
	# if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	echo -e "${ANSI_YELLOW}Creating symlink 'simulator$LIBEXT'...${ANSI_NOCOLOR}"
	# ln -sf $COCOTB_SharedDir/libsim$LIBEXT $COCOTB_SharedDir/simulator$LIBEXT


	echo -e "${ANSI_YELLOW}Compiling 'libvpi$LIBEXT'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING"
	CXX_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	LD_LINKER_ARGS="-Wl,--no-undefined -Wl,--enable-auto-import -Wl,--enable-runtime-pseudo-reloc-v2"
	LD_LIBRARY_SEARCH_DIR="$COCOTB_LIBRARY_SEARCH_DIR"	#$GHDL_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lghdlvpi -lgpi -lstdc++ -lgpilog"	#$GHDL_LIBRARY"
	# ---- VpiImpl.o ----
	CMD="$CXX -c $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDE_SEARCH_DIR -o $COCOTB_ObjDir/VpiImpl.o $COCOTB_SourceDir/vpi/VpiImpl.cpp"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	# ---- VpiCbHdl.o ----
	CMD="$CXX -c $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDE_SEARCH_DIR -o $COCOTB_ObjDir/VpiCbHdl.o $COCOTB_SourceDir/vpi/VpiCbHdl.cpp"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While compiling.${ANSI_NOCOLOR}";	exit -1;	fi
	# ---- libvpi.dll ----
	# CMD="$LD -r -nostdlib $CC_DEBUG $LD_LINKER_ARGS $LD_WARNINGS                                 -o $COCOTB_SharedDir/libvpi$LIBEXT $COCOTB_ObjDir/VpiImpl.o $COCOTB_ObjDir/VpiCbHdl.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	CMD="$LD -shared $CC_DEBUG $LD_LINKER_ARGS $LD_WARNINGS                                 -o $COCOTB_SharedDir/libvpi$LIBEXT $COCOTB_ObjDir/VpiImpl.o $COCOTB_ObjDir/VpiCbHdl.o $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES"
	echo -e "${ANSI_DARKCYAN}$CMD${ANSI_NOCOLOR}"
	$CMD
	if [ $? -ne 0 ]; then	echo 1>&2 -e "${ANSI_RED}[ERROR]: While linking.${ANSI_NOCOLOR}";	exit -1;	fi


	cd $COCOTB_SharedDir

	echo -e "${ANSI_YELLOW}Removing object files...${ANSI_NOCOLOR}"
	rm *.o

	export PYTHONHOME=/c/Tools/Python2.7.12
	export PYTHONPATH=$PYTHONHOME/lib:/d/git/PoC/lib/cocotb/cocotb:/d/git/PoC/temp/precompiled/ghdl/cocotb

	/c/Tools/GHDL/0.34dev-mingw32-mcode/bin/ghdl.exe -a ../test.vhdl
	/c/Tools/GHDL/0.34dev-mingw32-mcode/bin/ghdl.exe -e test
	/c/Tools/GHDL/0.34dev-mingw32-mcode/bin/ghdl.exe -r test --vpi=libvpi.dll

	export PYTHONHOME=
	export PYTHONPATH=


	cd $WorkingDir
fi

# QuestaSim/ModelSim
# ==============================================================================
if [ "$COMPILE_FOR_VSIM" == "TRUE" ]; then
	# Get GHDL directories
	# <= $VSimBinDir
	# <= $VSimDirName
	GetVSimDirectories $PoC_sh

	# Assemble output directory
	DestDir=$PoCRootDir/$PrecompiledDir/$VSimDirName
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir

	# clean cocotb directory
	if [ -d $DestDir/cocotb ]; then
		echo -e "${YELLOW}Cleaning library 'osvvm' ...${ANSI_NOCOLOR}"
		rm -rf cocotb
	fi

	# Cocotb paths and settings
	COCOTB_BuildDir=$DestDir/cocotb
	COCOTB_ObjDir=$COCOTB_BuildDir
	COCOTB_SharedDir=$COCOTB_BuildDir

	mkdir -p $COCOTB_ObjDir
	mkdir -p $COCOTB_SharedDir

	COCOTB_INCLUDE_SEARCH_DIR="-I$COCOTB_IncludeDir"
	COCOTB_LIBRARY_SEARCH_DIR="-L$COCOTB_SharedDir"

	# System and Linux paths and settings
	System_IncludeDir="/usr/include"
	System_Executables="/usr/bin"
	System_Libraries="/usr/lib"
	Linux_IncludeDir="$System_IncludeDir/x86_64-linux-gnu"

	LINUX_INCLUDE_SEARCH_DIR="-I$System_IncludeDir -I$Linux_IncludeDir"
	LINUX_LIBRARY_SEARCH_DIR="-L$System_Libraries"

	# Python paths and settings
	PY_VERSION="2.7"
	PY_LIBRARY="python$PY_VERSION"
	PYTHON_DEFINES="-DPYTHON_SO_LIB=lib$PY_LIBRARY.so"
	PYTHON_INCLUDE_SEARCH_DIR="-I$System_IncludeDir/$PY_LIBRARY"
	PYTHON_LIBRARY_SEARCH_DIR=
	PYTHON_LIBRARY="-l$PY_LIBRARY"

	# QuestaSim/ModelSim paths and settings
	VSIM_IncludeDir="$VSimBinDir/../include"

	VSIM_INCLUDE_SEARCH_DIR="-I$VSIM_IncludeDir"

	# Common CC and LD variables
	CC_WARNINGS="-Werror -Wcast-qual -Wcast-align -Wwrite-strings -Wall -Wno-unused-parameter"
	LD_WARNINGS="-Wstrict-prototypes -Waggregate-return"
	CC_DEBUG="-g -DDEBUG"
	CC_DEFINES="-DMODELSIM"
	CC_FLAGS="-fno-common -fpic"

	CXX_WARNINGS=$CC_WARNINGS
	CXX_DEBUG=$CC_DEBUG
	CXX_FLAGS=$CC_FLAGS

	# Configure executables
	CC="$VSimBinDir/../gcc-4.7.4-linux_x86_64/bin/gcc"
	CXX="$VSimBinDir/../gcc-4.7.4-linux_x86_64/bin/g++"
	LD="$System_Executables/gcc"

  echo -e "${ANSI_YELLOW}Compiling 'libcocotbutils.so'...${ANSI_NOCOLOR}"
	CC_DEFINES=$CC_DEFINES
	CC_WARNINGS=$CC_WARNINGS
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES=
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/cocotb_utils.o $COCOTB_SourceDir/utils/cocotb_utils.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libcocotbutils.so $COCOTB_ObjDir/cocotb_utils.o


	echo -e "${ANSI_YELLOW}Compiling 'libcocotbutils.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES -DFILTER"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/gpi_logging.o $COCOTB_SourceDir/gpi_log/gpi_logging.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libgpilog.so $COCOTB_ObjDir/gpi_logging.o


	echo -e "${ANSI_YELLOW}Compiling 'libcocotb.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir/gpi_embed.o $COCOTB_SourceDir/embed/gpi_embed.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libcocotb.so $COCOTB_ObjDir/gpi_embed.o


	echo -e "${ANSI_YELLOW}Compiling 'libgpi.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING -DLIB_EXT=so -DSINGLETON_HANDLES"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	LD_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES="-lcocotbutils -lgpilog -lcocotb -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_SourceDir/gpi/GpiCbHdl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/GpiCommon.o $COCOTB_SourceDir/gpi/GpiCommon.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libgpi.so $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_ObjDir/GpiCommon.o


	echo -e "${ANSI_YELLOW}Compiling 'libsim.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	LD_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir/simulatormodule.o $COCOTB_SourceDir/simulator/simulatormodule.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libsim.so $COCOTB_ObjDir/simulatormodule.o


	echo -e "${ANSI_YELLOW}Creating symlink 'simulator.so'...${ANSI_NOCOLOR}"
	ln -sf $COCOTB_SharedDir/libsim.so $COCOTB_SharedDir/simulator.so


	echo -e "${ANSI_YELLOW}Compiling 'libvpi.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	LD_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES="-lgpi -lgpilog -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/VpiImpl.o $COCOTB_SourceDir/vpi/VpiImpl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/VpiCbHdl.o $COCOTB_SourceDir/vpi/VpiCbHdl.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libvpi.so $COCOTB_ObjDir/VpiImpl.o $COCOTB_ObjDir/VpiCbHdl.o


	echo -e "${ANSI_YELLOW}Compiling 'libfli.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DFLI_CHECKING -DUSE_CACHE"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $VSIM_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	LD_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	LD_LIBRARIES="-lgpi -lgpilog -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliImpl.o $COCOTB_SourceDir/fli/FliImpl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_SourceDir/fli/FliCbHdl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliObjHdl.o $COCOTB_SourceDir/fli/FliObjHdl.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $LD_LIBRARY_SEARCH_DIR $LD_LIBRARIES -o $COCOTB_SharedDir/libfli.so $COCOTB_ObjDir/FliImpl.o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_ObjDir/FliObjHdl.o


	echo -e "${ANSI_YELLOW}Removing object files...${ANSI_NOCOLOR}"
	rm cocotb/*.o

	cd $WorkingDir
fi

