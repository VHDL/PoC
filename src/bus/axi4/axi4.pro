# =============================================================================
# Authors:
#	Adrian Weiland
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

#Packages included on main PoC.pro
#analyze AXI4_Common.pkg.vhdl
#analyze AXI4_Full.pkg.vhdl
#analyze ./AXI4Stream/AXI4Stream.pkg.vhdl
#analyze ./AXI4Lite/AXI4Lite.pkg.vhdl
#analyze axi4.pkg.vhdl

disabled AXI4_Address_Data_Aligner.vhdl
disabled AXI4_Address_Translate.vhdl
disabled AXI4_Address_Translate_n_Filter.vhdl
disabled AXI4_Data_Swapper.vhdl
analyze AXI4_FIFO.vhdl
analyze AXI4_FIFO_cdc.vhdl
disabled AXI4_DeMux.vhdl
disabled AXI4_Mux.vhdl
disabled AXI4_Packet_FIFO.vhdl
disabled AXI4_Sink_Slave.vhdl
analyze AXI4_Termination_Manager.vhdl
analyze AXI4_Termination_Subordinate.vhdl
analyze AXI4_to_AXI4Lite.vhdl

analyze AXI4_OSVVM.pkg.vhdl

disabled ./AXI4Lite/AXI4Lite_AddressMask.vhdl
disabled ./AXI4Lite/AXI4Lite_AddressTruncate.vhdl
disabled ./AXI4Lite/AXI4Lite_Writer.vhdl
disabled ./AXI4Lite/AXI4Lite_Reader.vhdl
# analyze ./AXI4Lite/AXI4Lite_Configurator.vhdl                ;  # Does not work right now
disabled ./AXI4Lite/AXI4Lite_DeMux.vhdl
disabled ./AXI4Lite/AXI4Lite_ErrorFilter.vhdl
analyze ./AXI4Lite/AXI4Lite_FIFO.vhdl
analyze ./AXI4Lite/AXI4Lite_FIFO_cdc.vhdl
analyze ./AXI4Lite/AXI4Lite_Register.vhdl
disabled ./AXI4Lite/AXI4Lite_Register_split.vhdl
analyze ./AXI4Lite/AXI4Lite_Termination_Manager.vhdl
analyze ./AXI4Lite/AXI4Lite_Termination_Subordinate.vhdl
analyze ./AXI4Lite/AXI4Lite_HighResolutionClock.vhdl
# analyze ./AXI4Lite/AXI4Lite_Interrupt_Controller.vhdl        ;  # Does not work right now
analyze ./AXI4Lite/AXI4Lite_Ocram_Adapter.vhdl
analyze ./AXI4Lite/AXI4Lite_OSVVM.pkg.vhdl
analyze ./AXI4Lite/AXI4Lite_GitVersionRegister.vhdl
disabled ./AXI4Lite/AXI4Lite_SimpleInterface.vhdl
analyze ./AXI4Lite/AXI4Lite_Uart.vhdl

analyze ./AXI4Stream/AXI4Stream_FIFO.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_cdc.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_tempgot.vhdl
analyze ./AXI4Stream/AXI4Stream_FIFO_tempput.vhdl
analyze ./AXI4Stream/AXI4Stream_Stage.vhdl
disabled ./AXI4Stream/AXI4Stream_Mirror.vhdl
analyze ./AXI4Stream/AXI4Stream_Mux.vhdl
disabled ./AXI4Stream/AXI4Stream_Pause.vhdl
analyze ./AXI4Stream/AXI4Stream_DeMux.vhdl
disabled ./AXI4Stream/AXI4Stream_DataExtractor.vhdl
disabled ./AXI4Stream/AXI4Stream_PatternFinder.vhdl
disabled ./AXI4Stream/AXI4Stream_FieldReplacer.vhd
disabled ./AXI4Stream/AXI4Stream_Crossbar.vhdl              ;  # Does not work right now due to Riviera compiler error (bug report is pending)
# analyze ./AXI4Stream/AXI4Stream_Frame_Buffer.vhdl         ;  #Does not work right now
disabled ./AXI4Stream/AXI4Stream_PRBSGenerator.vhdl
disabled ./AXI4Stream/AXI4Stream_Termination_Manager.vhdl
disabled ./AXI4Stream/AXI4Stream_Termination_Subordinate.vhdl
disabled ./AXI4Stream/AXI4Stream_Buffer_no_backpressure.vhdl
disabled ./AXI4Stream/AXI4Stream_To_Stream.vhdl
disabled ./AXI4Stream/AXI4Stream_Splitter.vhdl
disabled ./AXI4Stream/AXI4Stream_Delay.vhdl
disabled ./AXI4Stream/AXI4Stream_Realign.vhdl

# FIXME: should be analyzed before PoC.bus, right?
analyze ../../misc/gearbox/gearbox_down_cc.vhdl
analyze ../../misc/gearbox/gearbox_up_cc.vhdl
disabled ./AXI4Stream/AXI4Stream_Gearbox.vhdl
