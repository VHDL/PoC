# =============================================================================
# Authors:
#   Jonas Schreiner
#   Stefan Unrein
#   Patrick Lehmann
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
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
	proc getEnv {var {default ""}} {
		if {[info exists ::env($var)]} {
			return $::env($var)
		}
		return $default
	}

	variable vendorName [getEnv VENDOR "GENERIC"]
	variable boardName  [getEnv BOARD  "GENERIC"]

	variable myConfigFile  "../tb/common/my_config_$boardName.vhdl"
	variable myProjectFile "../tb/common/my_project.vhdl"

	variable vendor $vendorName; # GENERIC for vendor-less build; Xilinx, Altera,... for vendor specific build
}

source ../lib/OSVVM-Scripts/StartUp.tcl
# source ../lib/OSVVM-Scripts/StartNVC.tcl

build ../lib/OsvvmLibraries.pro

if {$::osvvm::ToolName eq "GHDL"} {
	SetExtendedAnalyzeOptions  {-frelaxed -Wno-specs -Wno-elaboration}
	SetExtendedSimulateOptions {-frelaxed -Wno-specs -Wno-binding}

} elseif {$::osvvm::ToolName eq "RivieraPRO"} {
	set RivieraSimOptions {-unbounderror}

} elseif {$::osvvm::ToolName eq "NVC"} {
	ExtendedAnalyzeOptions {--relaxed}

} elseif {$::osvvm::ToolName eq "Sigasi"} {

} else {
	error [format {
======================================
Unknown simulator selected: %s

Supported simulators:
  - GHDL
  - RivieraPRO
  - NVC
Other tools:
  - Sigasi in VSCode
======================================
} $::osvvm::ToolName]
}

#set ::osvvm::AnalyzeErrorStopCount 1
#set ::osvvm::SimulateErrorStopCount 1

build ../src/PoC.pro

#SetSaveWaves

build ../tb/RunAllTests.pro
