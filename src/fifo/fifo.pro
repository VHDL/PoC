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
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

analyze fifo.pkg.vhdl
analyze fifo_shift.vhdl
disabled fifo_stageFar.vhdl
analyze fifo_stage.vhdl
analyze fifo_ic_got.vhdl
analyze fifo_ic_assembly.vhdl
analyze fifo_cc_got.vhdl
disabled fifo_cc_got_commit.vhdl
analyze fifo_cc_got_tempgot.vhdl
analyze fifo_cc_got_tempput.vhdl
disabled fifo_cc_got_tempput_pipelined.vhdl
