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
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

TestSuite PoC.bus.axi4.axi4lite.HighResolutionClock

library tb_axi4lite_HighResolutionClock

analyze axi4lite_HighResolutionClock_tb_pkg.vhdl
analyze axi4lite_HighResolutionClock_th.vhdl
analyze axi4lite_HighResolutionClock_tc.vhdl

# Test Cases
RunTest axi4lite_HighResolutionClock_load_times.vhdl
RunTest axi4lite_HighResolutionClock_correction.vhdl
