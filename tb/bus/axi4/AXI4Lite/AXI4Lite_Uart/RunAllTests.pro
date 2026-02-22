# =============================================================================
# Authors:
#   Srikanth Boppudi (PLC2 Design GmbH)
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

TestSuite PoC.bus.axi4.axi4Lite.Uart

library tb_axi4lite_UART

analyze axi4lite_UART_tc.vhdl
analyze axi4lite_UART_th.vhdl

RunTest axi4lite_UART_receive.vhdl
RunTest axi4lite_UART_transmit_burst.vhdl
# RunTest axi4lite_UART_receive_burst.vhdl
# RunTest axi4lite_UART_receive_parity.vhdl
# RunTest axi4lite_UART_SWFC.vhdl
