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

include ./PRNG/RunAllTests.pro
include ./Prefix_And/RunAllTests.pro
include ./Prefix_Or/RunAllTests.pro
include ./Adder_Wide/RunAllTests.pro
include ./Counter_BCD/RunAllTests.pro
include ./Convert_Binary2BCD/RunAllTests.pro
include ./Divider/RunAllTests.pro
include ./FirstOne/RunAllTests.pro
include ./Scaler/RunAllTests.pro
include ./Same/RunAllTests.pro
include ./Counter_Ring/RunAllTests.pro
include ./Counter_Gray/RunAllTests.pro
include ./Counter_Free/RunAllTests.pro
include ./CarryChain_inc/RunAllTests.pro
include ./cca/RunAllTests.pro
include ./Shifter_Barrel/RunAllTests.pro
include ./SquareRoot/RunAllTests.pro
include ./TRNG/RunAllTests.pro
