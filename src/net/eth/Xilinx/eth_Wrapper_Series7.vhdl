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
use			PoC.physical.all;
use			PoC.net.all;


entity eth_Wrapper_Series7 is
	generic (
		DEBUG											: boolean														:= FALSE;															--
--		CLOCK_FREQ_MHZ						: REAL															:= 125.0;															-- 125 MHz
		CLOCKIN_FREQ								: FREQ															:= 125.0 MHz;															-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											--
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		--
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_SGMII		--
	);
	port (
		-- clock interface
		RS_TX_Clock								: in	std_logic;
		RS_RX_Clock								: in	std_logic;
		Eth_TX_Clock							: in	std_logic;
		Eth_RX_Clock							: in	std_logic;
		TX_Clock									: in	std_logic;
		RX_Clock									: in	std_logic;
		
		-- reset interface
		Reset											: in	std_logic;
		
		-- Command-Status-Error interface
		
		-- MAC LocalLink interface Poc.Stream
		TX_Valid									: in	std_logic;
		TX_Data										: in	T_SLV_8;
		TX_SOF										: in	std_logic;
		TX_EOF										: in	std_logic;
		TX_Ack										: out	std_logic;
		
		RX_Valid									: out	std_logic;
		RX_Data										: out	T_SLV_8;
		RX_SOF										: out	std_logic;
		RX_EOF										: out	std_logic;
		RX_Ack										: in	std_logic;
		
		PHY_Interface							:	inout	T_NET_ETH_PHY_INTERFACES
	);
end entity;

-- Structure
-- =============================================================================
--	genSoftIP
--		o	GEMAC					- Gigabit MAC_MDIOC MAC (GEMAC) SoftCore with GMII interface
--		genPHY_GMII
--			o	GMII				- GMII-GMII adapter; FlipFlop and IDelay instances
--		genPHY_SGMII
--			o	SGMII				- GMII-SGMII adapter; transceiver

-- +------------+---------------+---------------+---------------------------------------+
-- |	IP-Style	|	RS-Interface	|	PHY-Interface	|	status / comment											|
-- |------------+---------------+---------------+---------------------------------------+
-- |	SoftIP		|			GMII			|			GMII			|		not tested													|
-- |		"				|			GMII			|			SGMII			|		not tested													|
-- +------------+---------------+---------------+---------------------------------------+

architecture rtl of eth_Wrapper_Series7 is
	attribute KEEP									: boolean;
	
	signal Reset_async							: std_logic;		-- FIXME:
	
	signal TX_Reset									: std_logic;		-- FIXME:
	signal RX_Reset									: std_logic;		-- FIXME:
	
