# =============================================================================
# Authors:
#	Iqbal Asif (PLC2 Design GmbH)
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

TestSuite PoC.bus.axi4.DeMux

library tb_axi4_DeMux

analyze axi4_DeMux_TestController.vhdl
analyze axi4_DeMux_TestHarness.vhdl

RunTest TC_SimpleReadWrite.vhdl [generic NUM_TRANSACTIONS 1]
RunTest TC_SimpleReadWrite_delay.vhdl [generic NUM_TRANSACTIONS 1]
RunTest TC_SimpleReadWrite_multiID.vhdl
SkipTest TC_SimpleReadWrite_multiID_randDelay.vhdl
