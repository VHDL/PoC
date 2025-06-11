-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	A master-side bus termination module for AXI4-Lite.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Lite that represents a
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

use     work.axi4lite.all;


entity AXI4Lite_Termination_Master is
	generic (
		VALUE         : std_logic := '0'
	);
	port ( 
		AXI4Lite_M2S  : out T_AXI4Lite_Bus_M2S;
		AXI4Lite_S2M  : in  T_AXI4Lite_Bus_S2M
	);
end entity;


architecture rtl of AXI4Lite_Termination_Master is
	constant AddrBits : natural := AXI4Lite_M2S.AWAddr'length;
	constant DataBits : natural := AXI4Lite_M2S.WData'length;
begin

	AXI4Lite_M2S <= Initialize_AXI4Lite_Bus_M2S(AddrBits, DataBits, VALUE);

end architecture;
