-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:  Iqbal Asif, Max Kraft-Kugler
--
-- Entity:   A generic stream Duplicator for the AXI4-Stream protocol.
--
-- Description:
-- -------------------------------------
-- This module duplicates an input stream to multiple output streams. Input 
-- stream and output streams must have the same width of data, user etc..
-- The ready for the 
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

library PoC;
use     PoC.config.all;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4stream.all;


entity AXI4Stream_Mirror is
	generic (
		-- Danger of combinatorial loop when disabeling this and 
		-- one of the elements connected to Out_M2S is registering 
		-- the input first
		ADD_OUTPUT_GLUE       : boolean := true
	);
	port (
		Clock                 : in  std_logic;
		Reset                 : in  std_logic;

		-- Mask Configuration:
		ready_mask            : in  std_logic_vector;
		mask_transaction_lost : out std_logic_vector;

		-- IN Port
		In_M2S                : in  T_AXI4STREAM_M2S;
		In_S2M                : out T_AXI4STREAM_S2M;
		
		-- OUT Port
		Out_M2S               : out T_AXI4STREAM_M2S_VECTOR;
		Out_S2M               : in  T_AXI4STREAM_S2M_VECTOR
	);
end entity;


architecture rtl of AXI4Stream_Mirror is

	constant PORTS            : positive := Out_M2S'length;
	constant DATA_BITS        : positive := In_M2S.Data'length;
	constant USER_BITS        : natural  := In_M2S.User'length;
	--constant KEEP_BITS        : natural  := In_M2S.Keep'length; 
	constant GLUE_BITS        : positive := DATA_BITS + 1 + USER_BITS; -- Width (+ 1 is Last-bit) -- KEEP_BITS +

	--constant Bit_Vec : T_INT_VEC (0 to 2) := (
	--	Data_Pos => DATA_BITS,
	--	Last_Pos => 1,
	--	User_pos => USER_BITS
	--	--Keep_Pos => KEEP_BITS
	--);
	signal InGlue_full        : std_logic;
	signal InGlue_put         : std_logic;
	signal InGlue_data_in     : std_logic_vector(GLUE_BITS - 1 downto 0);
	signal InGlue_data_out    : std_logic_vector(GLUE_BITS - 1 downto 0);
	signal InGlue_Valid       : std_logic;
	signal InGlue_got         : std_logic;

	signal Ack_i              : std_logic;
	signal Valid_Mask_r       : std_logic_vector(PORTS - 1 downto 0) := (others => '1');
	signal Valid_ack          : std_logic_vector(PORTS - 1 downto 0);
	signal Masked_ack         : std_logic_vector(PORTS - 1 downto 0);
	
	signal Out_Ready          : std_logic_vector(PORTS - 1 downto 0);

begin
	--InGlue_data_in(high(Bit_Vec, Data_Pos) downto low(Bit_Vec, Data_Pos)) <= In_M2S.Data;
	--InGlue_data_in(high(Bit_Vec, Last_Pos))                               <= In_M2S.Last;
	--InGlue_data_in(high(Bit_Vec, User_Pos) downto low(Bit_Vec, User_Pos)) <= In_M2S.User;
	--InGlue_data_in(high(Bit_Vec, Keep_Pos) downto low(Bit_Vec, Keep_Pos)) <= In_M2S.Keep;
	--TODO Fix with above:
	InGlue_data_in <= In_M2S.User & In_M2S.Last & In_M2S.Data;
	InGlue_put     <= In_M2S.Valid;
	In_S2M.Ready   <= not InGlue_full;

	FIFO : entity work.FIFO_glue
		generic map (
			D_BITS                  => GLUE_BITS
		)
		port map (
			-- Global Reset and Clock
			clk                     => Clock,
			rst                     => Reset,

			-- Writing Interface
			put                     => InGlue_put,
			di                      => InGlue_data_in,
			ful                     => InGlue_full,

			-- Reading Interface
			vld                     => InGlue_Valid,
			do                      => InGlue_data_out,
			got                     => InGlue_got
		);

	ackowlegde_gen : for i in 0 to PORTS - 1 generate
		-- remove valid only dependend on ready
		Valid_ack(i)  <= Out_S2M(i).Ready;
		-- acknowledge if masked or ready
		Masked_ack(i) <= Out_S2M(i).Ready or ready_mask(i);
	end generate;

	Ack_i         <= slv_and(Masked_ack) or slv_and(not Valid_Mask_r or Masked_ack);
	InGlue_got    <= Ack_i;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or Ack_i ) = '1') then
				Valid_Mask_r    <= (others => '1');
			else
				Valid_Mask_r    <= Valid_Mask_r and not Valid_ack;
			end if;
		end if;
	end process;

	reassign_Outputs : for i in 0 to PORTS - 1 generate
		Out_M2S(i).Valid    <= InGlue_Valid and Valid_Mask_r(i);
		--Out_M2S(i).Data     <= InGlue_data_out(high(Bit_Vec, Data_Pos) downto low(Bit_Vec, Data_Pos));
		--Out_M2S(i).Last     <= InGlue_data_out(high(Bit_Vec, Last_Pos));
		--Out_M2S(i).User     <= InGlue_data_out(high(Bit_Vec, User_Pos) downto low(Bit_Vec, User_Pos));
		--Out_M2S(i).Keep     <= InGlue_data_out(high(Bit_Vec, Keep_Pos) downto low(Bit_Vec, Keep_Pos));
		--TODO fix with above:
		Out_M2S(i).Data     <= get_row(InGlue_data_out, i)(DATA_BITS - 1 downto 0);
		Out_M2S(i).Last     <= get_row(InGlue_data_out, i)(DATA_BITS);
		Out_M2S(i).User     <= get_row(InGlue_data_out, i)(InGlue_data_out'high downto DATA_BITS + 1);
	end generate;

	-- missed transaction indication:
	gen_lost:for i in 0 to PORTS - 1 generate
		-- transaction is considered lost when:
		-- the mirror transaction (all ports are either ready or masked) has happend but current slave had no transaction (valid still asserted without a ready)
		mask_transaction_lost(i) <= ((glue_got and (Out_M2S(i).Valid and not Out_S2M(i).Ready));
	end generate;

end architecture;
