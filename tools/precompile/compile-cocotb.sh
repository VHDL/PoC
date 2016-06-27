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

ANSI_RED="\e[31m"
ANSI_GREEN="\e[32m"
ANSI_YELLOW="\e[33m"
ANSI_BLUE="\e[34m"
ANSI_MAGENTA="\e[35m"
ANSI_CYAN="\e[36;1m"
ANSI_NOCOLOR="\e[0m"

# red texts
COLORED_ERROR="${ANSI_RED}[ERROR]"
COLORED_MESSAGE="${ANSI_YELLOW}       "
COLORED_FAILED="${ANSI_RED}[FAILED]${ANSI_NOCOLOR}"

# green texts
COLORED_DONE="${ANSI_GREEN}[DONE]${ANSI_NOCOLOR}"
COLORED_SUCCESSFUL="${ANSI_GREEN}[SUCCESSFUL]${ANSI_NOCOLOR}"


# set bash options
set -o pipefail

DEBUG=1
VERBOSE=0


Architecture=x86_64

PoCRootDir=/home/paebbels/git/PoC
COCOTB_RootDir=$PoCRootDir/lib/cocotb
COCOTB_IncludeDir=$COCOTB_RootDir/include
COCOTB_SourceDir=$COCOTB_RootDir/lib

COCOTB_BuildDir=$PoCRootDir/temp/precompiled/cocotb/build
COCOTB_ObjDir=$COCOTB_BuildDir/obj/$Architecture
COCOTB_SharedDir=$COCOTB_BuildDir/libs/$Architecture

mkdir -p $COCOTB_ObjDir
mkdir -p $COCOTB_SharedDir

COCOTB_INCLUDE_SEARCH_DIR="-I$COCOTB_IncludeDir"
COCOTB_LIBRARY_SEARCH_DIR="-L$COCOTB_SharedDir"

System_IncludeDir="/usr/include"
System_Libraries="/usr/lib"
Linux_IncludeDir="$System_IncludeDir/x86_64-linux-gnu"

PY_VERSION="2.7"
PY_LIBRARY="python$PY_VERSION"
PYTHON_DEFINES="-DPYTHON_SO_LIB=lib$PY_LIBRARY.so"
PYTHON_INCLUDE_SEARCH_DIR="-I$System_IncludeDir/$PY_LIBRARY"
PYTHON_LIBRARY_SEARCH_DIR=
PYTHON_LIBRARY="-l$PY_LIBRARY"


VSIM_IncludeDir="/opt/questasim/10.4d/include"

VSIM_INCLUDE_SEARCH_DIR="-I$VSIM_IncludeDir"

CC_WARNINGS="-Werror -Wcast-qual -Wcast-align -Wwrite-strings -Wall -Wno-unused-parameter"
LD_WARNINGS="-Wstrict-prototypes -Waggregate-return"
GCC_DEBUG="-g -DDEBUG"
GCC_DEFINES1="-DMODELSIM"
GCC_FLAGS="-fno-common -fpic"

CPP_WARNINGS=$CC_WARNINGS
GPP_DEBUG=$GCC_DEBUG
GPP_FLAGS=$GCC_FLAGS

LINUX_INCLUDE_SEARCH_DIR="-I$System_IncludeDir -I$Linux_IncludeDir"
LINUX_LIBRARY_SEARCH_DIR="-L$System_Libraries"

CC=/opt/questasim/10.4d/gcc-4.7.4-linux_x86_64/bin/gcc
CXX=/opt/questasim/10.4d/gcc-4.7.4-linux_x86_64/bin/g++
LD=/usr/bin/gcc

echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GCC_DEFINES=$GCC_DEFINES1
GCC_WARNINGS=$CC_WARNINGS
GCC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
GCC_LIBRARY_SEARCH_DIR=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES=
$CC  -c      $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDE_SEARCH_DIR                -o $COCOTB_ObjDir/cocotb_utils.o $COCOTB_SourceDir/utils/cocotb_utils.c
$LD  -shared $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libcocotbutils.so $COCOTB_ObjDir/cocotb_utils.o


echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GCC_DEFINES="$GCC_DEFINES1 -DFILTER"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_INCLUDE_SEARCH_DIR="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
GCC_LIBRARY_SEARCH_DIR="$LINUX_LIBRARY_SEARCH_DIR $COCOTB_LIBRARY_SEARCH_DIR"
GCC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY"
$CC -c      $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDE_SEARCH_DIR                -o $COCOTB_ObjDir/gpi_logging.o $COCOTB_SourceDir/gpi_log/gpi_logging.c
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libgpilog.so $COCOTB_ObjDir/gpi_logging.o


echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GCC_DEFINES="$GCC_DEFINES1 $PYTHON_DEFINES"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
GCC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpilog -lcocotbutils"
$CC -c      $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDES                          -o $COCOTB_ObjDir/gpi_embed.o $COCOTB_SourceDir/embed/gpi_embed.c
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libcocotb.so $COCOTB_ObjDir/gpi_embed.o


echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GPP_DEFINES="$GCC_DEFINES1 -DVPI_CHECKING -DLIB_EXT=so -DSINGLETON_HANDLES"
GPP_WARNINGS="$CPP_WARNINGS"
GPP_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES="-lcocotbutils -lgpilog -lcocotb -lstdc++"
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_SourceDir/gpi/GpiCbHdl.cpp
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/GpiCommon.o $COCOTB_SourceDir/gpi/GpiCommon.cpp
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libgpi.so $COCOTB_ObjDir/GpiCbHdl.o $COCOTB_ObjDir/GpiCommon.o


echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GCC_DEFINES="$GCC_DEFINES1 $PYTHON_DEFINES"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $LINUX_INCLUDE_SEARCH_DIR"
GCC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES="-lpthread -ldl -lutil -lm $PYTHON_LIBRARY -lgpi -lgpilog"
$CC -c $GCC_DEBUG $GCC_WARNINGS $GCC_FLAGS $GCC_DEFINES $GCC_INCLUDES       -o $COCOTB_ObjDir/simulatormodule.o $COCOTB_SourceDir/simulator/simulatormodule.c
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libsim.so $COCOTB_ObjDir/simulatormodule.o

ln -sf $COCOTB_SharedDir/libsim.so $COCOTB_SharedDir/simulator.so

echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GPP_DEFINES="$GCC_DEFINES1 -DVPI_CHECKING"
GPP_WARNINGS="$CPP_WARNINGS"
GPP_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES="-lgpi -lgpilog -lstdc++"
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/VpiImpl.o $COCOTB_SourceDir/vpi/VpiImpl.cpp
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/VpiCbHdl.o $COCOTB_SourceDir/vpi/VpiCbHdl.cpp
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libvpi.so $COCOTB_ObjDir/VpiImpl.o $COCOTB_ObjDir/VpiCbHdl.o


echo -e "${ANSI_CYAN}--------------------${ANSI_NOCOLOR}"
GPP_DEFINES="$GCC_DEFINES1 -DFLI_CHECKING -DUSE_CACHE"
GPP_WARNINGS="$CPP_WARNINGS"
GPP_INCLUDES="$PYTHON_INCLUDE_SEARCH_DIR $COCOTB_INCLUDE_SEARCH_DIR $VSIM_INCLUDE_SEARCH_DIR"
GCC_WARNINGS="$CC_WARNINGS $LD_WARNINGS"
GCC_LIBRARY_DIRS=$LINUX_LIBRARY_SEARCH_DIR
GCC_LIBRARIES="-lgpi -lgpilog -lstdc++"
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/FliImpl.o $COCOTB_SourceDir/fli/FliImpl.cpp
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_SourceDir/fli/FliCbHdl.cpp
$CXX -c      $GPP_DEBUG $GPP_WARNINGS $GPP_FLAGS $GPP_INCLUDES               -o $COCOTB_ObjDir/FliObjHdl.o $COCOTB_SourceDir/fli/FliObjHdl.cpp
$LD -shared $GCC_DEBUG $GCC_WARNINGS $GCC_LIBRARY_SEARCH_DIR $GCC_LIBRARIES -o $COCOTB_SharedDir/libfli.so $COCOTB_ObjDir/FliImpl.o $COCOTB_ObjDir/FliCbHdl.o $COCOTB_ObjDir/FliObjHdl.o






exit

