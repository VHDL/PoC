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
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

analyze ./ddrio.pkg.vhdl
analyze ./ddrio_In.vhdl
analyze ./ddrio_InOut.vhdl
analyze ./ddrio_Out.vhdl

if { $::poc::vendorName eq "Xilinx" } {
	analyze ./ddrio_In_Xilinx.vhdl
	analyze ./ddrio_InOut_Xilinx.vhdl
	analyze ./ddrio_Out_Xilinx.vhdl

} elseif { $::poc::vendorName eq "Altera" } {
	analyze ./ddrio_In_Altera.vhdl
	analyze ./ddrio_InOut_Altera.vhdl
	analyze ./ddrio_Out_Altera.vhdl

} elseif { $::poc::vendorName ne "GENERIC" } {
	puts "Unknown vendor '$::poc::vendorName' in io!"
	exit 1
}
