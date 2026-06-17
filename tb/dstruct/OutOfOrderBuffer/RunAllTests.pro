# =============================================================================
# Authors:
#	Adrian Weiland (PLC2 Design GmbH)
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

TestSuite PoC.dstruct.OutOfOrderBuffer

library tb_struct_OutOfOrderBuffer

analyze dstruct_OutOfOrderBuffer_TestController.vhdl
analyze tb_OutOfOrderBuffer.vhdl

# Enable code coverage collection in simulations
# if {$::osvvm::ToolVendor eq "Aldec"} {
# 	SetCoverageSimulateEnable true
# }

RunTest TbOutOfOrderBuffer_WriteRead.vhdl

# Disable code coverage collection in simulations
# if {$::osvvm::ToolVendor eq "Aldec"} {
# 	SetCoverageSimulateEnable false
# }
