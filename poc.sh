#! /usr/bin/env bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:				 	Patrick Lehmann
#                   Martin Zabel
#                   Gustavo Martin
#
#	Bash Script:			OSVVM-based simulation script for PoC
#
# Description:
# ------------------------------------
#	This script builds and simulates PoC using OSVVM build system.
#	It supports GHDL and NVC simulators.
#
# License:
# ==============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# work around for Darwin (Mac OS)
READLINK=readlink; if [[ $(uname) == "Darwin" ]]; then READLINK=greadlink; fi

# resolve script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$($READLINK "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Default values
SIMULATOR="ghdl"
GHDL_BACKEND="llvm"
TEMP_DIR="temp"
VENDOR="GENERIC"
ACTION="help"

# Function to display help
show_help() {
	echo -e "${CYAN}PoC OSVVM-based Build and Simulation Script${NC}"
	echo ""
	echo "Usage: $0 [OPTIONS] COMMAND"
	echo ""
	echo "Commands:"
	echo "  build-osvvm       Build OSVVM libraries"
	echo "  build-poc         Build PoC libraries"
	echo "  simulate          Run all testbenches"
	echo "  regression        Run complete regression (build-osvvm + build-poc + simulate)"
	echo "  clean             Remove temporary directory"
	echo "  help              Show this help message"
	echo ""
	echo "Options:"
	echo "  --simulator=<sim> Specify simulator: ghdl (default) or nvc"
	echo "  --backend=<be>    GHDL backend: llvm (default), gcc, or mcode"
	echo "  --vendor=<v>      Target vendor: GENERIC (default), Xilinx, Altera, etc."
	echo "  --temp=<dir>      Temporary directory (default: temp)"
	echo ""
	echo "Examples:"
	echo "  $0 build-osvvm                    # Build OSVVM with GHDL"
	echo "  $0 build-poc                      # Build PoC libraries"
	echo "  $0 simulate                       # Run all tests"
	echo "  $0 regression                     # Run complete regression"
	echo "  $0 --simulator=nvc build-osvvm    # Build OSVVM with NVC"
	echo "  $0 clean                          # Clean temporary files"
	echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
		--simulator=*)
			SIMULATOR="${1#*=}"
			shift
			;;
		--backend=*)
			GHDL_BACKEND="${1#*=}"
			shift
			;;
		--vendor=*)
			VENDOR="${1#*=}"
			shift
			;;
		--temp=*)
			TEMP_DIR="${1#*=}"
			shift
			;;
		build-osvvm|build-poc|simulate|regression|clean|help)
			ACTION="$1"
			shift
			;;
		*)
			echo -e "${RED}Unknown option: $1${NC}"
			show_help
			exit 1
			;;
	esac
done

# Show help if requested
if [ "$ACTION" = "help" ]; then
	show_help
	exit 0
fi

# Validate simulator
if [[ "$SIMULATOR" != "ghdl" && "$SIMULATOR" != "nvc" ]]; then
	echo -e "${RED}Error: Unsupported simulator '$SIMULATOR'${NC}"
	echo "Supported simulators: ghdl, nvc"
	exit 1
fi

# Set up simulator-specific variables
if [ "$SIMULATOR" = "ghdl" ]; then
	START_SCRIPT="StartGHDL.tcl"
	TEMP_SUBDIR="${TEMP_DIR}/${SIMULATOR}-${GHDL_BACKEND}"
	SIM_COMMAND="tclsh"
elif [ "$SIMULATOR" = "nvc" ]; then
	START_SCRIPT="StartNVC.tcl"
	TEMP_SUBDIR="${TEMP_DIR}/${SIMULATOR}"
	SIM_COMMAND="nvc --do"
fi

# Check if simulator is installed
if [ "$SIMULATOR" = "ghdl" ]; then
	if ! command -v ghdl &> /dev/null; then
		echo -e "${RED}Error: GHDL not found. Please install GHDL.${NC}"
		exit 1
	fi
elif [ "$SIMULATOR" = "nvc" ]; then
	if ! command -v nvc &> /dev/null; then
		echo -e "${RED}Error: NVC not found. Please install NVC.${NC}"
		exit 1
	fi
