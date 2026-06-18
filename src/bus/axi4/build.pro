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

#analyze axi4_Common.pkg.vhdl; # analyzed in PoC.pro
#analyze axi4_Full.pkg.vhdl;   # analyzed in PoC.pro
#analyze axi4.pkg.vhdl;        # analyzed in PoC.pro

disabled axi4_Address_Data_Aligner.vhdl
disabled axi4_Address_Translate.vhdl
disabled axi4_Address_Translate_n_Filter.vhdl
disabled axi4_Data_Swapper.vhdl
analyze axi4_FIFO.vhdl
analyze axi4_FIFO_CDC.vhdl
analyze axi4_DeMux.vhdl
analyze axi4_Mux.vhdl
disabled axi4_Packet_FIFO.vhdl
analyze axi4_Sink.vhdl
analyze axi4_Termination_Manager.vhdl
analyze axi4_Termination_Subordinate.vhdl
analyze axi4_AXI4Lite_Converter.vhdl
analyze axi4_OSVVM.pkg.vhdl
