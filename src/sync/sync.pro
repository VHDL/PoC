# =============================================================================
# Authors: Stefan Unrein
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

analyze ./sync.pkg.vhdl

if { $::poc::vendorName eq "Xilinx" } {
	analyze ./sync_Bits_Xilinx.vhdl
	analyze ./sync_Reset_Xilinx.vhdl
	analyze ./sync_Pulse_Xilinx.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	analyze ./sync_Bits_Altera.vhdl
	analyze ./sync_Reset_Altera.vhdl
	analyze ./sync_Pulse_Altera.vhdl

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName' in sync!"
	exit 1
}

analyze ./sync_Bits.vhdl
analyze ./sync_Reset.vhdl
analyze ./sync_Pulse.vhdl

analyze ./sync_Strobe.vhdl
analyze ./sync_Vector.vhdl
analyze ./sync_Command.vhdl