fi

# Check if tclsh is installed
if ! command -v tclsh &> /dev/null; then
	echo -e "${RED}Error: tclsh not found. Please install tcl (tcllib package).${NC}"
	exit 1
fi

# Clean command
if [ "$ACTION" = "clean" ]; then
	echo -e "${YELLOW}Cleaning temporary directory: ${TEMP_DIR}${NC}"
	rm -rf "$SCRIPT_DIR/$TEMP_DIR"
	echo -e "${GREEN}Done!${NC}"
	exit 0
fi

# Create temporary directory
mkdir -p "$SCRIPT_DIR/$TEMP_SUBDIR"
cd "$SCRIPT_DIR/$TEMP_SUBDIR" || exit 1

# Build OSVVM
if [ "$ACTION" = "build-osvvm" ]; then
	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Building OSVVM libraries with $SIMULATOR${NC}"
	echo -e "${CYAN}========================================${NC}"
	
	# Get absolute paths
	LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
	
	# Create TCL script that changes to lib directory before building
	cat > run_osvvm.tcl <<EOF
source $LIB_DIR/OSVVM-Scripts/$START_SCRIPT
set CurrentWorkingDirectory $LIB_DIR
build $LIB_DIR/OsvvmLibraries.pro OsvvmLibraries
EOF
	
	# Run the build
	if [ "$SIMULATOR" = "ghdl" ]; then
		tclsh run_osvvm.tcl
	else
		nvc --do run_osvvm.tcl
	fi
	
	EXIT_CODE=$?
	if [ $EXIT_CODE -eq 0 ]; then
		echo -e "${GREEN}OSVVM build completed successfully!${NC}"
	else
		echo -e "${RED}OSVVM build failed with exit code $EXIT_CODE${NC}"
		exit $EXIT_CODE
	fi
fi

# Build PoC
if [ "$ACTION" = "build-poc" ]; then
	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Building PoC libraries with $SIMULATOR${NC}"
	echo -e "${CYAN}========================================${NC}"
	
	# Ensure my_project.vhdl exists
	if [ ! -f "$SCRIPT_DIR/tb/common/my_project.vhdl" ]; then
		if [ -f "$SCRIPT_DIR/src/common/my_project.vhdl.template" ]; then
			echo -e "${YELLOW}Creating my_project.vhdl from template...${NC}"
			cp "$SCRIPT_DIR/src/common/my_project.vhdl.template" "$SCRIPT_DIR/tb/common/my_project.vhdl"
		else
			echo -e "${RED}Error: my_project.vhdl not found and template missing${NC}"
			exit 1
		fi
	fi
	
	# Get absolute paths
	LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
	SRC_DIR="$(cd "$SCRIPT_DIR/src" && pwd)"
	TB_DIR="$(cd "$SCRIPT_DIR/tb" && pwd)"
	
	# Create TCL script
	cat > run_poc.tcl <<EOF
source $LIB_DIR/OSVVM-Scripts/$START_SCRIPT

namespace eval ::poc {
  variable myConfigFile  "$TB_DIR/common/my_config_${VENDOR}.vhdl"
  variable myProjectFile "$TB_DIR/common/my_project.vhdl"
  variable vendor        "${VENDOR}"
}

if {\$::osvvm::ToolName eq "GHDL"} {
  SetExtendedAnalyzeOptions {-frelaxed -Wno-specs -Wno-elaboration}
}
if {\$::osvvm::ToolName eq "NVC"} {
  SetExtendedAnalyzeOptions {--relaxed}
}

build $SRC_DIR/PoC.pro PoC
EOF
	
	# Run the build
	if [ "$SIMULATOR" = "ghdl" ]; then
		tclsh run_poc.tcl
	else
		nvc --do run_poc.tcl
	fi
	
	EXIT_CODE=$?
	if [ $EXIT_CODE -eq 0 ]; then
		echo -e "${GREEN}PoC build completed successfully!${NC}"
	else
		echo -e "${RED}PoC build failed with exit code $EXIT_CODE${NC}"
		exit $EXIT_CODE
	fi
