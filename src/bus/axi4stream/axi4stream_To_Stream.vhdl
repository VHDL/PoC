-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:          Converts an AXI4-Stream to PoC.Stream.
--
-- Description:
-- -------------------------------------
-- Converter module for AXI4-Stream to PoC.Stream.
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;

use     work.utils.all;
use     work.components.all;
use     work.stream.all;
use     work.axi4stream.all;
use     work.vectors.all;


entity axi4stream_To_Stream is
	generic (
		INCLUDE_ID        : boolean := false;
		INCLUDE_DEST      : boolean := false
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_axi4stream_M2S;
		In_S2M            : out T_axi4stream_S2M;
		-- OUT Port
		Out_M2S           : out T_Stream_M2S;
		Out_S2M           : in  T_Stream_S2M
	);
end entity;


architecture rtl of axi4stream_To_Stream is
	constant User_Pos         : natural  := 0;
	constant Dest_Pos         : natural  := 1;
	constant ID_Pos           : natural  := 2;

	constant Data_Bits_Vec  : natural_vector := (
		User_Pos       => In_M2S.User'length,
		Dest_Pos       => ite(INCLUDE_DEST, In_M2S.Dest'length, 0),
		ID_Pos         => ite(INCLUDE_ID,   In_M2S.ID'length, 0)
	);

	signal started : std_logic := '0';

begin
	started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.Last and Out_S2M.Ack) or Reset), set => (In_M2S.Valid and Out_S2M.Ack)) when rising_edge(Clock);

	Out_M2S.Valid   <= In_M2S.Valid;
	Out_M2S.BE      <= In_M2S.Keep;
	Out_M2S.Data    <= In_M2S.Data;
	Out_M2S.SOF     <= In_M2S.Valid and not started;
	Out_M2S.EOF     <= In_M2S.Last;

    User_gen: if In_M2S.User'length > 0 generate
        Out_M2S.Meta(high(Data_Bits_Vec, User_Pos  ) downto low(Data_Bits_Vec, User_Pos))  <= In_M2S.User;
    else generate
		-- WORKAROUND:
		--  Tool: NVC 1.15.x
		--  NVC doesn't support inference of others through unconstrained port of type record.
        Out_M2S.Meta(Out_M2S.Meta'range) <= (others => '0');
    end generate;
	Dest_gen : if INCLUDE_DEST generate
		Out_M2S.Meta(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos))  <= In_M2S.Dest;
	end generate;
	ID_gen : if INCLUDE_ID generate
		Out_M2S.Meta(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos))    <= In_M2S.ID;
	end generate;

	In_S2M.Ready    <= Out_S2M.Ack;
	In_S2M.User     <= Out_S2M.Meta;

end architecture;
