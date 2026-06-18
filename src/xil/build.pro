# =============================================================================
# Authors: Adrian Weiland
#          Jonas Schreiner
#          Stefan Unrein
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

analyze ./xil.pkg.vhdl
if { $::poc::vendorName eq "Xilinx" } {
	disabled ./xil_ClockBuffer.vhdl
	disabled ./xil_Trans_config.vhdl
	analyze ./xil_DNAPort.vhdl
	analyze ./xil_ICAP.vhdl
	analyze ./xil_BSCAN.vhdl
	analyze ./xil_Reconfigurator.vhdl

	if {$::osvvm::ToolName eq "GHDL" || $::osvvm::ToolName eq "NVC"} {
		# todo: fix error: length of value 8 does not match length of target 16 for signal ALM (line 124, 359)
		disabled ./xil_SystemMonitor.vhdl
	} else {
		analyze ./xil_SystemMonitor.vhdl
	}
	analyze ./reconfig/reconfig_ICAP_FSM.vhdl
	analyze ./reconfig/reconfig_ICAP_Wrapper.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	puts "No Altera files in this namespace."

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknow vendor '$::poc::vendorName' in xil!"
	exit 1
}

