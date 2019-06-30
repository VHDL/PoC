-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	A slave-side bus termination module for AXI4-Lite.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Lite that represents a
-- dummy slave.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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

use     work.axi4lite.all;


entity AXI4Lite_Termination_Slave is
	generic (
		VALUE         : std_logic := '0'
	);
	port ( 
		AXI4Lite_M2S  : in   T_AXI4Lite_Bus_M2S;
		AXI4Lite_S2M  : out  T_AXI4Lite_Bus_S2M
	);
end entity;


architecture rtl of AXI4Lite_Termination_Slave is
  constant AddrBits : natural := AXI4Lite_M2S.AWAddr'length;
  constant DataBits : natural := AXI4Lite_M2S.WData'length;
begin

	AXI4Lite_S2M <= Initialize_AXI4Lite_Bus_S2M(AddrBits, DataBits, VALUE);

end architecture;
