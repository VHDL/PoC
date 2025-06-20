# =============================================================================
# Authors:
#	Jonas Schreiner
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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
# =============================================================================

namespace eval ::poc {
	variable myConfigFile  "../tb/common/my_config_GENERIC.vhdl"
	variable myProjectFile "../tb/common/my_project.vhdl"
	variable vendor "GENERIC"; # GENERIC for vendor-less build; Xilinx, Altera,... for vendor specific build
}

source ../lib/OSVVM-Scripts/StartUp.tcl

build ../lib/osvvm/osvvm.pro
build ../lib/OSVVM-Common/Common.pro
build ../lib/OSVVM-AXI4/AXI4.pro
# build ../lib/OSVVM-UART/UART.pro

if {$::osvvm::ToolName eq "GHDL"} {
    SetExtendedAnalyzeOptions {-frelaxed -Wno-specs}
    SetExtendedSimulateOptions {-frelaxed -Wno-specs -Wno-binding}
}

if {$::osvvm::ToolName eq "RiveraPRO"} {
    SetExtendedSimulationOptions {-unbounderror}
}
#set ::osvvm::AnalyzeErrorStopCount 1
#set ::osvvm::SimulateErrorStopCount 1


build ../src/PoC.pro

#SetSaveWaves

build ../tb/RunAllTests.pro
