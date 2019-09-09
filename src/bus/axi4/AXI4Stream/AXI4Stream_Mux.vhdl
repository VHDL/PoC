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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.axi4stream.all;


entity AXI4Stream_Mux is
	generic (
		USE_CONTROL_VECTOR  : boolean   := FALSE;
		PORTS               : positive  := 2
	);
	port (
		Clock               : in  std_logic;
		Reset               : in  std_logic;
		-- Control interface
		MuxControl          : in  std_logic_vector;
		-- IN Port
		In_M2S              : in  T_AXI4STREAM_M2S_VECTOR(PORTS - 1 downto 0);
		In_S2M              : out T_AXI4STREAM_S2M_VECTOR(PORTS - 1 downto 0);
		-- OUT Ports
		Out_M2S             : out T_AXI4STREAM_M2S;
		Out_S2M             : in  T_AXI4STREAM_S2M
	);
end entity;


architecture rtl of AXI4Stream_Mux is
	constant DATA_BITS  : positive := In_M2S(0).Data'length;

	subtype T_CHANNEL_INDEX is natural range 0 to PORTS - 1;

	type T_STATE is (ST_IDLE, ST_DATAFLOW);

	signal State              : T_STATE := ST_IDLE;
	signal NextState          : T_STATE;

	signal FSM_Dataflow_en    : std_logic;

	signal RequestVector      : std_logic_vector(PORTS - 1 downto 0);
	signal RequestWithSelf    : std_logic;
	signal RequestWithoutSelf : std_logic;

	signal RequestLeft        : unsigned(PORTS - 1 downto 0);
	signal SelectLeft         : unsigned(PORTS - 1 downto 0);
	signal SelectRight        : unsigned(PORTS - 1 downto 0);

	signal ChannelPointer_en  : std_logic;
	signal ChannelPointer     : std_logic_vector(PORTS - 1 downto 0);
	signal ChannelPointer_d   : std_logic_vector(PORTS - 1 downto 0) := to_slv(2 ** (PORTS - 1), PORTS);
	signal ChannelPointer_nxt : std_logic_vector(PORTS - 1 downto 0);
	signal ChannelPointer_bin : unsigned(log2ceilnz(PORTS) - 1 downto 0);

	signal idx                : T_CHANNEL_INDEX;

	signal Out_Last_i         : std_logic;

begin
	assert (USE_CONTROL_VECTOR and (MuxControl'length = PORTS))
		report "'MuxControl' needs to provide PORTS-many bits (one-hot-encoding)."
		severity FAILURE;

	RequestWithSelf    <= slv_or(RequestVector);
	RequestWithoutSelf <= slv_or(RequestVector and not ChannelPointer_d);

	mapping_gen : for i in 0 to PORTS -1 generate
		RequestVector(i)  <= In_M2S(i).Valid and (MuxControl(i) or not to_sl(USE_CONTROL_VECTOR));
		In_S2M(i).Ready   <= (Out_S2M.Ready  and FSM_Dataflow_en) and ChannelPointer(i);
	end generate;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State <= ST_IDLE;
			else
				State <= NextState;
			end if;
		end if;
	end process;

	process(State, RequestWithSelf, RequestWithoutSelf, Out_S2M.Ready, Out_Last_i, ChannelPointer_d, ChannelPointer_nxt)
	begin
		NextState         <= State;

		FSM_Dataflow_en   <= '0';

		ChannelPointer_en <= '0';
		ChannelPointer    <= ChannelPointer_d;

		case State is
			when ST_IDLE =>
				if (RequestWithSelf = '1') then
					ChannelPointer_en  <= '1';
					NextState          <= ST_DATAFLOW;
				end if;

			when ST_DATAFLOW =>
				FSM_Dataflow_en <= '1';
				if ((Out_S2M.Ready and Out_Last_i) = '1') then
					if (RequestWithoutSelf = '0') then
						NextState         <= ST_IDLE;
					else
						ChannelPointer_en <= '1';
					end if;
				end if;
		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				ChannelPointer_d <= to_slv(2 ** (PORTS - 1), PORTS);
			elsif (ChannelPointer_en = '1') then
				ChannelPointer_d <= ChannelPointer_nxt;
			end if;
		end if;
	end process;

	RequestLeft            <= (not ((unsigned(ChannelPointer_d) - 1) or unsigned(ChannelPointer_d))) and unsigned(RequestVector);
	SelectLeft             <= (unsigned(not RequestLeft) + 1) and RequestLeft;
	SelectRight            <= (unsigned(not RequestVector) + 1)	and unsigned(RequestVector);
	ChannelPointer_nxt     <= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));

	ChannelPointer_bin     <= onehot2bin(ChannelPointer);
	idx                    <= to_integer(ChannelPointer_bin);

	Out_M2S.Data           <= In_M2S(idx).Data;
	Out_M2S.User           <= In_M2S(idx).User;

	Out_Last_i             <= In_M2S(to_integer(ChannelPointer_bin)).Last;

	Out_M2S.Valid          <= In_M2S(to_integer(ChannelPointer_bin)).Valid and FSM_Dataflow_en;
	Out_M2S.Last           <= Out_Last_i;
end architecture;
