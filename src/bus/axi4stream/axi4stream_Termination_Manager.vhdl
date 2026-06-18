-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:          A master-side bus termination module for AXI4-Stream.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Stream that represents a
-- dummy master.
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.axi4stream.all;


entity axi4stream_Termination_Manager is
	generic (
		VALUE     : std_logic := '0'
	);
	port (
		-- OUT Port
		Out_M2S   : out T_AXI4Stream_M2S;
		Out_S2M   : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of axi4stream_Termination_Manager is
	constant DataBits : natural := Out_M2S.Data'length;
	constant UserBits : natural := Out_M2S.User'length;
	constant DestBits : natural := Out_M2S.Dest'length;
	constant IDBits   : natural := Out_M2S.ID'length;
begin

	Out_M2S <= Initialize_AXI4Stream_M2S(DataBits, UserBits, DestBits, IDBits, VALUE);

end architecture;
