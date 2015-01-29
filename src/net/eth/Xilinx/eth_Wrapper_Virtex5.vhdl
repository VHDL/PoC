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


ENTITY eth_Wrapper_Virtex5 IS
	GENERIC (
		DEBUG											: BOOLEAN														:= FALSE;															-- 
		CLOCK_FREQ_MHZ						: REAL															:= 125.0;															-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											-- 
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		-- 
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		-- 
	);
	PORT (
		-- clock interface
		RS_TX_Clock								: IN	STD_LOGIC;
		RS_RX_Clock								: IN	STD_LOGIC;
		Eth_TX_Clock							: IN	STD_LOGIC;
		Eth_RX_Clock							: IN	STD_LOGIC;
		TX_Clock									: IN	STD_LOGIC;
		RX_Clock									: IN	STD_LOGIC;

		-- reset interface
		Reset											: IN	STD_LOGIC;
		
		-- Command-Status-Error interface
		
		-- MAC LocalLink interface
		TX_Valid									: IN	STD_LOGIC;
		TX_Data										: IN	T_SLV_8;
		TX_SOF										: IN	STD_LOGIC;
		TX_EOF										: IN	STD_LOGIC;
		TX_Ack										: OUT	STD_LOGIC;

		RX_Valid									: OUT	STD_LOGIC;
		RX_Data										: OUT	T_SLV_8;
		RX_SOF										: OUT	STD_LOGIC;
		RX_EOF										: OUT	STD_LOGIC;
		RX_Ack										: In	STD_LOGIC;
		
		PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
	);
END ENTITY;

-- Structure
-- ============================================================================================================================================================
-- 	genHardIP
--		o	TX_FIFO				- HardIP <=> LocalLink converter; cross clocking
--		o	RX_FIFO				- HardIP <=> LocalLink converter; cross clocking
--		genRS_GMII
--			o	TEMAC_V5		- with GMII interface
--			genPHY_GMII
--				o	GMII			- GMII-GMII adapter; FlipFlop and IDelay instances
--			genPHY_SGMII
--				o	SGMII			- GMII-SGMII adapter; transceiver
--		genRS_TRANS
--			o	TEMAC_V5		- with Transceiver interface (GTP_DUAL)
--			genPHY_TRANS
--				o	TRANS			- Transceiver with SGMII output
--	genSoftIP
--		o	GEMAC					- Gigabit MAC_MDIOC MAC (GEMAC) SoftCore with GMII interface
--		genPHY_GMII
--			o	GMII				- GMII-GMII adapter; FlipFlop and IDelay instances
--		genPHY_SGMII
--			o	SGMII				- GMII-SGMII adapter; transceiver

-- +------------+---------------+---------------+---------------------------------------+
-- |	IP-Style	|	RS-Interface	|	PHY-Interface	|	status / comment											|
-- +------------+---------------+---------------+---------------------------------------+
-- |	HardIP		|			GMII			|			GMII			|	OK	tested; working as expected				|
-- |		"				|			GMII			|			SGMII			|			under development									|
-- |		"				|			TRANS			|			SGMII			|			not implemented, yet							|
-- |------------+---------------+---------------+---------------------------------------+
-- |	SoftIP		|			GMII			|			GMII			|	OK	tested; working as expected				|
-- |		"				|			GMII			|			SGMII			|			not implemented, yet							|
-- +------------+---------------+---------------+---------------------------------------+

ARCHITECTURE rtl OF eth_Wrapper_Virtex5 IS
	ATTRIBUTE KEEP									: BOOLEAN;

	SIGNAL Reset_async							: STD_LOGIC;		-- FIXME: 

	SIGNAL TX_Reset									: STD_LOGIC;		-- FIXME: 
	SIGNAL RX_Reset									: STD_LOGIC;		-- FIXME: 