begin

	-- XXX: review reset-tree and clock distribution
	Reset_async		<= Reset;
	
	-- ==========================================================================================================================================================
	-- Gigabit MAC_MDIOC MAC (GEMAC) - SoftIP
	-- ==========================================================================================================================================================
	genSoftIP	: if (ETHERNET_IPSTYLE = IPSTYLE_SOFT) generate
	
	begin
		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: GMII
		-- ========================================================================================================================================================
		genRS_GMII	: if (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_GMII) generate
			-- RS-GMII interface
			signal RS_TX_Valid					: std_logic;
			signal RS_TX_Data						: T_SLV_8;
			signal RS_TX_Error					: std_logic;
			
			signal RS_RX_Valid					: std_logic;
			signal RS_RX_Data						: T_SLV_8;
			signal RS_RX_Error					: std_logic;
		begin
			GEMAC	: entity PoC.Eth_GEMAC_GMII
				generic map (
					DEBUG														=> TRUE,
					CLOCKIN_FREQ									=> CLOCKIN_FREQ,			--
					
					TX_FIFO_DEPTH										=> 2048,								-- 2 kiB TX Buffer
					TX_INSERT_CROSSCLOCK_FIFO				=> true,								-- TODO:
					TX_SUPPORT_JUMBO_FRAMES					=> FALSE,								-- TODO:
					TX_DISABLE_UNDERRUN_PROTECTION	=> false,								-- TODO: 							true: no protection; false: store complete frame in buffer befor transmitting it
					
					RX_FIFO_DEPTH										=> 4096,								-- 4 kiB TX Buffer
					RX_INSERT_CROSSCLOCK_FIFO				=> TRUE,								-- TODO:
					RX_SUPPORT_JUMBO_FRAMES					=> FALSE								-- TODO:
				)
				port map (
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
					
					TX_BufferUnderrun					=> open,
					RX_FrameDrop							=> open,
					RX_FrameCorrupt						=> open,
					
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
			genPHY_MII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_MII) generate
				assert FALSE report "Physical interface MII is not supported!" severity FAILURE;
			end generate;
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: GMII
			-- ========================================================================================================================================================
			genPHY_GMII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) generate
			
			begin
				GMII	: entity PoC.eth_RSLayer_GMII_GMII_Xilinx
					port map (
						Reset_async								=> '0',--Reset_async,
									
						RS_TX_Clock								=> '0',--RS_TX_Clock,
						RS_RX_Clock								=> RS_RX_Clock,
						
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
			end generate;		-- PHY_DATA_INTERFACE: GMII
			
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) generate
			
			begin
			
			
				PCS : entity PoC.eth_RSLayer_GMII_SGMII_Series7
					port map (
						reset									=> reset,
						resetdone => open,
						
						-- status
						status_vector					=> open,
						
						speed_is_10_100 => '0',
						speed_is_100 => '1',
						
						-- configuration interface (disabled)
						configuration_vector	=> (others => '0'),
						
						-- GMII Interface
						gmii_isolate					=> open,
						gmii_txd							=> RS_TX_Data,			-- Transmit data from client MAC.
						gmii_tx_en						=> RS_TX_Valid,			-- Transmit control signal from client MAC.
						gmii_tx_er						=> RS_TX_Error,			-- Transmit control signal from client MAC.
						gmii_rxd							=> RS_RX_Data, 			-- Received Data to client MAC.
						gmii_rx_dv						=> RS_RX_Valid,			-- Received control signal to client MAC.
						gmii_rx_er						=> RS_RX_Error,			-- Received control signal to client MAC.
						
						-- SGMII PHY Interface
						txn => PHY_Interface.SGMII.tx_n,
						txp => PHY_Interface.SGMII.tx_p,
						rxn => PHY_Interface.SGMII.rx_n,
						rxp => PHY_Interface.SGMII.rx_p,
						
						--CLK's
						pma_reset => '0',
						mmcm_reset => open,
						
						mmcm_locked => '1',
						cplllock => open,
						
						userclk => RS_RX_Clock,
						userclk2 => RS_RX_Clock,
						
						gtrefclk_bufg => RS_RX_Clock,
						gtrefclk => RS_RX_Clock,
							
						independent_clock_bufg => RS_RX_Clock,
						txoutclk => open,
						rxoutclk => open,
						rxuserclk => RS_RX_Clock,
						rxuserclk2 => RS_RX_Clock,
						sgmii_clk_r => open,
						sgmii_clk_f => open,
						sgmii_clk_en => open,
						gt0_qplloutclk_in => RS_RX_Clock,
						gt0_qplloutrefclk_in => RS_RX_Clock,
						
						-- optical light detected in optical transceiver
						signal_detect					=> '1'
						
			
			
			
					);
			end generate;		-- PHY_DATA_INTERFACE: SGMII
		end generate;		-- RS_DATA_INTERFACE: GMII
		
		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: TRANSCEIVER
		-- ========================================================================================================================================================
		genRS_TRANS	: if (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_TRANSCEIVER) generate
		begin
			assert FALSE report "Reconcilation SubLayer interface TRANS is not supported!" severity FAILURE;
		end generate;		-- RS_DATA_INTERFACE: TRANSCEIVER
	end generate;		-- MAC_IP: IPSTYLE_SOFT
end rtl;
