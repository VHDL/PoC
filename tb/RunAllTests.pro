# =============================================================================
# Authors:
#	Adrian Weiland, Jonas Schreiner
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

library tb_common
include ./common.pro

include ./arith/RunAllTests.pro
include ./bus/RunAllTests.pro
#include ./cache/RunAllTests.pro
#include ./common/RunAllTests.pro
disabled ./dstruct/RunAllTests.pro
#include ./fifo/RunAllTests.pro
disabled ./io/RunAllTests.pro
#include ./mem/RunAllTests.pro
include ./misc/RunAllTests.pro
#include ./sim/RunAllTests.pro
#include ./sort/RunAllTests.pro
