-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:          A slave-side bus termination module for AXI4-Stream.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Stream that represents a
-- dummy slave.
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
use     work.axi4stream.all;


entity axi4stream_Termination_Subordinate is
	generic (
		VALUE     : std_logic := '0'
	);
	port (
		-- IN Port
		In_M2S    : in  T_AXI4Stream_M2S;
		In_S2M    : out T_AXI4Stream_S2M
	);
end entity;


architecture rtl of axi4stream_Termination_Subordinate is
  constant DataBits : natural := In_M2S.Data'length;
  constant UserBits : natural := In_M2S.User'length;
begin

	In_S2M <= Initialize_AXI4Stream_S2M(UserBits, VALUE);

end architecture;
