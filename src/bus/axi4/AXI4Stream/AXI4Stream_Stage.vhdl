-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:                 Max Kraft-Kugler
--
-- Entity:                  A generic AXI4-Stream Stage (Two-Stage FIFO).
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
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
use     work.vectors.all;
use     work.axi4stream.all;


entity AXI4Stream_Stage is
	generic (
		STAGES            : natural := 2
	);
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


architecture rtl of AXI4Stream_Stage is
	constant Data_Pos       : natural  := 0;
	constant Keep_Pos       : natural  := 1;
	constant Last_Pos       : natural  := 2;
	constant User_Pos       : natural  := 3;
	constant Dest_Pos       : natural  := 4;
	constant ID_Pos         : natural  := 5;
	constant Data_Bits_Vec  : T_NATVEC := (
		Keep_Pos       => In_M2S.Keep'length,
		Data_Pos       => In_M2S.Data'length,
		Last_Pos       => 1,
		User_Pos       => In_M2S.User'length,
		Dest_Pos       => In_M2S.Dest'length,
		ID_Pos         => In_M2S.ID'length
	);

	signal FIFO_full      : std_logic;
	signal FIFO_put       : std_logic;
	signal FIFO_data_in   : std_logic_vector(isum(Data_Bits_Vec) - 1 downto 0);
	signal FIFO_data_out  : std_logic_vector(isum(Data_Bits_Vec) - 1 downto 0);

begin

	FIFO_data_in(high(Data_Bits_Vec, Data_Pos) downto low(Data_Bits_Vec, Data_Pos)) <= In_M2S.Data;
	FIFO_data_in(high(Data_Bits_Vec, Keep_Pos) downto low(Data_Bits_Vec, Keep_Pos)) <= In_M2S.Keep;
	FIFO_data_in(high(Data_Bits_Vec, Last_Pos))					                            <= In_M2S.Last;
	FIFO_data_in(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos)) <= In_M2S.User;
	FIFO_data_in(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos)) <= In_M2S.Dest;
	FIFO_data_in(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  )) <= In_M2S.ID;

	FIFO_put      <= In_M2S.Valid;
	In_S2M.Ready  <= not FIFO_full;

	FIFO : entity work.fifo_stage
	generic map (
		D_BITS   => isum(Data_Bits_Vec),
		STAGES   => STAGES
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

	Out_M2S.Data <= FIFO_data_out(high(Data_Bits_Vec, Data_Pos) downto low(Data_Bits_Vec, Data_Pos));
	Out_M2S.Keep <= FIFO_data_out(high(Data_Bits_Vec, Keep_Pos) downto low(Data_Bits_Vec, Keep_Pos));
	Out_M2S.Last <= FIFO_data_out(high(Data_Bits_Vec, Last_Pos))					                          ;
	Out_M2S.User <= FIFO_data_out(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos));
	Out_M2S.Dest <= FIFO_data_out(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos));
	Out_M2S.ID   <= FIFO_data_out(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  ));

end architecture;
