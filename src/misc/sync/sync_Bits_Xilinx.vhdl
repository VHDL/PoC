-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Stefan Unrein
--
-- Entity:           sync_Bits_Xilinx
--
-- Description:
-- -------------------------------------
-- This is a multi-bit clock-domain-crossing circuit optimized for Xilinx FPGAs.
-- It utilizes two `FD` instances from `UniSim.vComponents`. If you need a
-- platform independent version of this synchronizer, please use
-- `PoC.misc.sync.Flag`, which internally instantiates this module if a Xilinx
-- FPGA is detected.
--
-- .. ATTENTION:
--     Use this synchronizer only for long time stable signals (flags).
--
-- CONSTRAINTS:
--    This relative placement of the internal sites are constrained by RLOCs.
--
--   Xilinx ISE UCF or XCF file:
--    .. code-block:: VHDL
--
--        NET "*_async"    TIG;
--        INST "*FF1_METASTABILITY_FFS" TNM = "METASTABILITY_FFS";
--        TIMESPEC "TS_MetaStability" = FROM FFS TO "METASTABILITY_FFS" TIG;
--
--   Xilinx Vivado xdc file:
--    The XDC file `sync_Bits_Xilinx.xdc` must be directly applied to all
--    instances of sync_Bits_Xilinx. To achieve this, set the property
--    `SCOPED_TO_REF` to `sync_Bits_Xilinx` within the Vivado project.
--    Load the XDC file defining the clocks before that XDC file by using the
--    property `PROCESSING_ORDER`.
--
--    .. literalinclude:: ../../../ucf/misc/sync/sync_Bits_Xilinx.xdc
--       :language: xdc
--       :tab-width: 2
--       :linenos:
--       :lines: 4-8
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
use     IEEE.std_logic_1164.all;

use     work.utils.all;
use     work.sync.all;


entity sync_Bits_Xilinx is
	generic (
		BITS            : positive            := 1;                       -- number of bit to be synchronized
		INIT            : std_logic_vector    := x"00000000";             -- initialization bits
		SYNC_DEPTH      : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low;    -- generate SYNC_DEPTH many stages, at least 2
		FALSE_PATH      : boolean             := true;
		REGISTER_OUTPUT : boolean             := false
	);
	port (
		Clock           : in  std_logic;                                  -- <Clock>  output clock domain
		Input           : in  std_logic_vector(BITS - 1 downto 0);        -- @async:  input bits
		Output          : out std_logic_vector(BITS - 1 downto 0) := (others => '0')-- @Clock:  output bits
	);
end entity;


library IEEE;
use     IEEE.std_logic_1164.all;

library UniSim;
use     UniSim.vComponents.all;

use     work.sync.all;


entity sync_Bit_Xilinx is
	generic (
		INIT            : bit;                                            -- initialization bits
		FALSE_PATH      : boolean             := true;
		SYNC_DEPTH      : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low;   -- generate SYNC_DEPTH many stages, at least 2
		REGISTER_OUTPUT : boolean             := true
	);
	port (
		Clock           : in  std_logic;                                  -- <Clock>  output clock domain
		Input           : in  std_logic;                      -- @async:  input bits
		Output          : out std_logic                       -- @Clock:  output bits
	);
end entity;


architecture rtl of sync_Bits_Xilinx is
	constant INIT_I          : bit_vector    := to_bitvector(resize(descend(INIT), BITS));
begin
	gen : for i in 0 to BITS - 1 generate
		Sync: entity work.sync_Bit_Xilinx
			generic map (
				INIT            => INIT_I(i),
				FALSE_PATH      => FALSE_PATH,
				SYNC_DEPTH      => SYNC_DEPTH,
				REGISTER_OUTPUT => REGISTER_OUTPUT
			)
			port map (
				Clock           => Clock,
				Input           => Input(i),
				Output          => Output(i)
			);
	end generate;
end architecture;


architecture rtl of sync_Bit_Xilinx is
	attribute ASYNC_REG     : string;
	attribute SHREG_EXTRACT : string;

	signal Data_async       : std_logic;
	signal Data_meta        : std_logic;
	signal Data_sync        : std_logic_vector(SYNC_DEPTH - 1 downto 0);

	-- Mark register Data_async's input as asynchronous
	attribute ASYNC_REG     of Data_meta  : signal is "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	attribute SHREG_EXTRACT of Data_meta  : signal is "NO";
	attribute SHREG_EXTRACT of Data_sync  : signal is "NO";


begin
	Data_async  <= Input;

	FALSE_PATH_gen : if FALSE_PATH generate
		METASTABILITY_FF_FALSE_PATH : FD
			generic map (
				INIT    => INIT
			)
			port map (
				C       => Clock,
				D       => Data_async,
				Q       => Data_meta
			);
	else generate
		METASTABILITY_FF_MAX_DELAY : FD
			generic map (
				INIT    => INIT
			)
			port map (
				C       => Clock,
				D       => Data_async,
				Q       => Data_meta
			);
	end generate;

	Data_sync(0) <= Data_meta;

	gen: for i in 0 to SYNC_DEPTH - 2 generate
		FF : FD
			generic map (
				INIT    => INIT
			)
			port map (
				C       => Clock,
				D       => Data_sync(i),
				Q       => Data_sync(i + 1)
			);
		end generate;

	reg_out_gen : if REGISTER_OUTPUT generate
		signal Output_d : std_logic := '0';
	begin
		Output_d <= Data_sync(Data_sync'high) when rising_edge(Clock);
		Output   <= Output_d;
	else generate
		Output   <= Data_sync(Data_sync'high);
	end generate;
end architecture;
