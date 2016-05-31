-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
USE			PoC.net.ALL;


ENTITY eth_RSLayer_TRANS_SGMII_Virtex6_GTXE1 IS
	PORT (
		Reset_async								: IN	STD_LOGIC;																	-- @async:

		-- RS-GMII interface
		RS_TX_Clock								: IN	STD_LOGIC;
		RS_TX_Valid								: IN	STD_LOGIC;
		RS_TX_Data								: IN	T_SLV_8;
		RS_TX_Error								: IN	STD_LOGIC;

		RS_RX_Clock								: IN	STD_LOGIC;
		RS_RX_Valid								: OUT	STD_LOGIC;
		RS_RX_Data								: OUT	T_SLV_8;
		RS_RX_Error								: OUT	STD_LOGIC;

		-- PHY-GMII interface
		PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_GMII
	);
END;

-- Note:
-- ============================================================================================================================================================
-- use IDELAY instances on GMII_RX_Clock to move the clock into alignment with the data (GMII_RX_Data[7:0])

ARCHITECTURE rtl OF eth_RSLayer_TRANS_SGMII_Virtex6_GTXE1 IS
	SIGNAL IODelay_RX_Clock	: STD_LOGIC;

	SIGNAL IDelay_Data			: T_SLV_8;
	SIGNAL IDelay_Valid			: STD_LOGIC;
	SIGNAL IDelay_Error			: STD_LOGIC;
BEGIN



END;
