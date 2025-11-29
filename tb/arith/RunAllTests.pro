# =============================================================================
# Authors: Jonas Schreiner
#          Gustavo Martin
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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

#SetSaveWaves true
#set ::osvvm::AnalyzeErrorStopCount 1
#set ::osvvm::SimulateErrorStopCount 1

TestSuite PoC.arith

library tb_arith

include ./prng/RunAllTests.pro
include ./prefix_and/RunAllTests.pro
include ./prefix_or/RunAllTests.pro
include ./addw/RunAllTests.pro
include ./counter_bcd/RunAllTests.pro
include ./convert_bin2bcd/RunAllTests.pro
include ./div/RunAllTests.pro
