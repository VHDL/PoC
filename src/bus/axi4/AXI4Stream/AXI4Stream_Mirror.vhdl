-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	A generic buffer module for the PoC.Stream protocol.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use         PoC.axi4stream.all;


entity AXI4Stream_Mirror is
	generic (
		PORTS							: positive									:= 2
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Port
		In_m2s					: in	T_AXI4STREAM_M2S;
		In_s2m					: out	T_AXI4STREAM_S2M;
		
		-- OUT Port
		Out_M2S					: out	T_AXI4STREAM_M2S_VECTOR;
		Out_S2M					: in	T_AXI4STREAM_S2M_VECTOR
	);
end entity;


architecture rtl of AXI4Stream_Mirror is
	constant DATA_BITS      : positive := In_M2S.Data'length;
	constant USER_BITS      : natural  := In_M2S.User'length;
	constant FIFO_BITS      : positive := DATA_BITS + 1 + USER_BITS; -- Width (+ 1 is Last-bit)
	signal   FIFO_full      : std_logic;
	signal   FIFO_put       : std_logic;
	signal   FIFO_data_in   : std_logic_vector(FIFO_BITS - 1 downto 0);
	signal   FIFO_data_out  : std_logic_vector(FIFO_BITS - 1 downto 0);
	
	signal 	 Out_Ready						: std_logic_vector(PORTS - 1 downto 0);
	signal 	 FIFOGlue_Valid				: std_logic;
	signal   FIFOGlue_got					: std_logic;

	signal Ready_i							: std_logic;
	signal Mask_r								: std_logic_vector(PORTS - 1 downto 0)	:= (others => '1');

	signal MetaOut_rst					: std_logic_vector(PORTS - 1 downto 0);

	signal Out_Data_i						: T_SLM(PORTS - 1 downto 0, DATA_BITS - 1 downto 0)						:= (others => (others => 'Z'));

begin

	-- Data path
	-- ==========================================================================================================================================================
	FIFO_data_in        <= In_M2S.User & In_M2S.Last & In_M2S.Data;
	FIFO_put            <= In_M2S.Valid;
	In_S2M.Ready        <= not FIFO_full;

	FIFO : entity work.fifo_glue
		generic map (
			D_BITS                  => FIFO_BITS
		)
		port map (
			-- Global Reset and Clock
			clk                     => Clock,
			rst                     => Reset,

			-- Writing Interface
			put                     => FIFO_put,
			di                      => FIFO_data_in,
			ful                     => FIFO_full,

			-- Reading Interface
			vld                     => FIFOGlue_Valid,
			do                      => FIFO_data_out,
			got                     => FIFOGlue_got
		);
	
	gen:for i in 0 to PORTS - 1 generate
		Out_Ready(i) <= Out_S2M(i).Ready;	
	end generate;
	
	Ready_i							<= 	slv_and(Out_Ready) or slv_and(not Mask_r or Out_Ready);
	FIFOGlue_got			  <=  Ready_i;
	
	genOutput : for i in 0 to PORTS - 1 generate
		Out_M2S(i).Valid		<= FIFOGlue_Valid;
		Out_M2S(i).Data     <= FIFO_data_out(DATA_BITS - 1 downto 0);
		Out_M2S(i).User     <= FIFO_data_out(FIFO_data_out'high downto DATA_BITS + 1);
		Out_M2S(i).Last			<= FIFO_data_out(DATA_BITS);
	end generate;
	
end architecture;
