-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	A generic AXI4-Stream multiplexer.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

use			work.utils.all;
use			work.vectors.all;
use			work.components.all;
use			work.axi4stream.all;


entity AXI4Stream_DeMux is
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- Control interface
		DeMuxControl			: in	std_logic_vector;
		-- IN Port
		In_M2S            : in  T_AXI4Stream_M2S;
		In_S2M            : out T_AXI4Stream_S2M;
		-- OUT Ports
    Out_M2S           : out T_AXI4Stream_M2S_VECTOR;
		Out_S2M           : in  T_AXI4Stream_S2M_VECTOR
	);
end entity;


architecture rtl of AXI4Stream_DeMux is
  constant PORTS							: positive				:= Out_M2S'length;
	constant DATA_BITS					: positive				:= Out_M2S(0).Data'length;
    
	subtype T_CHANNEL_INDEX is natural range 0 to PORTS - 1;

	type T_STATE		is (ST_IDLE, ST_DATAFLOW, ST_DISCARD_FRAME);

	signal State								: T_STATE					:= ST_IDLE;
	signal NextState						: T_STATE;

	signal Is_SOF								: std_logic;
	signal Is_EOF								: std_logic;
  
  signal started              : std_logic := '0';

	signal In_Ack_i							: std_logic;
	signal Out_Valid_i					: std_logic;
	signal DiscardFrame					: std_logic;

	signal ChannelPointer_rst		: std_logic;
	signal ChannelPointer_en		: std_logic;
	signal ChannelPointer				: std_logic_vector(PORTS - 1 downto 0);
	signal ChannelPointer_d			: std_logic_vector(PORTS - 1 downto 0)								:= (others => '0');

  signal Out_Ready						: std_logic_vector(PORTS - 1 downto 0);
begin
  assert PORTS = DeMuxControl'length report "Number of Ports needs to be equal to Number of DeMux-Bits!" severity failure;

  started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.Last) or Reset), set => (In_M2S.Valid)) when rising_edge(Clock);
  
  assign_gen : for i in 0 to PORTS -1 generate
    Out_Ready(i)  <= Out_S2M(i).Ready;
  end generate;
  
	In_Ack_i			<= slv_or(Out_Ready	 and ChannelPointer);
	DiscardFrame	<= slv_nor(DeMuxControl);

	Is_SOF			<= In_M2S.Valid and not started;
	Is_EOF			<= In_M2S.Valid and In_M2S.Last;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;

	process(State, In_Ack_i, In_M2S.Valid, Is_SOF, Is_EOF, DiscardFrame, DeMuxControl, ChannelPointer_d)
	begin
		NextState									<= State;

		ChannelPointer_rst				<= Is_EOF;
		ChannelPointer_en					<= '0';
		ChannelPointer						<= ChannelPointer_d;

		In_S2M.Ready							<= '0';
		Out_Valid_i								<= '0';

		case State is
			when ST_IDLE =>
				ChannelPointer					<= DeMuxControl;

				if (Is_SOF = '1') then
					if (DiscardFrame = '0') then
						ChannelPointer_en		<= '1';
						In_S2M.Ready				<= In_Ack_i;
						Out_Valid_i					<= '1';

						NextState						<= ST_DATAFLOW;
					else
						In_S2M.Ready							<= '1';

						NextState						<= ST_DISCARD_FRAME;
					end if;
				end if;

			when ST_DATAFLOW =>
				In_S2M.Ready						<= In_Ack_i;
				Out_Valid_i							<= In_M2S.Valid;
				ChannelPointer					<= ChannelPointer_d;

				if (Is_EOF = '1') then
					NextState							<= ST_IDLE;
				end if;

			when ST_DISCARD_FRAME =>
				In_S2M.Ready						<= '1';

				if (Is_EOF = '1') then
					NextState							<= ST_IDLE;
				end if;
		end case;
	end process;


	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or ChannelPointer_rst) = '1') then
				ChannelPointer_d		<= (others => '0');
			elsif (ChannelPointer_en = '1') then
				ChannelPointer_d		<= DeMuxControl;
			end if;
		end if;
	end process;

	genOutput : for i in 0 to PORTS - 1 generate
		Out_M2S(i).Valid		<= Out_Valid_i and ChannelPointer(i);
    Out_M2S(i).Data     <= In_M2S.Data;
    Out_M2S(i).User     <= In_M2S.User;
		Out_M2S(i).Last			<= In_M2S.Last;
	end generate;
end architecture;
