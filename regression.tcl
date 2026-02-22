# =============================================================================
# Authors:
#   Jonas Schreiner
#   Stefan Unrein
#   Patrick Lehmann
#   Adrian Weiland
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

source ../lib/OSVVM-Scripts/StartUp.tcl
source ../tools/OSVVM/poc.tcl

namespace import ::poc::*

# Skip report generation if executed within Sigasi/VS Code
if {[info exists ::env(OSVVM_TOOL)] && $::env(OSVVM_TOOL) eq "Sigasi"} {
	set ::osvvm::GenerateOsvvmReports "false"
}
if {[info exists ::env(GITLAB_CI)]} {
	set buildNamePrefix ""
} else {
	set buildNamePrefix "${::osvvm::ToolNameVersion}-"
}

namespace eval ::poc {
	variable myConfigFile  "../tb/common/my_config_${boardName}.vhdl"
	variable myProjectFile "../tb/common/my_project.vhdl"
}

build ../lib/OsvvmLibraries.pro [BuildName "${buildNamePrefix}OsvvmLibraries"]
if {$::osvvm::AnalyzeErrorCount > 0} {
	puts "ERROR: While building OSVVM"
	scriptExit
}

# -s -stop <i>    set the stop counts to <i>
# -d -debug       enable debugging
# -w -waves       save waveforms
configureOSVVM -stop 1 ;# -debug

build ../src/PoC.pro [BuildName "${buildNamePrefix}PoC"]
if {$::osvvm::AnalyzeErrorCount > 0} {
	puts "ERROR: While building PoC Library"

	puts $::errorInfo
	puts "====================================="
	puts $::osvvm::BuildErrorInfo

	scriptExit
}

build ../tb/RunAllTests.pro  [BuildName "${buildNamePrefix}RunAllTests"]
