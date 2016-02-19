# EMACS settings: -*-   tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# ============================================================================
# Tcl Include: Vivado Workflow Utility Procedures
#
# Authors:   Thomas B. Preusser
#
# Description
# -----------
# This is a collection of generic utility Tcl procedures.
#
# License:
# ============================================================================
# Copyright 2007-2016 Technische Universitaet Dresden - Germany
#                     Chair for VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#               http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================

# Extracts a the value of the named constant typically from a VHDL
# configuration packaged.
# Note: This implementation will fail on string values containing
#       semicolons (;).
proc get_config_values {config_vhdl names} {
	# Read config file into string
  set fd [open $config_vhdl r]
  set data [list [read $fd]]
  close $fd

	# Build list of values assigned to passed configuration variable names
	set vals {}
	foreach name $names {
		if { [regexp -nocase [string tolower "constant\\s*$name\\s*:\\s*\\w+\\s*:=\\s*(\[^;]+?)\\s*;"] $data all val] == 0 }  { set val {} }
		lappend vals $val
	}
	return $vals
}
