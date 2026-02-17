# =============================================================================
# Authors: Adrian Weiland
#          Stefan Unrein
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

# ./misc_ClockBuffer.vhdl        ;  # Already analyzed in PoC.pro
disabled ./misc_ConditionCounter.vhdl
disabled ./misc_Data_Swapper.vhdl
analyze ./misc_Delay.vhdl
analyze ./misc_FrequencyMeasurement.vhdl
analyze ./misc_Sequencer.vhdl
analyze ./misc_StrobeGenerator.vhdl
analyze ./misc_StrobeLimiter.vhdl
analyze ./misc_StrobeStretcher.vhdl
analyze ./misc_bit_lz.vhdl

analyze ./clock/clock.pkg.vhdl
analyze ./clock/clock_Counter.vhdl
analyze ./clock/clock_Timer.vhdl
analyze ./clock/clock_HighResolution.vhdl

include ./filter/filter.pro
include ./stat/stat.pro

include ./gearbox/gearbox.pro
