# =============================================================================
# Authors:
#	Adrian Weiland
#	Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

TestSuite PoC.bus.axi4stream.DeMux

library tb_axi4stream_DeMux

analyze TC_DeMux_e.vhdl
analyze DeMux_Harness.vhdl

RunTest TC_DeMux_a1.vhdl
RunTest TC_DeMux_a2.vhdl
RunTest TC_DeMux_a3.vhdl
RunTest TC_DeMux_a4.vhdl
