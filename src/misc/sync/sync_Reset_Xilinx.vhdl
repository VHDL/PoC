-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:           Patrick Lehmann
--                    Stefan Unrein
--
-- Entity:           sync_Reset_Xilinx
--
-- Description:
-- -------------------------------------
--    This is the Xilinx specific implementation of the entity
--    'PoC.misc.sync.sync_Reset'. See the description there on how to use this.
--
--    CONSTRAINTS:
--      The relative placement of the internal sites is constrained by RLOCs.
--
--      Xilinx ISE UCF or XCF file:
--        NET "*_async"    TIG;
--        INST "*FF1_METASTABILITY_FFS" TNM = "METASTABILITY_FFS";
--        TIMESPEC "TS_MetaStability" = FROM FFS TO "METASTABILITY_FFS" TIG;
--
--      Xilinx Vivado xdc file:
--        TODO
--        TODO
--
-- License:
-- =============================================================================
-- Copryright 2017-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;

library UniSim;
use     UniSim.VComponents.all;

use     work.sync.all;


entity sync_Reset_Xilinx is
	generic (
		REGISTER_OUTPUT : boolean           := true;
		SYNC_DEPTH    : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low    -- generate SYNC_DEPTH many stages, at least 2
	);
	port (
		Clock         : in  std_logic;                                  -- <Clock>  output clock domain
		Input         : in  std_logic;                                  -- @async:  reset input
		D             : in  std_logic := '0';                           -- @Clock:  data input
		Output        : out std_logic                                   -- @Clock:  reset output
	);
end entity;


architecture rtl of sync_Reset_Xilinx is
	attribute ASYNC_REG                     : string;

	signal Reset_async                      : std_logic;
	signal Reset_meta                       : std_logic;
	signal Reset_sync                       : std_logic;

	-- Mark register "Reset_meta" and "Output" as asynchronous
	attribute ASYNC_REG of Reset_meta       : signal is "TRUE";
	attribute ASYNC_REG of Reset_sync       : signal is "TRUE";

begin
	assert (SYNC_DEPTH = 2) report "Xilinx synchronizer supports only 2 stages. It could be extended to 4 or 8 on new FPGA series." severity WARNING;

	Reset_async    <= Input;

	FF2_METASTABILITY_FFS : FDP
		generic map (
			INIT    => '1'
		)
		port map (
			C        => Clock,
			PRE      => Reset_async,
			D        => D,
			Q        => Reset_meta
	);

	FF3_METASTABILITY_FFS : FDP
		generic map (
			INIT    => '1'
		)
		port map (
			C        => Clock,
			PRE      => Reset_async,
			D        => Reset_meta,
			Q        => Reset_sync
	);

	Out_gen : if REGISTER_OUTPUT generate
		signal Output_d : std_logic := '0';
	begin
		Output_d <= Reset_sync when rising_edge(Clock);
		Output   <= Output_d;
	else generate
		Output   <= Reset_sync;
	end generate;
end architecture;
