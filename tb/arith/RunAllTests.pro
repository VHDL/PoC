# =============================================================================
# Authors: Jonas Schreiner
#          Gustavo Martin
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

# TestSuite PoC.arith
# Deactivated to avoid failure on non-existing testcases

library tb_arith

include ./prng/RunAllTests.pro
include ./prefix_and/RunAllTests.pro
include ./prefix_or/RunAllTests.pro
include ./addw/RunAllTests.pro
include ./counter_bcd/RunAllTests.pro
include ./convert_bin2bcd/RunAllTests.pro
include ./div/RunAllTests.pro
include ./firstone/RunAllTests.pro
include ./scaler/RunAllTests.pro
include ./same/RunAllTests.pro
include ./counter_ring/RunAllTests.pro
include ./counter_gray/RunAllTests.pro
include ./counter_free/RunAllTests.pro
include ./carrychain_inc/RunAllTests.pro
include ./cca/RunAllTests.pro
include ./shifter_barrel/RunAllTests.pro
include ./sqrt/RunAllTests.pro
include ./trng/RunAllTests.pro
