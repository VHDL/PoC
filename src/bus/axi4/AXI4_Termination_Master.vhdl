-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:				 	A master-side bus termination module for AXI4 (full).
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4 (full) that represents a
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

use     work.axi4_full.all;


entity AXI4_Termination_Master is
	generic (
		VALUE     : std_logic := '0'
	);
	port ( 
		AXI4_M2S  : out T_AXI4_Bus_M2S;
		AXI4_S2M  : in  T_AXI4_Bus_S2M
	);
end entity;

architecture rtl of AXI4_Termination_Master is
	constant AddrBits : natural := AXI4_M2S.AWAddr'length;
	constant IDBits   : natural := AXI4_M2S.AWID'length;
	constant UserBits : natural := AXI4_M2S.AWUser'length;
	constant DataBits : natural := AXI4_M2S.WData'length;
begin

	AXI4_M2S <= Initialize_AXI4_Bus_M2S(AddrBits, DataBits, UserBits, IDBits, VALUE);

end architecture;
