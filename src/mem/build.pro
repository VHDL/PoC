# =============================================================================
# Authors: Adrian Weiland
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

analyze ./mem.pkg.vhdl
analyze ./ocram/ocram.pkg.vhdl
analyze ./ocram/ocram_TrueDualPort_sim.vhdl
analyze ./ocram/ocram_TrueDualPort.vhdl
analyze ./ocram/ocram_EnhancedSimpleDualPort.vhdl
analyze ./ocram/ocram_SimpleDualPort.vhdl
analyze ./ocram/ocram_SimpleDualPort_Optimized.vhdl
analyze ./ocram/ocram_SimpleDualPort_wfasd.vhdl
analyze ./ocram/ocram_SinglePort.vhdl
analyze ./ocram/ocram_TrueDualPort_wasdf.vhdl

if { $::poc::vendorName eq "Xilinx" } {
	puts "No files for Xilinx."

} elseif { $::poc::vendorName eq "Altera" } {
	analyze ./ocram/altera/ocram_SimplePort_Altera.vhdl
	analyze ./ocram/altera/ocram_TrueDualPort_Altera.vhdl

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName'!"
	exit 1
}

analyze ./ocrom/ocrom.pkg.vhdl
analyze ./ocrom/ocrom_DualPort.vhdl
analyze ./ocrom/ocrom_SinglePort.vhdl

analyze ./sdram/sdram_ctrl_fsm.vhdl

# TODO: Remove Spartan 3 and Cyclone 3 files
if { $::poc::vendorName eq "Xilinx" } {
	analyze ./sdram/sdram_ctrl_phy_s3esk.vhdl
	analyze ./sdram/sdram_ctrl_s3esk.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	analyze ./sdram/sdram_ctrl_phy_de0.vhdl
	analyze ./sdram/sdram_ctrl_de0.vhdl

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName' in mem!"
	exit 1
}

analyze ./mem_GitVersionRegister.pkg.vhdl

analyze ./lut/lut_Sine.vhdl
