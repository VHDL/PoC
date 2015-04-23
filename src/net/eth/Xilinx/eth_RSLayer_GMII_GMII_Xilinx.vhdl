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
USE			PoC.net.ALL;


ENTITY eth_RSLayer_GMII_GMII_Xilinx IS
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

ARCHITECTURE rtl OF eth_RSLayer_GMII_GMII_Xilinx IS
	ATTRIBUTE KEEP												: BOOLEAN;
	
	SIGNAL IODelay_RX_Clock								: STD_LOGIC;
	ATTRIBUTE KEEP OF IODelay_RX_Clock		: SIGNAL IS TRUE;
	
	SIGNAL IDelay_Data										: T_SLV_8;
	SIGNAL IDelay_Valid										: STD_LOGIC;
	SIGNAL IDelay_Error										: STD_LOGIC;
BEGIN
	-- Transmitter Clock
	-- ==========================================================================================================================================================
	-- Instantiate a DDR output register.  This is a good way to drive
	-- GMII_TX_Clock since the clock-to-PAD delay will be the same as that for
	-- data driven from IOB Ouput flip-flops eg GMII_TX_Data[7:0].
  TX_Clock_ODDR : ODDR
		PORT MAP (
			Q		=> PHY_Interface.TX_Clock,
			C		=> RS_TX_Clock,
			CE	=> '1',
			D1	=> '0',
			D2	=> '1',
			R		=> Reset_async,
			S		=> '0'
  );

	-- Receiver Clock
	-- ==========================================================================================================================================================
	-- please modify the value of the IOBDELAYs according to your design.
	-- for more information on IDELAYCTRL and IODELAY, please refer to the Virtex-5 User Guide.
	IODly_RX_Clock : IODELAY
		GENERIC MAP (
			IDELAY_TYPE			=> "FIXED",
			IDELAY_VALUE		=> 0,
			DELAY_SRC				=> "I",
			SIGNAL_PATTERN	=> "CLOCK"
		)
		PORT MAP (
			IDATAIN					=> PHY_Interface.RX_Clock,
			ODATAIN					=> '0',
			DATAOUT					=> IODelay_RX_Clock,
			DATAIN					=> '0',
			C								=> '0',
			T								=> '0',
			CE							=> '0',
			INC							=> '0',
			RST							=> '0'
		);
		
	BUFG_RX_Clock : BUFG
		PORT MAP (
			I								=> IODelay_RX_Clock,
			O								=> PHY_Interface.RX_RefClock
		);
	
	-- Output Logic : Drive TX signals through IOBs onto PHY-GMII interface	
	-- ==========================================================================================================================================================
	PROCESS(RS_TX_Clock, Reset_async)
  BEGIN
		IF (Reset_async = '1') THEN
			PHY_Interface.TX_Data				<= (OTHERS => '0');
			PHY_Interface.TX_Valid			<= '0';
			PHY_Interface.TX_Error			<= '0';
		ELSE
			IF rising_edge(RS_TX_Clock) THEN
				PHY_Interface.TX_Data			<= RS_TX_Data;
				PHY_Interface.TX_Valid		<= RS_TX_Valid;
				PHY_Interface.TX_Error		<= RS_TX_Error;
			END IF;
		END IF;
	END PROCESS;
	
	-- Input Logic : Receive RX signals through IDELAYs and IOBs from PHY-GMII interface	
	-- ==========================================================================================================================================================
	blkIDelay : BLOCK
		CONSTANT RX_VALID_BIT		: NATURAL													:= 8;
		CONSTANT RX_ERROR_BIT		: NATURAL													:= 9;
	
		SIGNAL IDelay_DataIn		: STD_LOGIC_VECTOR(9 DOWNTO 0);
		SIGNAL IDelay_DataOut		: STD_LOGIC_VECTOR(9 DOWNTO 0);
	BEGIN
		IDelay_DataIn(PHY_Interface.RX_Data'range)	<= PHY_Interface.RX_Data;
		IDelay_DataIn(RX_VALID_BIT)									<= PHY_Interface.RX_Valid;
		IDelay_DataIn(RX_ERROR_BIT)									<= PHY_Interface.RX_Error;
	
		genIDelay : FOR I IN IDelay_DataIn'reverse_range GENERATE
			dly : IDELAY
				GENERIC MAP (
					IOBDELAY_TYPE		=> "FIXED",
					IOBDELAY_VALUE	=> 0
				)
				PORT MAP (
					I								=> IDelay_DataIn(I),
					O								=> IDelay_DataOut(I),
					C								=> '0',
					CE							=> '0',
					INC							=> '0',
					RST							=> '0'
				);
		END GENERATE;
		
		IDelay_Data				<= IDelay_DataOut(IDelay_Data'range);
		IDelay_Valid			<= IDelay_DataOut(RX_VALID_BIT);
		IDelay_Error			<= IDelay_DataOut(RX_ERROR_BIT);
	END BLOCK;

	PROCESS(RS_RX_Clock, Reset_async)
	BEGIN
		IF (Reset_async = '1') THEN
			RS_RX_Data			<= (OTHERS => '0');
			RS_RX_Valid			<= '0';
			RS_RX_Error			<= '0';
		ELSE
			IF rising_edge(RS_RX_Clock) THEN
				RS_RX_Data		<= IDelay_Data;
				RS_RX_Valid		<= IDelay_Valid;
				RS_RX_Error		<= IDelay_Error;
			END IF;
		END IF;
	END PROCESS;
END;
