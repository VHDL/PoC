# =============================================================================
# Authors:
#	Adrian Weiland
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

analyze ./bus_Arbiter.vhdl

analyze ./stream/stream.pkg.vhdl
analyze ./stream/stream_DeMux.vhdl
analyze ./stream/stream_Mux.vhdl
disabled ./stream/stream_To_AXI4Stream.vhdl
disabled ./stream/stream_Delay.vhdl

include ./axi4stream
include ./axi4
include ./axi4lite
include ./stream

analyze ./drp/drp.pkg.vhdl
analyze ./drp/drp.generic.vhdl
analyze ./drp/drp_AXI4Lite_Bridge.vhdl
