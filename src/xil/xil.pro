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
	analyze ./xil_DNAPort.vhdl
	analyze ./xil_ICAP.vhdl
	analyze ./xil_BSCAN.vhdl
	analyze ./xil_Reconfigurator.vhdl
	analyze ./xil_SystemMonitor.vhdl
	analyze ./reconfig/reconfig_icap_fsm.vhdl
	analyze ./reconfig/reconfig_icap_wrapper.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	puts "No Altera files in this namespace."

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknow vendor '$::poc::vendorName' in xil!"
	exit 1
}

