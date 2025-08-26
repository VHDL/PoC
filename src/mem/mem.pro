# =============================================================================
# Authors:
#	Adrian Weiland, Stefan Unrein
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
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

analyze ./mem.pkg.vhdl
analyze ./ocram/ocram.pkg.vhdl
analyze ./ocram/ocram_tdp_sim.vhdl
analyze ./ocram/ocram_tdp.vhdl
analyze ./ocram/ocram_esdp.vhdl
analyze ./ocram/ocram_sdp.vhdl
analyze ./ocram/ocram_sdp_optimized.vhdl
analyze ./ocram/ocram_sdp_wf.vhdl
analyze ./ocram/ocram_sp.vhdl
analyze ./ocram/ocram_tdp_wf.vhdl
analyze ./ocram/altera/ocram_sp_altera.vhdl
analyze ./ocram/altera/ocram_tdp_altera.vhdl

analyze ./ocrom/ocrom.pkg.vhdl
analyze ./ocrom/ocrom_dp.vhdl
analyze ./ocrom/ocrom_sp.vhdl

analyze ./sdram/sdram_ctrl_de0.vhdl
analyze ./sdram/sdram_ctrl_fsm.vhdl
analyze ./sdram/sdram_ctrl_phy_de0.vhdl
analyze ./sdram/sdram_ctrl_phy_s3esk.vhdl
analyze ./sdram/sdram_ctrl_s3esk.vhdl

analyze ./mem_GitVersionRegister.pkg.vhdl

analyze ./lut/lut_Sine.vhdl
