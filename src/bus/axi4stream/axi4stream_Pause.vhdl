-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--                  Max Kraft-Kugler
--
-- Entity:          A generic AXI4-Stream module to pause a stream.
--
-- Description:
-- -------------------------------------
-- Applying a '1' to Pause input stops the stream. By enabling PACKET_MODE the
-- stream is only paused outside of a packet. If Pause is released for one
-- clock-cycle, the next whole packet is flowing through.
-- Flags 'In_Packet', 'Data_Available' and 'Data_Blocked' are only used in
-- PACKET_MODE.
--
-- License:
-- =============================================================================
-- Copyright 2024-2026 The PoC-Library Authors
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.axi4stream.all;


entity axi4stream_Pause is
	generic (
		PACKET_MODE         : boolean := false
	);
	port (
		Clock               : in  std_logic := '0';
		Reset               : in  std_logic := '0';
		-- Control Signal
		Pause               : in  std_logic;
		In_Packet           : out std_logic;
		Data_Available      : out std_logic;
		Data_Blocked        : out std_logic;
		-- IN AXIS Port
		In_M2S              : in  T_AXI4STREAM_M2S;
		In_S2M              : out T_AXI4STREAM_S2M;
		-- OUT AXIS Port
		Out_M2S             : out T_AXI4STREAM_M2S;
		Out_S2M             : in  T_AXI4STREAM_S2M
	);
end entity;


architecture rtl of axi4stream_Pause is

	signal Pause_internal : std_logic;

begin

	gen_SM : if PACKET_MODE generate

		signal is_transaction   : boolean;     -- FIXME: no boolean usage in synthesis
		signal is_packet_end    : boolean;

		type T_PACKET_STATE is (ST_IDLE, ST_IN_PACKET);
		signal pause_state      : T_PACKET_STATE;
		signal pause_state_next : T_PACKET_STATE;
	begin

		is_transaction <= (In_M2S.Valid and In_S2M.Ready) = '1';
		is_packet_end  <= In_M2S.Last = '1';

		process(all)
		begin
			pause_state_next <= pause_state;
			Pause_internal   <= '0';
			In_Packet        <= '0';
			case pause_state is
				when ST_IDLE =>
					Pause_internal <= Pause;
					if (is_transaction and not is_packet_end) then
						In_Packet        <= '1';
						pause_state_next <= ST_IN_PACKET;
					end if;

				when ST_IN_PACKET =>
					In_Packet        <= '1';
					if (is_transaction and is_packet_end) then
						In_Packet        <= '0';
						pause_state_next <= ST_IDLE;
					end if;
			end case;
		end process;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if(Reset = '1') then
					pause_state <= ST_IDLE;
				else
					pause_state <= pause_state_next;
				end if;
			end if;
		end process;

	else generate

		Pause_internal <= Pause;

	end generate;

	Data_Available <= In_M2S.Valid;
	Data_Blocked   <= Pause_internal;

	Out_M2S.Valid  <= In_M2S.Valid and not Pause_internal;
	Out_M2S.Data   <= In_M2S.Data;
	Out_M2S.Keep   <= In_M2S.Keep;
	Out_M2S.Last   <= In_M2S.Last;
	Out_M2S.User   <= In_M2S.User;
	Out_M2S.Dest   <= In_M2S.Dest;
	Out_M2S.ID     <= In_M2S.ID;

	In_S2M.Ready   <= Out_S2M.Ready and not Pause_internal;

end architecture;
