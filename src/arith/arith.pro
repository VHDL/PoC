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
	analyze ./xilinx/arith_carrychain_inc_xilinx.vhdl
	analyze ./xilinx/arith_cca_xilinx.vhdl
	analyze ./xilinx/arith_addw_xilinx.vhdl
	analyze ./xilinx/arith_inc_ovcy_xilinx.vhdl
	analyze ./xilinx/arith_prefix_and_xilinx.vhdl
	analyze ./xilinx/arith_prefix_or_xilinx.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	puts "No Altera files for arith."

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName' in arith!"
	exit 1
}

disabled ./arith_accumulator.vhdl
analyze ./arith_addw.vhdl
analyze ./arith_carrychain_inc.vhdl
analyze ./arith_cca.vhdl
analyze ./arith_convert_bin2bcd.vhdl
analyze ./arith_counter_bcd.vhdl
analyze ./arith_counter_free.vhdl
analyze ./arith_counter_gray.vhdl
analyze ./arith_counter_ring.vhdl
analyze ./arith_div.vhdl
analyze ./arith_firstone.vhdl
analyze ./arith_prefix_and.vhdl
analyze ./arith_prefix_or.vhdl
analyze ./arith_prng.vhdl
analyze ./arith_same.vhdl
analyze ./arith_sqrt.vhdl
analyze ./arith_scaler.vhdl
analyze ./arith_shifter_barrel.vhdl
analyze ./arith_trng.vhdl
