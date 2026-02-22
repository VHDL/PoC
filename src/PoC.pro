# =============================================================================
# Authors:
#   Adrian Weiland, Jonas Schreiner, Stefan Unrein
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

library PoC

analyze $::poc::myConfigFile
analyze $::poc::myProjectFile

include ./common/common.pro
analyze ./xil/./xil.pkg.vhdl
disabled ./misc/misc_ClockBuffer.vhdl
include ./sync/sync.pro
include ./arith/arith.pro
include ./misc/misc.pro

analyze ./bus/axi4/AXI4_Common.pkg.vhdl
analyze ./bus/axi4/AXI4_Full.pkg.vhdl
analyze ./bus/axi4/AXI4Stream/AXI4Stream.pkg.vhdl
analyze ./bus/axi4/AXI4Lite/AXI4Lite.pkg.vhdl
analyze ./bus/axi4/axi4.pkg.vhdl

include ./mem/mem.pro
include ./fifo/fifo.pro
include ./xil/xil.pro

include ./dstruct/dstruct.pro
include ./io/io.pro
include ./bus/bus.pro
include ./comm/comm.pro
include ./sort/sort.pro
include ./cache/cache.pro

analyze ./list/list_expire.vhdl

include ./net/net.pro
include ./sim/sim.pro