BEGIN
	
	-- XXX: review reset-tree and clock distribution
	Reset_async		<= Reset;
	
	-- ==========================================================================================================================================================
	-- Xilinx Virtex 5 Tri-Mode MAC_MDIOC MAC (TEMAC) HardIP
	-- ==========================================================================================================================================================
	genHardIP	: IF (ETHERNET_IPSTYLE = IPSTYLE_HARD) GENERATE
		SIGNAL TX_FIFO_Data						: T_SLV_8;
		SIGNAL TX_FIFO_Valid					: STD_LOGIC;
		SIGNAL TX_FIFO_Overflow				: STD_LOGIC;
		SIGNAL TX_FIFO_Status					: STD_LOGIC_VECTOR(3 DOWNTO 0);
		
		SIGNAL RX_FIFO_Overflow				: STD_LOGIC;
		SIGNAL RX_FIFO_Status					: STD_LOGIC_VECTOR(3 DOWNTO 0);
				
		SIGNAL Eth_TX_Reset						: STD_LOGIC;
		SIGNAL Eth_TX_Enable					: STD_LOGIC;
		SIGNAL Eth_TX_Ack							: STD_LOGIC;
		SIGNAL Eth_TX_Collision				: STD_LOGIC;
		SIGNAL Eth_TX_Retransmit			: STD_LOGIC;

		SIGNAL Eth_RX_Reset						: STD_LOGIC;		
		SIGNAL Eth_RX_Enable					: STD_LOGIC;
		
		SIGNAL Eth_RX_Data						: T_SLV_8;
		SIGNAL Eth_RX_Data_r					: T_SLV_8								:= (OTHERS	=> '0');
		SIGNAL Eth_RX_Valid						: STD_LOGIC;
		SIGNAL Eth_RX_Valid_r					: STD_LOGIC							:= '0';
		SIGNAL Eth_RX_GoodFrame				: STD_LOGIC;
		SIGNAL Eth_RX_GoodFrame_r			: STD_LOGIC							:= '0';
		SIGNAL Eth_RX_BadFrame				: STD_LOGIC;
		SIGNAL Eth_RX_BadFrame_r			: STD_LOGIC							:= '0';
		
		
	BEGIN
		genReset	: BLOCK
			SIGNAL TX_Reset_shift				: T_SLV_8;
			SIGNAL RX_Reset_shift				: T_SLV_8;
			
			SIGNAL Eth_TX_Reset_shift		: T_SLV_8;
			SIGNAL Eth_RX_Reset_shift		: T_SLV_8;
			
			ATTRIBUTE async_reg												: BOOLEAN;
			ATTRIBUTE async_reg OF TX_Reset_shift			: SIGNAL IS TRUE;
			ATTRIBUTE async_reg OF RX_Reset_shift			: SIGNAL IS TRUE;
			
			ATTRIBUTE async_reg OF Eth_TX_Reset_shift	: SIGNAL IS TRUE;
			ATTRIBUTE async_reg OF Eth_RX_Reset_shift	: SIGNAL IS TRUE;

		BEGIN
			-- Create synchronous reset in the transmitter clock domain.
			PROCESS(TX_Clock, Reset_async)
			BEGIN
				IF (Reset_async = '1') THEN
					TX_Reset_shift				<= (OTHERS	=> '1');
				ELSIF rising_edge(TX_Clock) THEN
					TX_Reset_shift				<= TX_Reset_shift(TX_Reset_shift'high - 1 DOWNTO 0) & '0';
				END IF;
			END PROCESS;

			-- Create synchronous reset in the receiver clock domain.
			PROCESS(RX_Clock, Reset_async)
			BEGIN
				IF (Reset_async = '1') THEN
					RX_Reset_shift				<= (OTHERS	=> '1');
				ELSIF rising_edge(RX_Clock) THEN
					RX_Reset_shift				<= RX_Reset_shift(RX_Reset_shift'high - 1 DOWNTO 0) & '0';
				END IF;
			END PROCESS;

			-- Create synchronous reset in the transmitter clock domain.
			PROCESS(Eth_TX_Clock, Reset_async)
			BEGIN
				IF (Reset_async = '1') THEN
					Eth_TX_Reset_shift		<= (OTHERS	=> '1');
				ELSIF rising_edge(Eth_TX_Clock) THEN
					Eth_TX_Reset_shift		<= Eth_TX_Reset_shift(Eth_TX_Reset_shift'high - 1 DOWNTO 0) & '0';
				END IF;
			END PROCESS;

			-- Create synchronous reset in the receiver clock domain.
			PROCESS(Eth_RX_Clock, Reset_async)
			BEGIN
				IF (Reset_async = '1') THEN
					Eth_RX_Reset_shift		<= (OTHERS	=> '1');
				ELSIF rising_edge(Eth_RX_Clock) THEN
					Eth_RX_Reset_shift		<= Eth_RX_Reset_shift(Eth_RX_Reset_shift'high - 1 DOWNTO 0) & '0';
				END IF;
			END PROCESS;

			TX_Reset				<= TX_Reset_shift(TX_Reset_shift'high);
			RX_Reset				<= RX_Reset_shift(RX_Reset_shift'high);
			Eth_TX_Reset		<= Eth_TX_Reset_shift(Eth_TX_Reset_shift'high);
			Eth_RX_Reset		<= Eth_RX_Reset_shift(Eth_RX_Reset_shift'high);
		END BLOCK;

		blkFIFO	: BLOCK
			SIGNAL TX_Valid_n			: STD_LOGIC;
			SIGNAL TX_SOF_n				: STD_LOGIC;
			SIGNAL TX_EOF_n				: STD_LOGIC;
			SIGNAL TX_Ack	_n			: STD_LOGIC;

			SIGNAL RX_Valid_n			: STD_LOGIC;
			SIGNAL RX_SOF_n				: STD_LOGIC;
			SIGNAL RX_EOF_n				: STD_LOGIC;
			SIGNAL RX_Ack	_n			: STD_LOGIC;
		BEGIN
			-- convert LocalLink interface from low-active to high-active and vv.
			-- ========================================================================================================================================================
			TX_Valid_n		<= NOT TX_Valid;
			TX_SOF_n			<= NOT TX_SOF;
			TX_EOF_n			<= NOT TX_EOF;
			TX_Ack				<= NOT TX_Ack	_n;

			RX_Valid			<= NOT RX_Valid_n;
			RX_SOF				<= NOT RX_SOF_n;
			RX_EOF				<= NOT RX_EOF_n;
			RX_Ack	_n		<= NOT RX_Ack;

			Eth_TX_Enable					<= '1';
			Eth_RX_Enable					<= '1';

			-- Transmitter FIFO and LocalLink adapter
			TX_FIFO	: ENTITY PoC.eth_TEMAC_TX_FIFO_Virtex5
				GENERIC MAP (
					FULL_DUPLEX_ONLY	=> FALSE--TRUE
				)
				PORT MAP (
					wr_clk						=> TX_Clock,								-- Local link write clock
					wr_sreset					=> TX_Reset,								-- synchronous reset (wr_clock)
					
					-- Transmitter Local Link Interface
					wr_data						=> TX_Data,									-- Data to TX FIFO
					wr_sof_n					=> TX_SOF_n,							
					wr_eof_n					=> TX_EOF_n,							
					wr_src_rdy_n			=> TX_Valid_n,						
					wr_dst_rdy_n			=> TX_Ack	_n,						
					wr_fifo_status		=> TX_FIFO_Status,					-- FIFO memory status

					-- Transmitter MAC Client Interface
					rd_clk						=> Eth_TX_Clock,						-- MAC transmit clock
					rd_sreset					=> Eth_TX_Reset,						-- Synchronous reset (rd_clk)
					rd_enable					=> Eth_TX_Enable,						-- Clock enable for rd_clk
					tx_data						=> TX_FIFO_Data,						-- Data to MAC transmitter
					tx_data_valid			=> TX_FIFO_Valid,						-- Valid signal to MAC transmitter
					tx_ack						=> Eth_TX_Ack,							-- Ack signal from MAC transmitter
					tx_collision			=> Eth_TX_Collision,				-- Collsion signal from MAC transmitter
					tx_retransmit			=> Eth_TX_Retransmit,				-- Retransmit signal from MAC transmitter
					overflow					=> TX_FIFO_Overflow					-- FIFO overflow indicator from FIFO
				);
			
			-- Receiver FIFO and LocalLink adapter
			RX_FIFO	: ENTITY PoC.eth_TEMAC_RX_FIFO_Virtex5
				PORT MAP (
					rd_clk						=> RX_Clock,								-- Local link read clock
					rd_sreset					=> RX_Reset,								-- synchronous reset (rd_clock)
					
					-- Receiver Local Link Interface
					rd_data_out				=> RX_Data,									-- Data from RX FIFO
					rd_sof_n					=> RX_SOF_n,						
					rd_eof_n					=> RX_EOF_n,						
					rd_src_rdy_n			=> RX_Valid_n,					
					rd_dst_rdy_n			=> RX_Ack	_n,					
					
					-- Receiver MAC Client Interface
					wr_clk						=> Eth_RX_Clock,						-- MAC receive clock
					wr_sreset					=> Eth_RX_Reset,						-- Synchronous reset (wr_clk)
					wr_enable					=> Eth_RX_Enable,						-- Clock enable for wr_clk
					rx_data						=> Eth_RX_Data_r,						-- Data from MAC receiver
					rx_data_valid			=> Eth_RX_Valid_r,					-- Valid signal from MAC receiver
					rx_good_frame			=> Eth_RX_GoodFrame_r,			-- Good frame indicator from MAC receiver
					rx_bad_frame			=> Eth_RX_BadFrame_r,				-- Bad frame indicator from MAC receiver
					overflow					=> RX_FIFO_Overflow,				-- FIFO overflow indicator from FIFO
					rx_fifo_status		=> RX_FIFO_Status						-- FIFO memory status [3:0]
				);
		END BLOCK;
	

		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: GMII
		-- ========================================================================================================================================================
		genRS_GMII	: IF (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_GMII) GENERATE
			-- RS-GMII interface
			SIGNAL RS_TX_Valid					: STD_LOGIC;
			SIGNAL RS_TX_Data						: T_SLV_8;
			SIGNAL RS_TX_Error					: STD_LOGIC;
				
			SIGNAL RS_RX_Valid					: STD_LOGIC;
			SIGNAL RS_RX_Data						: T_SLV_8;
			SIGNAL RS_RX_Error					: STD_LOGIC;
		BEGIN
			
			-- Instantiate the EMAC Wrapper (v5temac_gmii.vhd)
			TEMAC_V5	: ENTITY PoC.eth_TEMAC_GMII_Virtex5
				PORT MAP (
					-- Asynchronous Reset
					RESET														=> Reset_async,
					DCM_LOCKED_0										=> '1',														-- TODO: should this signals be connected to ClockNet/DCM_locked?
				
					-- Client Receiver Interface - EMAC0
					CLIENTEMAC0RXCLIENTCLKIN				=> Eth_RX_Clock,
					EMAC0CLIENTRXCLIENTCLKOUT				=> OPEN,													-- SOURCE: UG194, page 147
					
					EMAC0CLIENTRXD									=> Eth_RX_Data,
					EMAC0CLIENTRXDVLD								=> Eth_RX_Valid,
					EMAC0CLIENTRXDVLDMSW						=> OPEN,
					EMAC0CLIENTRXGOODFRAME					=> Eth_RX_GoodFrame,
					EMAC0CLIENTRXBADFRAME						=> Eth_RX_BadFrame,
					EMAC0CLIENTRXFRAMEDROP					=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATS							=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSVLD						=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSBYTEVLD				=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Client Transmitter Interface - EMAC0
					CLIENTEMAC0TXCLIENTCLKIN				=> Eth_TX_Clock,
					EMAC0CLIENTTXCLIENTCLKOUT				=> OPEN,
					
					CLIENTEMAC0TXD									=> TX_FIFO_Data,
					CLIENTEMAC0TXDVLD								=> TX_FIFO_Valid,
					CLIENTEMAC0TXDVLDMSW						=> '0',
					EMAC0CLIENTTXACK								=> Eth_TX_Ack,
					CLIENTEMAC0TXFIRSTBYTE					=> '0',														-- SOURCE: v5temac_gmii_locallink.vhd
					CLIENTEMAC0TXUNDERRUN						=> '0',														-- SOURCE: v5temac_client_eth_fifo_8.vhd
					EMAC0CLIENTTXCOLLISION					=> Eth_TX_Collision,
					EMAC0CLIENTTXRETRANSMIT					=> Eth_TX_Retransmit,
					CLIENTEMAC0TXIFGDELAY						=> (OTHERS	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATS							=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSVLD						=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSBYTEVLD				=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- MAC Control Interface - EMAC0
					CLIENTEMAC0PAUSEREQ							=> '0',														-- SOURCE: ml505_gmii_udp_top.vhdl
					CLIENTEMAC0PAUSEVAL							=> (OTHERS	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Clock Signals - EMAC0
					GTX_CLK_0												=> '0',														-- SOURCE: UG194, page 147

					EMAC0PHYTXGMIIMIICLKOUT					=> OPEN,													-- SOURCE: UG194, page 147
					PHYEMAC0TXGMIIMIICLKIN					=> RS_TX_Clock,

					-- GMII Interface - EMAC0
					GMII_TXD_0											=> RS_TX_Data,
					GMII_TX_EN_0										=> RS_TX_Valid,
					GMII_TX_ER_0										=> RS_TX_Error,

					GMII_RX_CLK_0										=> RS_RX_Clock,				
					GMII_RXD_0											=> RS_RX_Data,
					GMII_RX_DV_0										=> RS_RX_Valid,
					GMII_RX_ER_0										=> RS_RX_Error
				);
			
			-- default assignments for the MDIO interface
			-- FIXME: connect HardMacro TEMAC to MDIO Bus
--		PHY_Interface.MDIO.Clock_o
--			PHY_Interface.MDIO.Clock_o		<= '0';
--			PHY_Interface.MDIO.Clock_t		<= '1';
--		PHY_Interface.MDIO.Data_i
--			PHY_Interface.MDIO.Data_o			<= '0';
--			PHY_Interface.MDIO.Data_t			<= '1';
			
			-- Register the receiver outputs from TEMAC before routing to the FIFO
			-- ======================================================================================================================================================
			PROCESS(RX_Clock, Reset_async)
			BEGIN
				IF (Reset_async = '1') THEN
					Eth_RX_Data_r						<= (OTHERS	=> '0');
					Eth_RX_Valid_r					<= '0';
					Eth_RX_GoodFrame_r			<= '0';
					Eth_RX_BadFrame_r				<= '0';
				ELSE
					IF rising_edge(RX_Clock) THEN
						Eth_RX_Data_r					<= Eth_RX_Data;
						Eth_RX_Valid_r				<= Eth_RX_Valid;
						Eth_RX_GoodFrame_r		<= Eth_RX_GoodFrame;
						Eth_RX_BadFrame_r			<= Eth_RX_BadFrame;
					END IF;
				END IF;
			END PROCESS;
			
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: MII
			-- ========================================================================================================================================================
			genPHY_MII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_MII) GENERATE
				ASSERT FALSE REPORT "Physical interface MII is not supported!" SEVERITY FAILURE;
			END GENERATE;
			
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: GMII
			-- ========================================================================================================================================================
			genPHY_GMII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) GENERATE
				GMII	: ENTITY PoC.eth_RSLayer_GMII_GMII_Xilinx
					PORT MAP (
						RS_TX_Clock								=> RS_TX_Clock,
						RS_RX_Clock								=> RS_RX_Clock,
						
						Reset_async								=> Reset_async,																		-- @async: 
						
						-- RS-GMII interface
						RS_TX_Valid								=> RS_TX_Valid,
						RS_TX_Data								=> RS_TX_Data,
						RS_TX_Error								=> RS_TX_Error,
						
						RS_RX_Valid								=> RS_RX_Valid,
						RS_RX_Data								=> RS_RX_Data,
						RS_RX_Error								=> RS_RX_Error,
						
						-- PHY-GMII interface
						PHY_Interface							=> PHY_Interface.GMII
					);
			END GENERATE;		-- PHY_DATA_INTERFACE: GMII

			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII : IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) GENERATE
				-- RS-GMII interface
				SIGNAL RS_TX_Valid					: STD_LOGIC;
				SIGNAL RS_TX_Data						: T_SLV_8;
				SIGNAL RS_TX_Error					: STD_LOGIC;
					
				SIGNAL RS_RX_Valid					: STD_LOGIC;
				SIGNAL RS_RX_Data						: T_SLV_8;
				SIGNAL RS_RX_Error					: STD_LOGIC;
			BEGIN
				ASSERT FALSE REPORT "Physical interface SGMII is not implemented!" SEVERITY FAILURE;
			
--				SGMII	: ENTITY PoC.eth_RSLayer_GMII_SGMII_Virtex5
--		--			GENERIC MAP (
--		--				CLOCKIN_FREQ_MHZ					=> CLOCKIN_FREQ_MHZ					-- 125 MHz
--		--			)
--					PORT MAP (
--						Clock										=> RS_TX_Clock,
--						Reset										=> Reset_async,
--						
--						-- GEMAC-GMII interface
--						RS_TX_Clock							=> RS_TX_Clock,
--						RS_TX_Valid							=> RS_TX_Valid,
--						RS_TX_Data							=> RS_TX_Data,
--						RS_TX_Error							=> RS_TX_Error,
--						
--						RS_RX_Clock							=> RS_RX_Clock,
--						RS_RX_Valid							=> RS_RX_Valid,
--						RS_RX_Data							=> RS_RX_Data,
--						RS_RX_Error							=> RS_RX_Error
--					);
			END GENERATE;		-- PHY_DATA_INTERFACE: SGMII
		END GENERATE;		-- RS_DATA_INTERFACE: GMII
		
		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: TRANSCEIVER
		-- ========================================================================================================================================================
		genRS_TRANS	: IF (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_TRANSCEIVER) GENERATE
			-- Transceiver interface (TRANS) - EMAC0
			-- ------------------------------------------------------------------
			SIGNAL TEMAC_PowerDown										: STD_LOGIC;
			SIGNAL Trans_LoopBack_MSB									: STD_LOGIC;
			SIGNAL Trans_Interrupt										: STD_LOGIC;
			SIGNAL Trans_SignalDetect									: STD_LOGIC;
			
			-- TX signals
			SIGNAL Trans_TX_MGTReset									: STD_LOGIC;
			SIGNAL Trans_TX_Data											: T_SLV_8;
			SIGNAL Trans_TX_CharIsK										: STD_LOGIC;
			SIGNAL Trans_TX_RunningDisparity					: STD_LOGIC;
			SIGNAL Trans_TX_BufferError								: STD_LOGIC;
			SIGNAL Trans_TX_CharDisparityMode					: STD_LOGIC;
			SIGNAL Trans_TX_CharDisparityValue				: STD_LOGIC;

			-- RX signals
			SIGNAL Trans_RX_MGTReset									: STD_LOGIC;
			SIGNAL Trans_RX_Data											: T_SLV_8;
			SIGNAL Trans_RX_CharIsComma								: STD_LOGIC;
			SIGNAL Trans_RX_CharIsK										: STD_LOGIC;
			SIGNAL Trans_RX_CharIsNotInTable					: STD_LOGIC;
			SIGNAL Trans_RX_RunningDisparity					: STD_LOGIC;
			SIGNAL Trans_RX_DisparityError						: STD_LOGIC;
			SIGNAL Trans_RX_Realign										: STD_LOGIC;
			SIGNAL Trans_RX_ClockCorrectionCount			: T_SLV_3;
			SIGNAL Trans_RX_BufferStatus							: T_SLV_3;

			SIGNAL Trans_PHY_MDIOAddress							: STD_LOGIC_VECTOR(4 DOWNTO 0);
			SIGNAL Trans_1														: STD_LOGIC;
			SIGNAL Trans_2														: STD_LOGIC;
			SIGNAL Trans_3														: STD_LOGIC;
		
		BEGIN
			Trans_PHY_MDIOAddress		<= "00111";
		
			TEMAC_V5	: ENTITY PoC.eth_TEMAC_TRANS_Virtex5
				PORT MAP (
					--					-- Asynchronous Reset
					RESET														=> Reset,

					DCM_LOCKED_0										=> Trans_3,

					-- Client Receiver Interface - EMAC0
					CLIENTEMAC0RXCLIENTCLKIN				=> Eth_RX_Clock,
					EMAC0CLIENTRXCLIENTCLKOUT				=> OPEN,													-- SOURCE: UG194, page 147
					
					EMAC0CLIENTRXD									=> Eth_RX_Data,
					EMAC0CLIENTRXDVLD								=> Eth_RX_Valid,
					EMAC0CLIENTRXDVLDMSW						=> OPEN,
					EMAC0CLIENTRXGOODFRAME					=> Eth_RX_GoodFrame,
					EMAC0CLIENTRXBADFRAME						=> Eth_RX_BadFrame,
					EMAC0CLIENTRXFRAMEDROP					=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATS							=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSVLD						=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSBYTEVLD				=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Client Transmitter Interface - EMAC0
					CLIENTEMAC0TXCLIENTCLKIN				=> Eth_TX_Clock,
					EMAC0CLIENTTXCLIENTCLKOUT				=> OPEN,
					
					CLIENTEMAC0TXD									=> TX_FIFO_Data,
					CLIENTEMAC0TXDVLD								=> TX_FIFO_Valid,
					CLIENTEMAC0TXDVLDMSW						=> '0',
					EMAC0CLIENTTXACK								=> Eth_TX_Ack,
					CLIENTEMAC0TXFIRSTBYTE					=> '0',														-- SOURCE: v5temac_gmii_locallink.vhd
					CLIENTEMAC0TXUNDERRUN						=> '0',														-- SOURCE: v5temac_client_eth_fifo_8.vhd
					EMAC0CLIENTTXCOLLISION					=> Eth_TX_Collision,
					EMAC0CLIENTTXRETRANSMIT					=> Eth_TX_Retransmit,
					CLIENTEMAC0TXIFGDELAY						=> (OTHERS	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATS							=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSVLD						=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSBYTEVLD				=> OPEN,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- MAC Control Interface - EMAC0
					CLIENTEMAC0PAUSEREQ							=> '0',														-- SOURCE: ml505_gmii_udp_top.vhdl
					CLIENTEMAC0PAUSEVAL							=> (OTHERS	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Clock Signals - EMAC0
					GTX_CLK_0												=> '0',														-- SOURCE: UG194, page 147

					EMAC0PHYTXGMIIMIICLKOUT					=> OPEN,													-- SOURCE: UG194, page 147
					PHYEMAC0TXGMIIMIICLKIN					=> RS_TX_Clock,

					-- Transceiver interface (TRANS) - EMAC0
					-- ------------------------------------------------------------------
					POWERDOWN_0											=> TEMAC_PowerDown,
					LOOPBACKMSB_0										=> Trans_LoopBack_MSB,
					AN_INTERRUPT_0									=> Trans_Interrupt,
					SIGNAL_DETECT_0									=> Trans_SignalDetect,
					
					-- TX signals
					MGTTXRESET_0										=> Trans_TX_MGTReset,
					TXDATA_0												=> Trans_TX_Data,
					TXCHARISK_0											=> Trans_TX_CharIsK,
					TXRUNDISP_0											=> Trans_TX_RunningDisparity,
					TXBUFERR_0											=> Trans_TX_BufferError,
					TXCHARDISPMODE_0								=> Trans_TX_CharDisparityMode,
					TXCHARDISPVAL_0									=> Trans_TX_CharDisparityValue,

					-- RX signals
					MGTRXRESET_0										=> Trans_RX_MGTReset,
					RXDATA_0												=> Trans_RX_Data,
					RXCHARISCOMMA_0									=> Trans_RX_CharIsComma,
					RXCHARISK_0											=> Trans_RX_CharIsK,
					RXNOTINTABLE_0									=> Trans_RX_CharIsNotInTable,
					RXRUNDISP_0											=> Trans_RX_RunningDisparity,
					RXDISPERR_0											=> Trans_RX_DisparityError,
					RXREALIGN_0											=> Trans_RX_Realign,
					RXCLKCORCNT_0										=> Trans_RX_ClockCorrectionCount,
					RXBUFSTATUS_0										=> Trans_RX_BufferStatus(1 DOWNTO 0),

					PHYAD_0													=> Trans_PHY_MDIOAddress,
					ENCOMMAALIGN_0									=> Trans_1,

					SYNCACQSTATUS_0									=> Trans_2,

					-- MDIO interface - EMAC0
					MDC_0														=> PHY_Interface.MDIO.Clock_ts.O,
					MDIO_0_I												=> PHY_Interface.MDIO.Data_ts.I,
					MDIO_0_O												=> PHY_Interface.MDIO.Data_ts.O,
					MDIO_0_T												=> PHY_Interface.MDIO.Data_ts.T
				);
			
			PHY_Interface.MDIO.Clock_ts.T	<= '0';
			
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: MII
			-- ========================================================================================================================================================
			genPHY_MII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_MII) GENERATE
				ASSERT FALSE REPORT "Physical interface MII is not supported!" SEVERITY FAILURE;
			END GENERATE;
						-- ========================================================================================================================================================
			-- FPGA-PHY inferface: GMII
			-- ========================================================================================================================================================
			genPHY_GMII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) GENERATE
				ASSERT FALSE REPORT "Physical interface GMII is not supported!" SEVERITY FAILURE;
			END GENERATE;
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) GENERATE
				SIGNAL DCM_Locked								: STD_LOGIC;
				SIGNAL Trans_PLL_Locked					: STD_LOGIC;
				SIGNAL Trans_TX_Clock						: STD_LOGIC;
				SIGNAL Trans_RX_Clock						: STD_LOGIC;
				
				SIGNAL Trans_RefClockOut				: STD_LOGIC;
				SIGNAL Trans_TX_ClockOut				: STD_LOGIC;
				SIGNAL Trans_RX_RecoveredClock	: STD_LOGIC;
				
				SIGNAL Trans_TX_Reset						: STD_LOGIC;
				SIGNAL Trans_RX_Reset						: STD_LOGIC;
				SIGNAL Trans_ResetDone					: STD_LOGIC;
				SIGNAL Trans_TX_BufferReset			: STD_LOGIC;
				SIGNAL Trans_RX_BufferReset			: STD_LOGIC;
				
				SIGNAL Trans_RX_ElectricalIDLE	: STD_LOGIC;
				SIGNAL Trans_LoopBack						: T_SLV_3;
				
				SIGNAL Trans_TX_BufferStatus		: T_SLV_2;
				SIGNAL Trans_PowerDown					: T_SLV_2;
			BEGIN
				Trans_PowerDown		<= (OTHERS => TEMAC_PowerDown);
				
				BUFG_RefClockOut : BUFG
					PORT MAP (
						I		=> Trans_RefClockOut,
						O		=> PHY_Interface.SGMII.SGMII_RXRefClock_Out
					);
			
--				TRANS	: ENTITY PoC.Eth_RSLayer_TRANS_GMII_Virtex5
--					GENERIC MAP (
--						-- Simulation attributes
--						TILE_SIM_GTPRESET_SPEEDUP				=> 0,					-- Set to 1 to speed up sim reset
--						TILE_SIM_PLL_PERDIV2						=> x"190",		-- Set to the VCO Unit Interval time 
--
--						-- Channel bonding attributes
--						TILE_CHAN_BOND_MODE_0						=> "OFF",			-- "MASTER", "SLAVE", or "OFF"
--						TILE_CHAN_BOND_LEVEL_0					=> 0,					-- 0 to 7. See UG for details
--						
--						TILE_CHAN_BOND_MODE_1						=> "OFF",			-- "MASTER", "SLAVE", or "OFF"
--						TILE_CHAN_BOND_LEVEL_1					=> 0					-- 0 to 7. See UG for details
--					)
--					PORT MAP (
--						------------------------ Loopback and Powerdown Ports ----------------------
--						LOOPBACK0_IN										=> Trans_LoopBack,					-- 2:0
--						LOOPBACK1_IN										=> "000",
--						RXPOWERDOWN0_IN									=> Trans_PowerDown,					-- 1:0
--						TXPOWERDOWN0_IN									=> Trans_PowerDown,
--						RXPOWERDOWN1_IN									=> "11",
--						TXPOWERDOWN1_IN									=> "11",
--						----------------------- Receive Ports - 8b10b Decoder ----------------------
--						RXCHARISCOMMA0_OUT							=> Trans_RX_CharIsComma,
--						RXCHARISCOMMA1_OUT							=> OPEN,
--						RXCHARISK0_OUT									=> Trans_RX_CharIsK,
--						RXCHARISK1_OUT									=> OPEN,
--						RXDISPERR0_OUT									=> Trans_RX_DisparityError,
--						RXDISPERR1_OUT									=> OPEN,
--						RXNOTINTABLE0_OUT								=> Trans_RX_CharIsNotInTable,
--						RXNOTINTABLE1_OUT								=> OPEN,
--						RXRUNDISP0_OUT									=> Trans_RX_RunningDisparity,
--						RXRUNDISP1_OUT									=> OPEN,
--						------------------- Receive Ports - Clock Correction Ports -----------------
--						RXCLKCORCNT0_OUT								=> Trans_RX_ClockCorrectionCount,
--						RXCLKCORCNT1_OUT								=> OPEN,
--						--------------- Receive Ports - Comma Detection and Alignment --------------
--						RXENMCOMMAALIGN0_IN							=> '1',
--						RXENMCOMMAALIGN1_IN							=> '0',
--						RXENPCOMMAALIGN0_IN							=> '1',
--						RXENPCOMMAALIGN1_IN							=> '0',
--						------------------- Receive Ports - RX Data Path interface -----------------
--						RXDATA0_OUT											=> Trans_RX_Data,
--						RXDATA1_OUT											=> OPEN,
--						RXRECCLK0_OUT										=> Trans_RX_RecoveredClock,
--						RXRECCLK1_OUT										=> OPEN,
--						RXRESET0_IN											=> Trans_RX_Reset,
--						RXRESET1_IN											=> '0',
--						RXUSRCLK0_IN										=> Trans_RX_Clock,
--						RXUSRCLK1_IN										=> '0',
--						RXUSRCLK20_IN										=> Trans_RX_Clock,
--						RXUSRCLK21_IN										=> '0',
--						------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
--						RXELECIDLE0_OUT									=> Trans_RX_ElectricalIDLE,
--						RXELECIDLE1_OUT									=> OPEN,
--						RXN0_IN													=> PHY_Interface.SGMII.RX_n,
--						RXN1_IN													=> '0',
--						RXP0_IN													=> PHY_Interface.SGMII.RX_p,
--						RXP1_IN													=> '0',
--						-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
--						RXBUFRESET0_IN									=> Trans_RX_BufferReset,
--						RXBUFRESET1_IN									=> '0',
--						RXBUFSTATUS0_OUT								=> Trans_RX_BufferStatus,
--						RXBUFSTATUS1_OUT								=> OPEN,
--						--------------------- Shared Ports - Tile and PLL Ports --------------------
--						CLKIN_IN												=> PHY_Interface.SGMII.SGMII_RefClock_In,
--						GTPRESET_IN											=> '0',
--						PLLLKDET_OUT										=> Trans_PLL_Locked,
--						REFCLKOUT_OUT										=> Trans_RefClockOut,
--						RESETDONE0_OUT									=> Trans_ResetDone,
--						RESETDONE1_OUT									=> OPEN,
--						---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
--						TXCHARDISPMODE0_IN							=> Trans_TX_CharDisparityMode,
--						TXCHARDISPMODE1_IN							=> '0',
--						TXCHARDISPVAL0_IN								=> Trans_TX_CharDisparityValue,
--						TXCHARDISPVAL1_IN								=> '0',
--						TXCHARISK0_IN										=> Trans_TX_CharIsK,
--						TXCHARISK1_IN										=> '0',
--						------------- Transmit Ports - TX Buffering and Phase Alignment ------------
--						TXBUFSTATUS0_OUT								=> Trans_TX_BufferStatus,
--						TXBUFSTATUS1_OUT								=> OPEn,
--						------------------ Transmit Ports - TX Data Path interface -----------------
--						TXDATA0_IN											=> Trans_TX_Data,
--						TXDATA1_IN											=> x"00",
--						TXOUTCLK0_OUT										=> Trans_TX_ClockOut,
--						TXOUTCLK1_OUT										=> OPEN,
--						TXRESET0_IN											=> Trans_TX_Reset,
--						TXRESET1_IN											=> '0',
--						TXUSRCLK0_IN										=> Trans_TX_Clock,
--						TXUSRCLK1_IN										=> '0',
--						TXUSRCLK20_IN										=> Trans_TX_Clock,
--						TXUSRCLK21_IN										=> '0',
--						--------------- Transmit Ports - TX Driver and OOB signalling --------------
--						TXN0_OUT												=> PHY_Interface.SGMII.TX_n,
--						TXN1_OUT												=> OPEN,
--						TXP0_OUT												=> PHY_Interface.SGMII.TX_p,
--						TXP1_OUT												=> OPEN
--					);
			END GENERATE;		-- PHY_DATA_INTERFACE: SGMII
		END GENERATE;		-- RS_DATA_INTERFACE: TRANSCEIVER
	END GENERATE;		-- MAC_IP: IPSTYLE_HARD
	
	-- ==========================================================================================================================================================
	-- Gigabit MAC_MDIOC MAC (GEMAC) - SoftIP
	-- ==========================================================================================================================================================
	genSoftIP	: IF (ETHERNET_IPSTYLE = IPSTYLE_SOFT) GENERATE

	BEGIN
		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: GMII
		-- ========================================================================================================================================================
		genRS_GMII	: IF (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_GMII) GENERATE
			-- RS-GMII interface
			SIGNAL RS_TX_Valid					: STD_LOGIC;
			SIGNAL RS_TX_Data						: T_SLV_8;
			SIGNAL RS_TX_Error					: STD_LOGIC;
				
			SIGNAL RS_RX_Valid					: STD_LOGIC;
			SIGNAL RS_RX_Data						: T_SLV_8;
			SIGNAL RS_RX_Error					: STD_LOGIC;
		BEGIN
			GEMAC	: ENTITY PoC.Eth_GEMAC_GMII
				GENERIC MAP (
					DEBUG														=> TRUE,
					CLOCK_FREQ_MHZ									=> CLOCK_FREQ_MHZ,			-- 
				
					TX_FIFO_DEPTH										=> 2048,								-- 2 kiB TX Buffer
					TX_INSERT_CROSSCLOCK_FIFO				=> true,								-- TODO: 
					TX_SUPPORT_JUMBO_FRAMES					=> FALSE,								-- TODO: 
					TX_DISABLE_UNDERRUN_PROTECTION	=> false,								-- TODO: 							true: no protection; false: store complete frame in buffer befor transmitting it
					
					RX_FIFO_DEPTH										=> 4096,								-- 4 kiB TX Buffer
					RX_INSERT_CROSSCLOCK_FIFO				=> TRUE,								-- TODO: 
					RX_SUPPORT_JUMBO_FRAMES					=> FALSE								-- TODO: 
				)
				PORT MAP (
					-- clock interface
					TX_Clock									=> TX_Clock,
					RX_Clock									=> RX_Clock,
					Eth_TX_Clock							=> Eth_TX_Clock,
					Eth_RX_Clock							=> Eth_RX_Clock,
					RS_TX_Clock								=> RS_TX_Clock,
					RS_RX_Clock								=> RS_RX_Clock,
					
					TX_Reset									=> Reset,
					RX_Reset									=> Reset,
					RS_TX_Reset								=> Reset,
					RS_RX_Reset								=> Reset,

					TX_BufferUnderrun					=> OPEN,
					RX_FrameDrop							=> OPEN,
					RX_FrameCorrupt						=> OPEN,
					
					-- MAC LocalLink interface
					TX_Valid									=> TX_Valid,
					TX_Data										=> TX_Data,
					TX_SOF										=> TX_SOF,
					TX_EOF										=> TX_EOF,
					TX_Ack										=> TX_Ack,

					RX_Valid									=> RX_Valid,
					RX_Data										=> RX_Data,
					RX_SOF										=> RX_SOF,
					RX_EOF										=> RX_EOF,
					RX_Ack										=> RX_Ack,
					
					-- RS-GMII interface
					RS_TX_Valid								=> RS_TX_Valid,
					RS_TX_Data								=> RS_TX_Data,
					RS_TX_Error								=> RS_TX_Error,
					
					RS_RX_Valid								=> RS_RX_Valid,
					RS_RX_Data								=> RS_RX_Data,
					RS_RX_Error								=> RS_RX_Error
				);
		
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: MII
			-- ========================================================================================================================================================
			genPHY_MII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_MII) GENERATE
				ASSERT FALSE REPORT "Physical interface MII is not supported!" SEVERITY FAILURE;
			END GENERATE;
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: GMII
			-- ========================================================================================================================================================
			genPHY_GMII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) GENERATE
			
			BEGIN
				GMII	: ENTITY PoC.eth_RSLayer_GMII_GMII_Xilinx
					PORT MAP (
						RS_TX_Clock								=> RS_TX_Clock,
						RS_RX_Clock								=> RS_RX_Clock,						
						
						Reset_async								=> Reset_async,																		-- @async: 
						
						-- RS-GMII interface
						RS_TX_Valid								=> RS_TX_Valid,
						RS_TX_Data								=> RS_TX_Data,
						RS_TX_Error								=> RS_TX_Error,
						
						RS_RX_Valid								=> RS_RX_Valid,
						RS_RX_Data								=> RS_RX_Data,
						RS_RX_Error								=> RS_RX_Error,
						
						-- PHY-GMII interface
						PHY_Interface							=> PHY_Interface.GMII
					);
			END GENERATE;		-- PHY_DATA_INTERFACE: GMII
		
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII	: IF (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) GENERATE
			
			BEGIN
				ASSERT FALSE REPORT "Physical interface SGMII is not implemented!" SEVERITY FAILURE;
			
				SGMII	: ENTITY PoC.Eth_RSLayer_GMII_SGMII_Virtex5
		--			GENERIC MAP (
		--				CLOCKIN_FREQ_MHZ					=> CLOCKIN_FREQ_MHZ					-- 125 MHz
		--			)
					PORT MAP (
						Clock										=> RS_TX_Clock,
						Reset										=> Reset_async,
						
						-- GEMAC-GMII interface
						RS_TX_Clock							=> RS_TX_Clock,
						RS_TX_Valid							=> RS_TX_Valid,
						RS_TX_Data							=> RS_TX_Data,
						RS_TX_Error							=> RS_TX_Error,
						
						RS_RX_Clock							=> RS_RX_Clock,
						RS_RX_Valid							=> RS_RX_Valid,
						RS_RX_Data							=> RS_RX_Data,
						RS_RX_Error							=> RS_RX_Error
					);
			END GENERATE;		-- PHY_DATA_INTERFACE: SGMII
		END GENERATE;		-- RS_DATA_INTERFACE: GMII
		
		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: TRANSCEIVER
		-- ========================================================================================================================================================
		genRS_TRANS	: IF (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_TRANSCEIVER) GENERATE
		BEGIN
			ASSERT FALSE REPORT "Reconcilation SubLayer interface TRANS is not supported!" SEVERITY FAILURE;
		END GENERATE;		-- RS_DATA_INTERFACE: TRANSCEIVER
	END GENERATE;		-- MAC_IP: IPSTYLE_SOFT
END;
