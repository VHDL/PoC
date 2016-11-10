-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
--use			PoC.strings.all;
use			PoC.net.all;


entity eth_RSLayer_TRANS_SGMII_Virtex6_GTXE1 is
	port (
		Reset_async								: in	std_logic;																	-- @async:

		-- RS-GMII interface
		RS_TX_Clock								: in	std_logic;
		RS_TX_Valid								: in	std_logic;
		RS_TX_Data								: in	T_SLV_8;
		RS_TX_Error								: in	std_logic;

		RS_RX_Clock								: in	std_logic;
		RS_RX_Valid								: out	std_logic;
		RS_RX_Data								: out	T_SLV_8;
		RS_RX_Error								: out	std_logic;

		-- PHY-GMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_GMII
	);
end;

-- Note:
-- =============================================================================
-- use IDELAY instances on GMII_RX_Clock to move the clock into alignment with the data (GMII_RX_Data[7:0])

architecture rtl of eth_RSLayer_TRANS_SGMII_Virtex6_GTXE1 is
	signal IODelay_RX_Clock	: std_logic;

	signal IDelay_Data			: T_SLV_8;
	signal IDelay_Valid			: std_logic;
	signal IDelay_Error			: std_logic;
begin



end;
