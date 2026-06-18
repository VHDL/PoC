# =============================================================================
# Authors:
#	Iqbal Asif (PLC2 Design GmbH)
#	Patrick Lehmann (PLC2 Design GmbH)
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

TestSuite PoC.bus.axi4lite.OCRAM_Adapter

library tb_axi4lite_OCRAMAdapter

analyze axi4lite_OCRAM_Adapter_TestController.vhdl
analyze axi4lite_OCRAM_Adapter_TestHarness.vhdl

if {$::osvvm::ToolName in {GHDL}} {
	SkipTest TC_InitMemory.vhdl "Skip GHDL because llvm backend does not support external name required for this test."
	SkipTest TC_AsyncReadWrite.vhdl "Skip GHDL because llvm backend does not support external name required for this test."
	SkipTest TC_SimpleReadWrite.vhdl "Skip GHDL because llvm backend does not support external name required for this test."
} else {
	RunTest TC_InitMemory.vhdl [generic USE_INIT_FILE TRUE]
	RunTest TC_AsyncReadWrite.vhdl
	RunTest TC_SimpleReadWrite.vhdl
}
