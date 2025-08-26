# =============================================================================
# Authors:
#	Adrian Weiland, Stefan Unrein
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

#Packages included on main PoC.pro
#analyze AXI4_Common.pkg.vhdl
#analyze AXI4_Full.pkg.vhdl
#analyze ./AXI4Stream/AXI4Stream.pkg.vhdl
#analyze ./AXI4Lite/AXI4Lite.pkg.vhdl
#analyze axi4.pkg.vhdl

analyze AXI4_FIFO.vhdl
analyze AXI4_FIFO_cdc.vhdl
analyze AXI4_Termination_Manager.vhdl
analyze AXI4_Termination_Subordinate.vhdl
analyze AXI4_to_AXI4Lite.vhdl

analyze AXI4_OSVVM.pkg.vhdl

analyze ./AXI4Lite/AXI4Lite_FIFO.vhdl
analyze ./AXI4Lite/AXI4Lite_FIFO_cdc.vhdl
analyze ./AXI4Lite/AXI4Lite_Register.vhdl
analyze ./AXI4Lite/AXI4Lite_Termination_Manager.vhdl
analyze ./AXI4Lite/AXI4Lite_Termination_Subordinate.vhdl
analyze ./AXI4Lite/AXI4Lite_OSVVM.pkg.vhdl
analyze ./AXI4Lite/AXI4Lite_GitVersionRegister.vhdl

analyze ./AXI4Stream/AXI4Stream_FIFO.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_cdc.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_tempgot.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_tempput.vhdl
analyze ./AXI4Stream/AXI4Stream_Stage.vhdl
analyze ./AXI4Stream/AXI4Stream_Mux.vhdl
analyze ./AXI4Stream/AXI4Stream_DeMux.vhdl
analyze ../../misc/gearbox/gearbox_down_cc.vhdl
analyze ../../misc/gearbox/gearbox_up_cc.vhdl

