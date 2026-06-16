# =============================================================================
# Authors:
#   Adrian Weiland
#   Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

analyze ./arith.pkg.vhdl

if { $::poc::vendorName eq "Xilinx" } {
	analyze ./xilinx/arith_CarryChain_inc_Xilinx.vhdl
	analyze ./xilinx/arith_cca_xilinx.vhdl

	if {$::osvvm::ToolName eq "NVC"} {
		# todo: fix error: cannot reference file OUTPUT in pure function COMPUTE_BLOCKS (line 128)
		disabled ./xilinx/arith_Adder_Wide_Xilinx.vhdl
	} else {
		analyze ./xilinx/arith_Adder_Wide_Xilinx.vhdl
	}

	analyze ./xilinx/arith_inc_ovcy_xilinx.vhdl
	analyze ./xilinx/arith_Prefix_And_Xilinx.vhdl
	analyze ./xilinx/arith_Prefix_Or_Xilinx.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	puts "No Altera files for arith."

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName' in arith!"
	exit 1
}

disabled ./arith_accumulator.vhdl
analyze ./arith_Adder_Wide.vhdl
analyze ./arith_CarryChain_inc.vhdl
analyze ./arith_cca.vhdl
analyze ./arith_Convert_Binary2BCD.vhdl
analyze ./arith_Counter_BCD.vhdl
analyze ./arith_counter_free.vhdl
analyze ./arith_Counter_Gray.vhdl
analyze ./arith_Counter_Ring.vhdl
analyze ./arith_Divider.vhdl
analyze ./arith_FirstOne.vhdl
analyze ./arith_Prefix_And.vhdl
analyze ./arith_Prefix_Or.vhdl
analyze ./arith_PRNG.vhdl
analyze ./arith_Same.vhdl
analyze ./arith_SquareRoot.vhdl
analyze ./arith_Scaler.vhdl
analyze ./arith_Shifter_Barrel.vhdl
analyze ./arith_TRNG.vhdl
