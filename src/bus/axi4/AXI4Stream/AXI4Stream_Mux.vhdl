-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--                  Iqbal Asif
--
-- Entity:          A generic AXI4-Stream multiplexer.
--
-- Description:
-- -------------------------------------
-- The IP core module provides a multiplexing function between generic
-- AXI4 stream channel to one AXI4 stream channel.
-- Features
-- * Round Robin bus arbitration if the mux control is not enabled.
-- * index or port win value is append into MSB of destination signal if the
--   "APPEND_DEST_BITS" generic is enabled.
-- * For example, for 2 channel multiplexer if the data from channel 1 is
--   going through then MSB of Dest port will be "1". Size of Dest will be
--   increased by log2ceilnz(PORTS).
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.AXI4Stream.all;


entity AXI4Stream_Mux is
	generic (
		USE_CONTROL_VECTOR : boolean  := false;
		APPEND_DEST_BITS   : boolean  := false;
		PORTS              : positive := 2
	);
	port (
		Clock      : in  std_logic;
		Reset      : in  std_logic;
		-- Control interface
		MuxControl : in  std_logic_vector(PORTS - 1 downto 0) := (others => '1');
		-- IN Port
		In_M2S     : in  T_AXI4Stream_M2S_VECTOR(PORTS - 1 downto 0);
		In_S2M     : out T_AXI4Stream_S2M_VECTOR(PORTS - 1 downto 0);
		-- OUT Ports
		Out_M2S    : out T_AXI4Stream_M2S;
		Out_S2M    : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of AXI4Stream_Mux is

	subtype T_CHANNEL_INDEX is natural range 0 to PORTS - 1;

	type T_STATE is (ST_IDLE, ST_DATAFLOW);

	signal State     : T_STATE := ST_IDLE;
	signal NextState : T_STATE;

	signal FSM_Dataflow_en : std_logic;

	signal RequestVector      : std_logic_vector(PORTS - 1 downto 0);
	signal RequestWithSelf    : std_logic;
	signal RequestWithoutSelf : std_logic;

	signal RequestLeft : unsigned(PORTS - 1 downto 0);
	signal SelectLeft  : unsigned(PORTS - 1 downto 0);
	signal SelectRight : unsigned(PORTS - 1 downto 0);

	signal ChannelPointer_en  : std_logic;
	signal ChannelPointer     : std_logic_vector(PORTS - 1 downto 0);
	signal ChannelPointer_d   : std_logic_vector(PORTS - 1 downto 0) := to_slv(2 ** (PORTS - 1), PORTS);
	signal ChannelPointer_nxt : std_logic_vector(PORTS - 1 downto 0);
	signal ChannelPointer_bin : unsigned(log2ceilnz(PORTS) - 1 downto 0);

	signal idx : T_CHANNEL_INDEX;

	signal Out_Last_i : std_logic;

begin
	assert not USE_CONTROL_VECTOR or (MuxControl'length = PORTS)
		report "'MuxControl' needs to provide PORTS-many bits (one-hot-encoding)."
		severity failure;

	assert not APPEND_DEST_BITS or (Out_M2S.Dest'length = log2ceilnz(PORTS) + In_M2S(0).Dest'length)
		report "'Destination Length' needs to provide PORTS-many bits (one-hot-encoding) and first input stream Destination size."
		severity failure;

	RequestWithSelf    <= slv_or(RequestVector);
	RequestWithoutSelf <= slv_or(RequestVector and not ChannelPointer_d);

	genMapping : for i in 0 to PORTS -1 generate
		RequestVector(i) <= In_M2S(i).Valid and (MuxControl(i) or not to_sl(USE_CONTROL_VECTOR));
		In_S2M(i).Ready  <= (Out_S2M.Ready and FSM_Dataflow_en) and ChannelPointer(i);
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

	process(all)
	begin
		NextState <= State;

		FSM_Dataflow_en <= '0';

		ChannelPointer_en <= '0';
		ChannelPointer    <= ChannelPointer_d;

		case State is
			when ST_IDLE =>
				if (RequestWithSelf = '1') then
					ChannelPointer_en <= '1';
					NextState         <= ST_DATAFLOW;
				end if;

			when ST_DATAFLOW =>
				FSM_Dataflow_en <= '1';
				if ((Out_S2M.Ready and Out_Last_i) = '1') then
					if (RequestWithoutSelf = '0') then
						NextState <= ST_IDLE;
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

	RequestLeft        <= (not ((unsigned(ChannelPointer_d) - 1) or unsigned(ChannelPointer_d))) and unsigned(RequestVector);
	SelectLeft         <= (unsigned(not RequestLeft) + 1) and RequestLeft;
	SelectRight        <= (unsigned(not RequestVector) + 1) and unsigned(RequestVector);
	ChannelPointer_nxt <= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));

	ChannelPointer_bin <= onehot2bin(ChannelPointer);
	idx                <= to_integer(ChannelPointer_bin);

	Out_M2S.Data <= In_M2S(idx).Data;
	Out_M2S.User <= In_M2S(idx).User;
	Out_M2S.Keep <= In_M2S(idx).Keep;
	Out_M2S.ID   <= In_M2S(idx).ID;
	Out_M2S.Dest <= std_logic_vector(to_unsigned(idx, log2ceilnz(PORTS))) & In_M2S(idx).Dest when APPEND_DEST_BITS else In_M2S(idx).Dest; --NEW Destination ID for each new PORTS

	Out_Last_i <= In_M2S(idx).Last;

	Out_M2S.Valid <= In_M2S(idx).Valid and FSM_Dataflow_en;
	Out_M2S.Last  <= Out_Last_i;
end architecture;
