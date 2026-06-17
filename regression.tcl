# =============================================================================
# Authors:
#   Jonas Schreiner
#   Stefan Unrein
#   Patrick Lehmann
#   Adrian Weiland
#
# Description:
#   This file is structured in a way that it can run in different modes locally
#   and on the CI server. Parameters can be set through arguments (a) if used
#   interactively and through environment variables (b).
#
#   (a) When in interactive mode, arguments can be set as shown below:
#       set ::argv <build_step>; set ::argc 1
#       (it has been tested with Riviera-PRO interactive, NVC interactive and tclsh with GHDL)
#
#   (b) One of the following environment variables can be set - REGRESSION_STEP has priority:
#       REGRESSION_FROM : <build_step> (similar to variant a)
#       REGRESSION_STEP : <build_step> - Execute only the selected step
#
#   Afterwards the file can be sourced as usual.
#   Note that (a) always has priority over (b). If none are specified all steps
#   are executed and everything is built.
#
#   Examples:
#     Riviera-PRO:
#       'set ::argv {poc}; set ::argc 1; source ../regression.tcl'
#       This will built everything starting with the PoC.
#     exec-NVC:
#       - 'REGRESSION_FROM="poc" exec-NVC.sh -n --tcl-file=regression.tcl'
#            This will build everything starting from the poc
#       - 'REGRESSION_STEP="test" exec-NVC.sh -n --tcl-file=regression.tcl'
#         'REGRESSION_FROM="poc" REGRESSION_STEP="test" exec-NVC.sh -n --tcl-file=regression.tcl'
#           This will only run the tests.
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
namespace import ::regression::*

#---------------------#
# Configuration space #
#---------------------#
set defaultStep "all"
set regressionLevels [createRegressionLevels osvvm poc test] ; # all

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

#---------------------#

evaluateRegressionLevel $defaultStep $regressionLevels

if {$::regression::level <= 0} {
	build ${root}/lib/OsvvmLibraries.pro [BuildName "${::poc::buildNamePrefix}OsvvmLibraries"]
	if {[checkForBuildErrors] || $::regression::executeSingleStep} {
		return
	}
}

if {$::regression::level <= 1} {
	build ${root}/PoC.pro [BuildName "${::poc::buildNamePrefix}PoC"]
	if {[checkForBuildErrors] || $::regression::executeSingleStep} {
		return
	}
}
if {$::regression::level <= 2} {
	build ${root}/tb/RunAllTests.pro [BuildName "${::poc::buildNamePrefix}RunAllTests"]
	if {[checkForRunErrors] || $::regression::executeSingleStep} {
		return
	}
}
