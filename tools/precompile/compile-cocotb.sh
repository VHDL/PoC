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
#											Chair for VLSI-Design, Diagnostics and Architecture
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
PoC_sh=$PoCRootDir/poc.sh

# source shared file from precompile directory
source $ScriptDir/shared.sh


# command line argument processing
NO_COMMAND=1
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
	echo "  compile-altera.sh [-c] [--help|--all|--ghdl|--vsim]"
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
	# echo "Options:"
	# echo "     --vhdl93           Compile for VHDL-93."
	# echo "     --vhdl2008         Compile for VHDL-2008."
	# echo ""
	exit 0
fi


if [ "$COMPILE_ALL" == "TRUE" ]; then
	COMPILE_FOR_GHDL=TRUE
	COMPILE_FOR_VSIM=TRUE
fi
# if [ \( $VHDL93 -eq 0 \) -a \( $VHDL2008 -eq 0 \) ]; then
	# VHDL93=1
	# VHDL2008=1
# fi

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
	DestDir=$PoCRootDir/$PrecompiledDir/$VSimDirName/cocotb
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir
	
	# clean osvvm directory
	if [ -d $DestDir/osvvm ]; then
		echo -e "${YELLOW}Cleaning library 'osvvm' ...${ANSI_NOCOLOR}"
		rm -rf osvvm
	fi
	
	# Cocotb paths and settings
	COCOTB_BuildDir=$DestDir/build
	COCOTB_ObjDir=$COCOTB_BuildDir/obj
	COCOTB_SharedDir=$COCOTB_BuildDir/libs
	
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
	CC_LIBRARY_SEARCH_DIR=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES=
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/cocotb_utils.o $COCOTB_SourceDir/utils/cocotb_utils.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libcocotbutils.so $COCOTB_ObjDir/cocotb_utils.o


	echo -e "${ANSI_YELLOW}Compiling 'libcocotbutils.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES -DFILTER"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	CC_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDE_SEARCH_DIR   -o $COCOTB_ObjDir/gpi_logging.o $COCOTB_SourceDir/gpi_log/gpi_logging.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libgpilog.so $COCOTB_ObjDir/gpi_logging.o


	echo -e "${ANSI_YELLOW}Compiling 'libcocotb.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir/gpi_embed.o $COCOTB_SourceDir/embed/gpi_embed.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libcocotb.so $COCOTB_ObjDir/gpi_embed.o


	echo -e "${ANSI_YELLOW}Compiling 'libgpi.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING -DLIB_EXT=so -DSINGLETON_HANDLES"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES="-lcocotbutils -lgpilog -lcocotb -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_SourceDir/gpi/GpiCbHdl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/GpiCommon.o $COCOTB_SourceDir/gpi/GpiCommon.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libgpi.so $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_ObjDir/GpiCommon.o


	echo -e "${ANSI_YELLOW}Compiling 'libsim.so'...${ANSI_NOCOLOR}"
	CC_DEFINES="$CC_DEFINES $PYTHON_DEFINES"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
	$CC  -c      $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_DEFINES $CC_INCLUDES             -o $COCOTB_ObjDir/simulatormodule.o $COCOTB_SourceDir/simulator/simulatormodule.c
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CC_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libsim.so $COCOTB_ObjDir/simulatormodule.o

	ln -sf $COCOTB_SharedDir/libsim.so $COCOTB_SharedDir/simulator.so

	echo -e "${ANSI_YELLOW}Compiling 'libvpi.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DVPI_CHECKING"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES="-lgpi -lgpilog -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/VpiImpl.o $COCOTB_SourceDir/vpi/VpiImpl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/VpiCbHdl.o $COCOTB_SourceDir/vpi/VpiCbHdl.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libvpi.so $COCOTB_ObjDir/VpiImpl.o $COCOTB_ObjDir/VpiCbHdl.o


	echo -e "${ANSI_YELLOW}Compiling 'libfli.so'...${ANSI_NOCOLOR}"
	CXX_DEFINES="$CC_DEFINES -DFLI_CHECKING -DUSE_CACHE"
	CXX_WARNINGS="$CXX_WARNINGS"
	CXX_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $VSIM_INCLUDE_SEARCH_DIR"
	CC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
	CC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
	CC_LIBRARIES="-lgpi -lgpilog -lstdc++"
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliImpl.o $COCOTB_SourceDir/fli/FliImpl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_SourceDir/fli/FliCbHdl.cpp
	$CXX -c      $CXX_DEBUG $CXX_WARNINGS $CXX_FLAGS $CXX_DEFINES $CXX_INCLUDES         -o $COCOTB_ObjDir/FliObjHdl.o $COCOTB_SourceDir/fli/FliObjHdl.cpp
	$LD  -shared $CC_DEBUG $CC_WARNINGS $CXX_FLAGS $CC_LIBRARY_SEARCH_DIR $CC_LIBRARIES -o $COCOTB_SharedDir/libfli.so $COCOTB_ObjDir/FliImpl.o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_ObjDir/FliObjHdl.o

	
	cd $WorkingDir
fi

