-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Stefan Unrein
--									Max Kraft-Kugler
--									Patrick Lehmann
--									Iqbal Asif
--
-- Package:					TBD
--
-- Description:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

use     work.config.all;
use     work.utils.all;
use     work.components.all;
use     work.vectors.all;
use     work.stream.all;
use     work.AXI4Stream.all;


entity Stream_To_AXI4Stream is
	generic (
		INCLUDE_ID        : boolean := false;
		INCLUDE_DEST      : boolean := false
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_Stream_M2S;
		In_S2M            : out T_Stream_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of Stream_To_AXI4Stream is
	constant User_Pos         : natural  := 0;
	constant Dest_Pos         : natural  := 1;
	constant ID_Pos           : natural  := 2;
	
	constant Data_Bits_Vec  : natural_vector := (
		User_Pos       => Out_M2S.User'length,
		Dest_Pos       => ite(INCLUDE_DEST, Out_M2S.Dest'length, 0),
		ID_Pos         => ite(INCLUDE_ID,   Out_M2S.ID'length, 0)
	);
	
	signal started : std_logic := '0';

begin

	started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.EOF and Out_S2M.Ready) or Reset), set => (In_M2S.Valid and In_M2S.SOF)) when rising_edge(Clock);

	Out_M2S.Valid <= In_M2S.Valid and (started or In_M2S.SOF);
	Out_M2S.Data  <= In_M2S.Data;
	-- WORKAROUND:
	--  Tool: NVC 1.15.x
	--  NVC doesn't support inference of others through unconstrained port of type record.
	Out_M2S.Keep(Out_M2S.Keep'range)  <= (others => '1') when In_M2S.EOF = '0' else In_M2S.BE;
	Out_M2S.Last  <= In_M2S.EOF;
	

    User_gen: if In_M2S.Meta'length > 0 generate
        Out_M2S.User <= In_M2S.Meta(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos));
    else generate
		-- WORKAROUND:
		--  Tool: NVC 1.15.x
		--  NVC doesn't support inference of others through unconstrained port of type record.
        Out_M2S.User(Out_M2S.User'range) <= (others => '0');
    end generate;
	Dest_gen : if INCLUDE_DEST generate
		Out_M2S.Dest <= In_M2S.Meta(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos));
	end generate;
	ID_gen : if INCLUDE_ID generate
		Out_M2S.ID   <= In_M2S.Meta(high(Data_Bits_Vec, ID_Pos) downto low(Data_Bits_Vec, ID_Pos));
	end generate;
	
	In_S2M.Ack    <= Out_S2M.Ready;
	In_S2M.Meta   <= Out_S2M.User;

end architecture;
