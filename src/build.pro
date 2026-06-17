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

include ./common
disabled ./misc/misc_ClockBuffer.vhdl
include ./sync
include ./arith
include ./misc

analyze ./bus/axi4/axi4_Common.pkg.vhdl
analyze ./bus/axi4/axi4_Full.pkg.vhdl
analyze ./bus/axi4stream/axi4stream.pkg.vhdl
analyze ./bus/axi4lite/axi4lite.pkg.vhdl
analyze ./bus/axi4/axi4.pkg.vhdl

include ./mem
include ./fifo
include ./xil

include ./dstruct
include ./io
include ./bus
include ./comm
include ./sort
include ./cache

analyze ./list/list_Expire.vhdl

include ./net
include ./sim