fi

# Simulate
if [ "$ACTION" = "simulate" ]; then
	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Running PoC simulations with $SIMULATOR${NC}"
	echo -e "${CYAN}========================================${NC}"
	
	# Ensure my_project.vhdl exists
	if [ ! -f "$SCRIPT_DIR/tb/common/my_project.vhdl" ]; then
		if [ -f "$SCRIPT_DIR/src/common/my_project.vhdl.template" ]; then
			echo -e "${YELLOW}Creating my_project.vhdl from template...${NC}"
			cp "$SCRIPT_DIR/src/common/my_project.vhdl.template" "$SCRIPT_DIR/tb/common/my_project.vhdl"
		else
			echo -e "${RED}Error: my_project.vhdl not found and template missing${NC}"
			exit 1
		fi
	fi
	
	# Get absolute paths
	LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
	TB_DIR="$(cd "$SCRIPT_DIR/tb" && pwd)"
	
	# Create TCL script
	cat > run_simulate.tcl <<EOF
source $LIB_DIR/OSVVM-Scripts/$START_SCRIPT

namespace eval ::poc {
  variable myConfigFile  "$TB_DIR/common/my_config_${VENDOR}.vhdl"
  variable myProjectFile "$TB_DIR/common/my_project.vhdl"
  variable vendor        "${VENDOR}"
}

if {\$::osvvm::ToolName eq "GHDL"} {
  SetExtendedSimulateOptions {-frelaxed -Wno-specs -Wno-binding}
}
if {\$::osvvm::ToolName eq "NVC"} {
}

build $TB_DIR/RunAllTests.pro
EOF
	
	# Run the simulation
	if [ "$SIMULATOR" = "ghdl" ]; then
		tclsh run_simulate.tcl
	else
		nvc --do run_simulate.tcl
	fi
	
	EXIT_CODE=$?
	if [ $EXIT_CODE -eq 0 ]; then
		echo -e "${GREEN}Simulations completed successfully!${NC}"
		echo -e "${CYAN}Reports are available in: ${TEMP_SUBDIR}/reports${NC}"
	else
		echo -e "${RED}Simulations failed with exit code $EXIT_CODE${NC}"
		exit $EXIT_CODE
	fi
fi

# Regression - run complete workflow
if [ "$ACTION" = "regression" ]; then
	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Running complete regression workflow${NC}"
	echo -e "${CYAN}========================================${NC}"
	echo ""
	
	# Get absolute path to this script
	SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"
	
	# Step 1: Build OSVVM
	echo -e "${YELLOW}Step 1/3: Building OSVVM libraries...${NC}"
	bash "$SCRIPT_PATH" --simulator="$SIMULATOR" --backend="$GHDL_BACKEND" --vendor="$VENDOR" --temp="$TEMP_DIR" build-osvvm
	if [ $? -ne 0 ]; then
		echo -e "${RED}Regression failed at build-osvvm step${NC}"
		exit 1
	fi
	echo ""
	
	# Step 2: Build PoC
	echo -e "${YELLOW}Step 2/3: Building PoC libraries...${NC}"
	bash "$SCRIPT_PATH" --simulator="$SIMULATOR" --backend="$GHDL_BACKEND" --vendor="$VENDOR" --temp="$TEMP_DIR" build-poc
	if [ $? -ne 0 ]; then
		echo -e "${RED}Regression failed at build-poc step${NC}"
		exit 1
	fi
	echo ""
	
	# Step 3: Run simulations
	echo -e "${YELLOW}Step 3/3: Running simulations...${NC}"
	bash "$SCRIPT_PATH" --simulator="$SIMULATOR" --backend="$GHDL_BACKEND" --vendor="$VENDOR" --temp="$TEMP_DIR" simulate
	if [ $? -ne 0 ]; then
		echo -e "${RED}Regression failed at simulate step${NC}"
		exit 1
	fi
	echo ""
	
	echo -e "${GREEN}========================================${NC}"
	echo -e "${GREEN}Regression completed successfully!${NC}"
	echo -e "${GREEN}========================================${NC}"
	exit 0
fi

exit 0
