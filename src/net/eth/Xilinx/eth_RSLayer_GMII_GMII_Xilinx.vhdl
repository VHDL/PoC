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
use			PoC.net.all;
--use			PoC.net_comp.all;


entity eth_RSLayer_GMII_GMII_Xilinx is
	port (
		Reset_async								: in		std_logic;			-- @async:
		
		-- RS-GMII interface
		RS_TX_Clock								: in		std_logic;
		RS_TX_Valid								: in		std_logic;
		RS_TX_Data								: in		T_SLV_8;
		RS_TX_Error								: in		std_logic;
		
		RS_RX_Clock								: in		std_logic;
		RS_RX_Valid								: out		std_logic;
		RS_RX_Data								: out		T_SLV_8;
		RS_RX_Error								: out		std_logic;
		
		-- PHY-GMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_GMII := C_NET_ETH_PHY_INTERFACE_GMII_INIT
	);
end entity;

-- Note:
-- =============================================================================
-- use IDELAY instances on GMII_RX_Clock to move the clock into alignment with the data (GMII_RX_Data[7:0])

architecture rtl of eth_RSLayer_GMII_GMII_Xilinx is
	attribute KEEP												: boolean;
	
	signal IODelay_RX_Clock								: std_logic;
	attribute KEEP of IODelay_RX_Clock		: signal is TRUE;
	
	signal IDelay_Data										: T_SLV_8;
	signal IDelay_Valid										: std_logic;
	signal IDelay_Error										: std_logic;
begin
	-- Transmitter Clock
	-- ==========================================================================================================================================================
	-- Instantiate a DDR output register.  This is a good way to drive
	-- GMII_TX_Clock since the clock-to-PAD delay will be the same as that for
	-- data driven from IOB Ouput flip-flops eg GMII_TX_Data[7:0].
  TX_Clock_ODDR : ODDR
		port map (
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
		generic map (
			IDELAY_TYPE			=> "FIXED",
			IDELAY_VALUE		=> 0,
			DELAY_SRC				=> "I",
			SIGNAL_PATTERN	=> "CLOCK"
		)
		port map (
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
		port map (
			I								=> IODelay_RX_Clock,
			O								=> PHY_Interface.RX_RefClock
		);
		
	-- Output Logic : Drive TX signals through IOBs onto PHY-GMII interface
	-- ==========================================================================================================================================================
	process(RS_TX_Clock, Reset_async)
  begin
		if (Reset_async = '1') then
			PHY_Interface.TX_Data				<= (others => '0');
			PHY_Interface.TX_Valid			<= '0';
			PHY_Interface.TX_Error			<= '0';
		else
			if rising_edge(RS_TX_Clock) then
				PHY_Interface.TX_Data			<= RS_TX_Data;
				PHY_Interface.TX_Valid		<= RS_TX_Valid;
				PHY_Interface.TX_Error		<= RS_TX_Error;
			end if;
		end if;
	end process;
	
	-- Input Logic : Receive RX signals through IDELAYs and IOBs from PHY-GMII interface
	-- ==========================================================================================================================================================
	blkIDelay : block
		constant RX_VALID_BIT		: natural													:= 8;
		constant RX_ERROR_BIT		: natural													:= 9;
		
		signal IDelay_DataIn		: std_logic_vector(9 downto 0);
		signal IDelay_DataOut		: std_logic_vector(9 downto 0);
	begin
		IDelay_DataIn(PHY_Interface.RX_Data'range)	<= PHY_Interface.RX_Data;
		IDelay_DataIn(RX_VALID_BIT)									<= PHY_Interface.RX_Valid;
		IDelay_DataIn(RX_ERROR_BIT)									<= PHY_Interface.RX_Error;
		
		genIDelay : for i in IDelay_DataIn'reverse_range generate
			dly : IDELAY
				generic map (
					IOBDELAY_TYPE		=> "FIXED",
					IOBDELAY_VALUE	=> 0
				)
				port map (
					I								=> IDelay_DataIn(i),
					O								=> IDelay_DataOut(i),
					C								=> '0',
					CE							=> '0',
					INC							=> '0',
					RST							=> '0'
				);
		end generate;
		
		IDelay_Data				<= IDelay_DataOut(IDelay_Data'range);
		IDelay_Valid			<= IDelay_DataOut(RX_VALID_BIT);
		IDelay_Error			<= IDelay_DataOut(RX_ERROR_BIT);
	end block;
	
	process(RS_RX_Clock, Reset_async)
	begin
		if (Reset_async = '1') then
			RS_RX_Data			<= (others => '0');
			RS_RX_Valid			<= '0';
			RS_RX_Error			<= '0';
		else
			if rising_edge(RS_RX_Clock) then
				RS_RX_Data		<= IDelay_Data;
				RS_RX_Valid		<= IDelay_Valid;
				RS_RX_Error		<= IDelay_Error;
			end if;
		end if;
	end process;
end architecture;
