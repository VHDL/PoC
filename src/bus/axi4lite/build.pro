# =============================================================================
# Authors:
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

#analyze ./axi4lite.pkg.vhdl; # analyzed in PoC.pro

disabled ./axi4lite_AddressMask.vhdl
disabled ./axi4lite_AddressTruncate.vhdl
disabled ./axi4lite_Writer.vhdl
disabled ./axi4lite_Reader.vhdl
# disabled ./axi4lite_Configurator.vhdl # Does not work right now
analyze ./axi4lite_DeMux.vhdl
disabled ./axi4lite_ErrorFilter.vhdl
analyze ./axi4lite_FIFO.vhdl
analyze ./axi4lite_FIFO_CDC.vhdl
analyze ./axi4lite_Register.vhdl
disabled ./axi4lite_Register_split.vhdl
analyze ./axi4lite_Termination_Manager.vhdl
analyze ./axi4lite_Termination_Subordinate.vhdl
analyze ./axi4lite_HighResolutionClock.vhdl
# disabled ./axi4lite_Interrupt_Controller.vhdl # Does not work right now
analyze ./axi4lite_OCRAM_Adapter.vhdl
analyze ./axi4lite_OSVVM.pkg.vhdl
analyze ./axi4lite_GitVersionRegister.vhdl
disabled ./axi4lite_SimpleInterface.vhdl
analyze ./axi4lite_UART.vhdl
