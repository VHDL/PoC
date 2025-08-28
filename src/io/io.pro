# =============================================================================
# Authors: Adrian Weiland
#          Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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

analyze ./io.pkg.vhdl
analyze ./io_Debounce.vhdl
analyze ./io_FrequencyCounter.vhdl
analyze ./io_TimingCounter.vhdl
analyze ./io_GlitchFilter.vhdl
analyze ./io_PulseWidthModulation.vhdl
analyze ./io_KeyPadScanner.vhdl
analyze ./io_7SegmentMux_BCD.vhdl
analyze ./io_7SegmentMux_HEX.vhdl
analyze ./io_FanControl.vhdl

analyze ./ddrio/ddrio.pkg.vhdl
analyze ./ddrio/ddrio_in.vhdl
analyze ./ddrio/ddrio_inout.vhdl
analyze ./ddrio/ddrio_out.vhdl

if { $::poc::vendor eq "Xilinx" } {
	analyze ./ddrio/ddrio_in_xilinx.vhdl
	analyze ./ddrio/ddrio_inout_xilinx.vhdl
	analyze ./ddrio/ddrio_out_xilinx.vhdl

} elseif { $::poc::vendor eq "Altera" } {
	analyze ./ddrio/ddrio_in_altera.vhdl
	analyze ./ddrio/ddrio_inout_altera.vhdl
	analyze ./ddrio/ddrio_out_altera.vhdl

} elseif { $::poc::vendor ne "GENERIC" } {
	puts "Unknow vendor '$::poc::vendor' in arith!"
	exit 1
}

include ./uart/uart.pro
include ./iic/iic.pro

analyze ./pmod/pmod.pkg.vhdl
analyze ./pmod/pmod_KYPD.vhdl
analyze ./pmod/pmod_SSD.vhdl
analyze ./pmod/pmod_USBUART.vhdl

