# =============================================================================
# Authors:
#   Jonas Schreiner
#   Stefan Unrein
#   Patrick Lehmann
#   Adrian Weiland
#
# Description:
#   This file is structured in a way that it can run in different modes locally
#   and on the CI server. Parameters can be set through arguments (1) if used
#   interactively and through environment variables (2).
#
#   (1) When in interactive mode arguments can be set as shown below
#       set argv {<build_step>}; set argc 1
#       (it has been tested with Riviera-PRO, NVC and GHDL)
#
#   (2) The following environment variables can be set:
#       REGRESSION_START_STEP  : <build_step> (similar to (1))
#       REGRESSION_SINGLE_STEP : Execute only the selected step in
#                                REGRESSION_START_STEP (can be "1" or "0")
#
#   Afterwards the file can be sourced as usual.
#   Note that (1) always has priority over (2). If none are specified all steps
#   are executed and everything is built.
#
#   Examples:
#     Riviera-PRO:
#       'set argv {poc}; set argc 1; source ../regression.tcl'
#       This will built everything starting with the PoC. If only the PoC should
#       be build REGRESSION_SINGLE_STEP has to be set to "1" previously
#     exec-NVC:
#       'export REGRESSION_START_STEP="test"; export REGRESSION_SINGLE_STEP="1"'
#       'exec-NVC.sh -n --tcl-file=regression.tcl'
#       This will only run the tests.
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

set root [file dirname [info script]]
# noqa: W300
source ${root}/lib/OSVVM-Scripts/StartUp.tcl
# noqa: W300
source ${root}/tools/OSVVM/poc.tcl

namespace import ::poc::*

set executeSingleStep 0
if {[info exists ::env(REGRESSION_SINGLE_STEP)]} {
	set executeSingleStep [expr {$::env(REGRESSION_SINGLE_STEP) == 1}] ; # Only build selected step
}

proc map_level {step} {
	switch -nocase -- $step {
		"all"   { return 0 }
		"osvvm" { return 0 }
		"poc"   { return 1 }
		"test"  { return 2 }
		default {
			puts "\[WARNING\] Unknown build level '$step', using 'all'"
			return 0
		}
	}
}

# 1. argv (when used interactively)
#    example for only compiling poc and running the tests: 'set argv {poc}; set argc 1; clear; source ../regression.tcl'
if {[info exists argv] && [llength $argv] > 0} {
	set buildConfigSource "interactive"
	set level [map_level [lindex $argv 0]]

# 2. Check for environment variables
#    can i.e. set by 'export REGRESSION_START_STEP="test"'
} elseif {[info exists ::env(REGRESSION_START_STEP)]} {
	set buildConfigSource "environment variable"
	set level [map_level $::env(REGRESSION_START_STEP)]
} else {
	set buildConfigSource "default"
	set level 0
}

# 3. output result
puts "=================================="
puts "Build configuration"
puts "  Level: $level (set by $buildConfigSource)"
puts "  Executing [expr {$executeSingleStep ? "single step" : "multiple steps"}]"
puts "=================================="

# -g -gui         disables system exit (i.e. on errors)
# -v -vendor      Vendor name
# -b -board       Board name
# -p -projectFile Path to the my_project file
# -c -configFile  Path to the my_config file
configurePoC -g

# -s -stop <i>    set the stop counts to <i>
# -d -debug       enable debugging
# -w -waves       save waveforms
configureOSVVM -stop 1 ;

if {$level <= 0} {
	build ${root}/lib/OsvvmLibraries.pro [BuildName "${::poc::buildNamePrefix}OsvvmLibraries"]
	if {[checkForBuildErrors] || $executeSingleStep} {
		return
	}
}

if {$level <= 1} {
	build ${root}/PoC.pro [BuildName "${::poc::buildNamePrefix}PoC"]
	if {[checkForBuildErrors] || $executeSingleStep} {
		return
	}
}
if {$level <= 2} {
	build ${root}/tb/RunAllTests.pro [BuildName "${::poc::buildNamePrefix}RunAllTests"]
	if {[checkForRunErrors] || $executeSingleStep} {
		return
	}
}
