# =============================================================================
# Authors: Iqbal Asif (PLC2 Design GmbH)
#          Patrick Lehmann (PLC2 Design GmbH)
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

# TestSuite PoC.bus.axi4.axi4Lite
# Deactivated to avoid failure on non-existing testcases

library tb_axi4Lite

disabled ./AXI4Lite_Demux/RunAllTests.pro
include ./AXI4Lite_Register/RunAllTests.pro
include ./AXI4Lite_Ocram_Adapter/RunAllTests.pro
# include ./AXI4Lite_InterruptController/RunAllTests.pro      # Currently not working
include ./AXI4Lite_Uart/RunAllTests.pro
# include ./AXI4Lite_HighResolutionClock/RunAllTests.pro      # Currently not working
