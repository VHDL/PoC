-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          A generic AXI4-Stream multiplexer.
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.axi4stream.all;


entity AXI4Stream_DeMux is
	generic (
		ADD_MIRROR_MODE     : boolean   := false;
		OUTPUT_STAGES       : natural   := 0;
		ENABLE_REVERSE_USER : boolean   := false
	);
	port (
		Clock               : in  std_logic;
		Reset               : in  std_logic;
		-- Control interface
		DeMuxControl        : in  std_logic_vector;
		-- IN Port
		In_M2S              : in  T_AXI4STREAM_M2S;
		In_S2M              : out T_AXI4STREAM_S2M;
		-- OUT Ports
		Out_M2S             : out T_AXI4STREAM_M2S_VECTOR;
		Out_S2M             : in  T_AXI4STREAM_S2M_VECTOR
	);
end entity;


architecture rtl of AXI4Stream_DeMux is
	constant PORTS              : positive := Out_M2S'length;

	type T_STATE is (ST_IDLE, ST_DATAFLOW, ST_DISCARD_FRAME);

	signal State                : T_STATE  := ST_IDLE;
	signal NextState            : T_STATE;

	signal Is_EOF               : std_logic;

	signal In_Ack_i             : std_logic;
	signal Out_Valid_i          : std_logic;
	signal DiscardFrame         : std_logic;

	signal ChannelPointer_en    : std_logic;
	signal ChannelPointer       : DeMuxControl'subtype;
	signal ChannelPointer_d     : DeMuxControl'subtype      := (others => '0');

	signal Out_Ready            : DeMuxControl'subtype;

	signal Valid_Mask_r         : DeMuxControl'subtype      := (others => '1');
	signal Out_M2S_d            : Out_M2S'subtype;
	signal Out_S2M_d            : Out_S2M'subtype;

begin
	assert (DeMuxControl'high = Out_M2S'high) and (DeMuxControl'low = Out_M2S'low)
		report "'MuxControl' and 'Out_M2S' needs to have same range(one-hot-encoding)."
		severity FAILURE;

	genAssign : for i in 0 to PORTS -1 generate
		Out_Ready(i)  <= Out_S2M_d(i).Ready;
	end generate;

	genMirror : if ADD_MIRROR_MODE generate
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Reset or In_Ack_i) = '1' then
					Valid_Mask_r    <= (others => '1');
				elsif Out_Valid_i = '1' then
					Valid_Mask_r    <= Valid_Mask_r and not Out_Ready;
				end if;
			end if;
		end process;

		In_Ack_i     <= slv_and(not Valid_Mask_r or (Out_Ready or not ChannelPointer));

	else generate

		Valid_Mask_r <= (others => '1');
		In_Ack_i     <= slv_or(Out_Ready  and ChannelPointer);
	end generate;

	DiscardFrame  <= slv_nor(DeMuxControl);

	Is_EOF      <= In_M2S.Valid and In_M2S.Last;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State       <= ST_IDLE;
			else
				State       <= NextState;
			end if;
		end if;
	end process;

	process(all)
	begin
		NextState                 <= State;

		ChannelPointer_en         <= '0';
		ChannelPointer            <= ChannelPointer_d;

		In_S2M.Ready              <= '0';
		Out_Valid_i               <= '0';

		case State is
			when ST_IDLE =>
				ChannelPointer          <= DeMuxControl;

				if (In_M2S.Valid = '1') then
					ChannelPointer_en   <= '1';

					if (DiscardFrame = '0') then
						In_S2M.Ready        <= In_Ack_i;
						Out_Valid_i         <= '1';

						if ((Is_EOF and In_Ack_i) = '1') then
							NextState         <= ST_IDLE;
						else
							NextState         <= ST_DATAFLOW;
						end if;
					else
						In_S2M.Ready        <= '1';

						if (Is_EOF = '1') then
							NextState         <= ST_IDLE;
						else
							NextState         <= ST_DISCARD_FRAME;
						end if;
					end if;
				end if;

			when ST_DATAFLOW =>
				In_S2M.Ready            <= In_Ack_i;
				Out_Valid_i             <= In_M2S.Valid;

				if ((Is_EOF and In_Ack_i) = '1') then
					NextState             <= ST_IDLE;
				end if;

			when ST_DISCARD_FRAME =>
				In_S2M.Ready            <= '1';

				if (Is_EOF = '1') then
					NextState             <= ST_IDLE;
				end if;
		end case;
	end process;

	ChannelPointer_d    <= DeMuxControl when rising_edge(Clock) and ChannelPointer_en = '1';

	genReverseUser : if ENABLE_REVERSE_USER generate
		In_S2M.User         <= Out_S2M_d(lssb_idx(ChannelPointer)).User;
	end generate;

	genOutput : for i in 0 to PORTS - 1 generate
		Out_M2S_d(i).Valid    <= Out_Valid_i and ChannelPointer(i) and Valid_Mask_r(i);
		Out_M2S_d(i).Data     <= In_M2S.Data;
		Out_M2S_d(i).Keep     <= In_M2S.Keep;
		Out_M2S_d(i).User     <= In_M2S.User;
		Out_M2S_d(i).Dest     <= In_M2S.Dest;
		Out_M2S_d(i).ID       <= In_M2S.ID;
		Out_M2S_d(i).Last     <= In_M2S.Last;

		OutStage : entity work.AXI4Stream_stage
		generic map(
			STAGES            => OUTPUT_STAGES
		)
		port map(
			Clock             => Clock,
			Reset             => Reset,
			-- IN Port
			In_M2S            => Out_M2S_d(i),
			In_S2M            => Out_S2M_d(i),
			-- OUT Port
			Out_M2S           => Out_M2S(i),
			Out_S2M           => Out_S2M(i)
		);
	end generate;
end architecture;
