# =============================================================================
# Authors:
#	Iqbal Asif
#	Patrick Lehmann
#	Adrian Weiland
#	Stefan Unrein
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

# TestSuite PoC.bus.axi4
# Deactivated to avoid failure on non-existing testcases

library tb_axi4

include ./AXI4Lite/RunAllTests.pro

#include ./AXI4Stream/Buffer/RunAllTests.pro
#include ./AXI4Stream/Buffer_CDC/RunAllTests.pro
#include ./AXI4Stream/DeMux/RunAllTests.pro
#include ./AXI4Stream/Delay/RunAllTests.pro
#include ./AXI4Stream/Splitter/RunAllTests.pro
#include ./AXI4Stream/DestHandler/RunAllTests.pro
#include ./AXI4Stream/Realign/RunAllTests.pro
