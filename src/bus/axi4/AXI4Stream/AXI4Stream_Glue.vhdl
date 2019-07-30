-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:                 Max Kraft-Kugler
--
-- Entity:                  A generic AXI4-Stream Glue (Two-Stage FIFO).
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;

use     work.axi4stream.all;


entity AXI4Stream_Glue is
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4Stream_M2S;
		In_S2M            : out T_AXI4Stream_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of AXI4Stream_Glue is
	constant DATA_BITS      : positive := In_M2S.Data'length;
	constant USER_BITS      : natural  := In_M2S.User'length;
	constant FIFO_BITS      : positive := DATA_BITS + 1 + USER_BITS; -- Data Width (+ 1 is Last-bit)
	
	signal   FIFO_full      : std_logic;
	signal   FIFO_put       : std_logic;
	signal   FIFO_data_in   : std_logic_vector(FIFO_BITS - 1 downto 0);
	signal   FIFO_data_out  : std_logic_vector(FIFO_BITS - 1 downto 0);

begin

	-- FIFO_data_in  <= (In_M2S.User, In_M2S.Last, In_M2S.Data); -- BUG: broken in Vivado 2018.3
	FIFO_data_in  <= In_M2S.User & In_M2S.Last & In_M2S.Data;
	FIFO_put      <= In_M2S.Valid;
	In_S2M.Ready  <= not FIFO_full;

	FIFO : entity work.fifo_glue
		generic map (
			D_BITS  => FIFO_BITS
		)
		port map (
			-- Global Reset and Clock
			clk     => Clock,
			rst     => Reset,

			-- Writing Interface
			put     => FIFO_put,
			di      => FIFO_data_in,
			ful     => FIFO_full,

			-- Reading Interface
			vld     => Out_M2S.Valid,
			do      => FIFO_data_out,
			got     => Out_S2M.Ready
		);

	Out_M2S.User  <= FIFO_data_out(FIFO_data_out'high downto DATA_BITS + 1);
	Out_M2S.Last  <= FIFO_data_out(DATA_BITS);
	Out_M2S.Data  <= FIFO_data_out(DATA_BITS - 1 downto 0);

end architecture;
