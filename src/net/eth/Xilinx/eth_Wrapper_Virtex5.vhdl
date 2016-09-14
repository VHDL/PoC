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


entity eth_Wrapper_Virtex5 is
	generic (
		DEBUG											: boolean														:= FALSE;															--
		CLOCK_FREQ_MHZ						: REAL															:= 125.0;															-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											--
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		--
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		--
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

		-- MAC LocalLink interface
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

architecture rtl of eth_Wrapper_Virtex5 is
	attribute KEEP									: boolean;

	signal Reset_async							: std_logic;		-- FIXME:

	signal TX_Reset									: std_logic;		-- FIXME:
	signal RX_Reset									: std_logic;		-- FIXME:

begin

	-- XXX: review reset-tree and clock distribution
	Reset_async		<= Reset;

	-- ==========================================================================================================================================================
	-- Xilinx Virtex 5 Tri-Mode MAC_MDIOC MAC (TEMAC) HardIP
	-- ==========================================================================================================================================================
	genHardIP	: if (ETHERNET_IPSTYLE = IPSTYLE_HARD) generate
		signal TX_FIFO_Data						: T_SLV_8;
		signal TX_FIFO_Valid					: std_logic;
		signal TX_FIFO_Overflow				: std_logic;
		signal TX_FIFO_Status					: std_logic_vector(3 downto 0);

		signal RX_FIFO_Overflow				: std_logic;
		signal RX_FIFO_Status					: std_logic_vector(3 downto 0);

		signal Eth_TX_Reset						: std_logic;
		signal Eth_TX_Enable					: std_logic;
		signal Eth_TX_Ack							: std_logic;
		signal Eth_TX_Collision				: std_logic;
		signal Eth_TX_Retransmit			: std_logic;

		signal Eth_RX_Reset						: std_logic;
		signal Eth_RX_Enable					: std_logic;

		signal Eth_RX_Data						: T_SLV_8;
		signal Eth_RX_Data_r					: T_SLV_8								:= (others	=> '0');
		signal Eth_RX_Valid						: std_logic;
		signal Eth_RX_Valid_r					: std_logic							:= '0';
		signal Eth_RX_GoodFrame				: std_logic;
		signal Eth_RX_GoodFrame_r			: std_logic							:= '0';
		signal Eth_RX_BadFrame				: std_logic;
		signal Eth_RX_BadFrame_r			: std_logic							:= '0';


	begin
		genReset	: block
			signal TX_Reset_shift				: T_SLV_8;
			signal RX_Reset_shift				: T_SLV_8;

			signal Eth_TX_Reset_shift		: T_SLV_8;
			signal Eth_RX_Reset_shift		: T_SLV_8;

			attribute async_reg												: boolean;
			attribute async_reg of TX_Reset_shift			: signal is TRUE;
			attribute async_reg of RX_Reset_shift			: signal is TRUE;

			attribute async_reg of Eth_TX_Reset_shift	: signal is TRUE;
			attribute async_reg of Eth_RX_Reset_shift	: signal is TRUE;

		begin
			-- Create synchronous reset in the transmitter clock domain.
			process(TX_Clock, Reset_async)
			begin
				if (Reset_async = '1') then
					TX_Reset_shift				<= (others	=> '1');
				elsif rising_edge(TX_Clock) then
					TX_Reset_shift				<= TX_Reset_shift(TX_Reset_shift'high - 1 downto 0) & '0';
				end if;
			end process;

			-- Create synchronous reset in the receiver clock domain.
			process(RX_Clock, Reset_async)
			begin
				if (Reset_async = '1') then
					RX_Reset_shift				<= (others	=> '1');
				elsif rising_edge(RX_Clock) then
					RX_Reset_shift				<= RX_Reset_shift(RX_Reset_shift'high - 1 downto 0) & '0';
				end if;
			end process;

			-- Create synchronous reset in the transmitter clock domain.
			process(Eth_TX_Clock, Reset_async)
			begin
				if (Reset_async = '1') then
					Eth_TX_Reset_shift		<= (others	=> '1');
				elsif rising_edge(Eth_TX_Clock) then
					Eth_TX_Reset_shift		<= Eth_TX_Reset_shift(Eth_TX_Reset_shift'high - 1 downto 0) & '0';
				end if;
			end process;

			-- Create synchronous reset in the receiver clock domain.
			process(Eth_RX_Clock, Reset_async)
			begin
				if (Reset_async = '1') then
					Eth_RX_Reset_shift		<= (others	=> '1');
				elsif rising_edge(Eth_RX_Clock) then
					Eth_RX_Reset_shift		<= Eth_RX_Reset_shift(Eth_RX_Reset_shift'high - 1 downto 0) & '0';
				end if;
			end process;

			TX_Reset				<= TX_Reset_shift(TX_Reset_shift'high);
			RX_Reset				<= RX_Reset_shift(RX_Reset_shift'high);
			Eth_TX_Reset		<= Eth_TX_Reset_shift(Eth_TX_Reset_shift'high);
			Eth_RX_Reset		<= Eth_RX_Reset_shift(Eth_RX_Reset_shift'high);
		end block;

		blkFIFO	: block
			signal TX_Valid_n			: std_logic;
			signal TX_SOF_n				: std_logic;
			signal TX_EOF_n				: std_logic;
			signal TX_Ack_n				: std_logic;

			signal RX_Valid_n			: std_logic;
			signal RX_SOF_n				: std_logic;
			signal RX_EOF_n				: std_logic;
			signal RX_Ack_n				: std_logic;
		begin
			-- convert LocalLink interface from low-active to high-active and vv.
			-- ========================================================================================================================================================
			TX_Valid_n		<= not TX_Valid;
			TX_SOF_n			<= not TX_SOF;
			TX_EOF_n			<= not TX_EOF;
			TX_Ack				<= not TX_Ack_n;

			RX_Valid			<= not RX_Valid_n;
			RX_SOF				<= not RX_SOF_n;
			RX_EOF				<= not RX_EOF_n;
			RX_Ack_n			<= not RX_Ack;

			Eth_TX_Enable					<= '1';
			Eth_RX_Enable					<= '1';

			-- Transmitter FIFO and LocalLink adapter
			TX_FIFO	: entity PoC.eth_TEMAC_TX_FIFO_Virtex5
				generic map (
					FULL_DUPLEX_ONLY	=> FALSE--TRUE
				)
				port map (
					wr_clk						=> TX_Clock,								-- Local link write clock
					wr_sreset					=> TX_Reset,								-- synchronous reset (wr_clock)

					-- Transmitter Local Link Interface
					wr_data						=> TX_Data,									-- Data to TX FIFO
					wr_sof_n					=> TX_SOF_n,
					wr_eof_n					=> TX_EOF_n,
					wr_src_rdy_n			=> TX_Valid_n,
					wr_dst_rdy_n			=> TX_Ack_n,
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
			RX_FIFO	: entity PoC.eth_TEMAC_RX_FIFO_Virtex5
				port map (
					rd_clk						=> RX_Clock,								-- Local link read clock
					rd_sreset					=> RX_Reset,								-- synchronous reset (rd_clock)

					-- Receiver Local Link Interface
					rd_data_out				=> RX_Data,									-- Data from RX FIFO
					rd_sof_n					=> RX_SOF_n,
					rd_eof_n					=> RX_EOF_n,
					rd_src_rdy_n			=> RX_Valid_n,
					rd_dst_rdy_n			=> RX_Ack_n,

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
		end block;


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

			-- Instantiate the EMAC Wrapper (v5temac_gmii.vhd)
			TEMAC_V5	: entity PoC.eth_TEMAC_GMII_Virtex5
				port map (
					-- Asynchronous Reset
					RESET														=> Reset_async,
					DCM_LOCKED_0										=> '1',														-- TODO: should this signals be connected to ClockNet/DCM_locked?

					-- Client Receiver Interface - EMAC0
					CLIENTEMAC0RXCLIENTCLKIN				=> Eth_RX_Clock,
					EMAC0CLIENTRXCLIENTCLKOUT				=> open,													-- SOURCE: UG194, page 147

					EMAC0CLIENTRXD									=> Eth_RX_Data,
					EMAC0CLIENTRXDVLD								=> Eth_RX_Valid,
					EMAC0CLIENTRXDVLDMSW						=> open,
					EMAC0CLIENTRXGOODFRAME					=> Eth_RX_GoodFrame,
					EMAC0CLIENTRXBADFRAME						=> Eth_RX_BadFrame,
					EMAC0CLIENTRXFRAMEDROP					=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATS							=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSVLD						=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSBYTEVLD				=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Client Transmitter Interface - EMAC0
					CLIENTEMAC0TXCLIENTCLKIN				=> Eth_TX_Clock,
					EMAC0CLIENTTXCLIENTCLKOUT				=> open,

					CLIENTEMAC0TXD									=> TX_FIFO_Data,
					CLIENTEMAC0TXDVLD								=> TX_FIFO_Valid,
					CLIENTEMAC0TXDVLDMSW						=> '0',
					EMAC0CLIENTTXACK								=> Eth_TX_Ack,
					CLIENTEMAC0TXFIRSTBYTE					=> '0',														-- SOURCE: v5temac_gmii_locallink.vhd
					CLIENTEMAC0TXUNDERRUN						=> '0',														-- SOURCE: v5temac_client_eth_fifo_8.vhd
					EMAC0CLIENTTXCOLLISION					=> Eth_TX_Collision,
					EMAC0CLIENTTXRETRANSMIT					=> Eth_TX_Retransmit,
					CLIENTEMAC0TXIFGDELAY						=> (others	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATS							=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSVLD						=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSBYTEVLD				=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- MAC Control Interface - EMAC0
					CLIENTEMAC0PAUSEREQ							=> '0',														-- SOURCE: ml505_gmii_udp_top.vhdl
					CLIENTEMAC0PAUSEVAL							=> (others	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Clock Signals - EMAC0
					GTX_CLK_0												=> '0',														-- SOURCE: UG194, page 147

					EMAC0PHYTXGMIIMIICLKOUT					=> open,													-- SOURCE: UG194, page 147
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
			process(RX_Clock, Reset_async)
			begin
				if (Reset_async = '1') then
					Eth_RX_Data_r						<= (others	=> '0');
					Eth_RX_Valid_r					<= '0';
					Eth_RX_GoodFrame_r			<= '0';
					Eth_RX_BadFrame_r				<= '0';
				else
					if rising_edge(RX_Clock) then
						Eth_RX_Data_r					<= Eth_RX_Data;
						Eth_RX_Valid_r				<= Eth_RX_Valid;
						Eth_RX_GoodFrame_r		<= Eth_RX_GoodFrame;
						Eth_RX_BadFrame_r			<= Eth_RX_BadFrame;
					end if;
				end if;
			end process;

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
				GMII	: entity PoC.eth_RSLayer_GMII_GMII_Xilinx
					port map (
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
			end generate;		-- PHY_DATA_INTERFACE: GMII

			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII : if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) generate
				-- RS-GMII interface
				signal RS_TX_Valid					: std_logic;
				signal RS_TX_Data						: T_SLV_8;
				signal RS_TX_Error					: std_logic;

				signal RS_RX_Valid					: std_logic;
				signal RS_RX_Data						: T_SLV_8;
				signal RS_RX_Error					: std_logic;
			begin
				assert FALSE report "Physical interface SGMII is not implemented!" severity FAILURE;

				PCS : entity PoC.eth_GMII_SGMII_PCS_Virtex5
					port map (
						dcm_locked						=> 'X',

						reset									=> 'X',

						-- status
						status_vector					=> open,

						-- configuration interface (disabled)
						configuration_vector	=> (others => '0'),
						configuration_valid		=> '0',

						-- auto-negotiation
						an_restart_config			=> '0',
						an_adv_config_val			=> '0',
						an_adv_config_vector	=> (others => '0'),
						an_interrupt					=> open,

						link_timer_value			=> (others => '0'),

						-- GMII Interface
						gmii_isolate					=> open,
						gmii_txd							=> RS_TX_Data,			-- Transmit data from client MAC.
						gmii_tx_en						=> RS_TX_Valid,			-- Transmit control signal from client MAC.
						gmii_tx_er						=> RS_TX_Error,			-- Transmit control signal from client MAC.
						gmii_rxd							=> RS_RX_Data, 			-- Received Data to client MAC.
						gmii_rx_dv						=> RS_RX_Valid,			-- Received control signal to client MAC.
						gmii_rx_er						=> RS_RX_Error,			-- Received control signal to client MAC.

						phyad									=> PCS_MDIO_ADDRESS(4 downto 0),
						mdc										=> MDIO_Clock,
						mdio_in								=> MDIO_Data_i,
						mdio_out							=> MDIO_Data_o,
						mdio_tri							=> MDIO_Data_t,

						-- TRANS interface
						powerdown							=> PCS_PowerDown,
						mgt_tx_reset					=> PCS_TX_Reset,
						mgt_rx_reset					=> PCS_RX_Reset,
						userclk								=> PCS_UserClock,
						userclk2							=> PCS_UserClock2,
						enablealign						=> PCS_EnableAlign,

						-- TRANS TX interface
						txdata								=> PCS_TX_Data,
						txcharisk							=> PCS_TX_CharIsK,
						txchardispmode				=> PCS_TX_CharDisparityMode,
						txchardispval					=> PCS_TX_CharDisparityValue,
						txbuferr							=> Trans_TX_BufferError,

						-- TRANS RX interface
						rxdata								=> Trans_RX_Data,
						rxcharisk							=> Trans_RX_CharIsK,
						rxchariscomma					=> Trans_RX_CharIsComma,
						rxbufstatus						=> Trans_RX_BufferStatus,
						rxdisperr							=> Trans_RX_DisparityError,
						rxnotintable					=> Trans_RX_NotInTable,
						rxrundisp							=> Trans_RX_RunningDisparity,
						rxclkcorcnt						=> Trans_RX_ClockCorrectionCount,


						-- optical light detected in optical transceiver
						signal_detect					=> '1'


			--			sgmii_clk0					: out std_logic;										-- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).

					);

			Trans : entity PoC.eth_Transceiver_Virtex5_GTP
				generic map (
					DEBUG										=> DEBUG,
					CLOCK_IN_FREQ						=> CLOCK_FREQ,
					PORTS										=> PORTS
				)
				port map (
					PowerDown								=> PCS_PowerDown,
					TX_Reset								=> PCS_TX_Reset,
					RX_Reset								=> PCS_RX_Reset,
					UserClock								=> PCS_UserClock,
					UserClock2							=> PCS_UserClock2,
					EnableAlignment					=> PCS_EnableAlign,

					-- TRANS TX interface
					TX_Data									=> PCS_TX_Data,
					TX_CharIsK							=> PCS_TX_CharIsK,
					TX_CharDisparityMode		=> PCS_TX_CharDisparityMode,
					TX_CharDisparityValue		=> PCS_TX_CharDisparityValue,
					TX_BufferError					=> Trans_TX_BufferError,

					-- TRANS RX interface
					RX_Data									=> Trans_RX_Data,
					RX_CharIsK							=> Trans_RX_CharIsK,
					RX_CharIsComma					=> Trans_RX_CharIsComma,
					RX_BufferStatus					=> Trans_RX_BufferStatus,
					RX_DisparityError				=> Trans_RX_DisparityError,
					RX_NotInTable						=> Trans_RX_NotInTable,
					RX_RunningDisparity			=> Trans_RX_RunningDisparity,
					RX_ClockCorrectionCount	=> Trans_RX_ClockCorrectionCount,

					TX_n										=> open,
					TX_p										=> open,
					RX_n										=> 'X',
					RX_p										=> 'X'
				);

			end generate;		-- PHY_DATA_INTERFACE: SGMII
		end generate;		-- RS_DATA_INTERFACE: GMII

		-- ========================================================================================================================================================
		-- reconcilation sublayer (RS) interface	: TRANSCEIVER
		-- ========================================================================================================================================================
		genRS_TRANS	: if (RS_DATA_INTERFACE = NET_ETH_RS_DATA_INTERFACE_TRANSCEIVER) generate
			-- Transceiver interface (TRANS) - EMAC0
			-- ------------------------------------------------------------------
			signal TEMAC_PowerDown										: std_logic;
			signal Trans_LoopBack_MSB									: std_logic;
			signal Trans_Interrupt										: std_logic;
			signal Trans_SignalDetect									: std_logic;

			-- TX signals
			signal Trans_TX_MGTReset									: std_logic;
			signal Trans_TX_Data											: T_SLV_8;
			signal Trans_TX_CharIsK										: std_logic;
			signal Trans_TX_RunningDisparity					: std_logic;
			signal Trans_TX_BufferError								: std_logic;
			signal Trans_TX_CharDisparityMode					: std_logic;
			signal Trans_TX_CharDisparityValue				: std_logic;

			-- RX signals
			signal Trans_RX_MGTReset									: std_logic;
			signal Trans_RX_Data											: T_SLV_8;
			signal Trans_RX_CharIsComma								: std_logic;
			signal Trans_RX_CharIsK										: std_logic;
			signal Trans_RX_CharIsNotInTable					: std_logic;
			signal Trans_RX_RunningDisparity					: std_logic;
			signal Trans_RX_DisparityError						: std_logic;
			signal Trans_RX_Realign										: std_logic;
			signal Trans_RX_ClockCorrectionCount			: T_SLV_3;
			signal Trans_RX_BufferStatus							: T_SLV_3;

			signal Trans_PHY_MDIOAddress							: std_logic_vector(4 downto 0);
			signal Trans_1														: std_logic;
			signal Trans_2														: std_logic;
			signal Trans_3														: std_logic;

		begin
			Trans_PHY_MDIOAddress		<= "00111";

			TEMAC_V5	: entity PoC.eth_TEMAC_TRANS_Virtex5
				port map (
					--					-- Asynchronous Reset
					RESET														=> Reset,

					DCM_LOCKED_0										=> Trans_3,

					-- Client Receiver Interface - EMAC0
					CLIENTEMAC0RXCLIENTCLKIN				=> Eth_RX_Clock,
					EMAC0CLIENTRXCLIENTCLKOUT				=> open,													-- SOURCE: UG194, page 147

					EMAC0CLIENTRXD									=> Eth_RX_Data,
					EMAC0CLIENTRXDVLD								=> Eth_RX_Valid,
					EMAC0CLIENTRXDVLDMSW						=> open,
					EMAC0CLIENTRXGOODFRAME					=> Eth_RX_GoodFrame,
					EMAC0CLIENTRXBADFRAME						=> Eth_RX_BadFrame,
					EMAC0CLIENTRXFRAMEDROP					=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATS							=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSVLD						=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTRXSTATSBYTEVLD				=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Client Transmitter Interface - EMAC0
					CLIENTEMAC0TXCLIENTCLKIN				=> Eth_TX_Clock,
					EMAC0CLIENTTXCLIENTCLKOUT				=> open,

					CLIENTEMAC0TXD									=> TX_FIFO_Data,
					CLIENTEMAC0TXDVLD								=> TX_FIFO_Valid,
					CLIENTEMAC0TXDVLDMSW						=> '0',
					EMAC0CLIENTTXACK								=> Eth_TX_Ack,
					CLIENTEMAC0TXFIRSTBYTE					=> '0',														-- SOURCE: v5temac_gmii_locallink.vhd
					CLIENTEMAC0TXUNDERRUN						=> '0',														-- SOURCE: v5temac_client_eth_fifo_8.vhd
					EMAC0CLIENTTXCOLLISION					=> Eth_TX_Collision,
					EMAC0CLIENTTXRETRANSMIT					=> Eth_TX_Retransmit,
					CLIENTEMAC0TXIFGDELAY						=> (others	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATS							=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSVLD						=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl
					EMAC0CLIENTTXSTATSBYTEVLD				=> open,													-- SOURCE: ml505_gmii_udp_top.vhdl

					-- MAC Control Interface - EMAC0
					CLIENTEMAC0PAUSEREQ							=> '0',														-- SOURCE: ml505_gmii_udp_top.vhdl
					CLIENTEMAC0PAUSEVAL							=> (others	=> '0'),								-- SOURCE: ml505_gmii_udp_top.vhdl

					-- Clock Signals - EMAC0
					GTX_CLK_0												=> '0',														-- SOURCE: UG194, page 147

					EMAC0PHYTXGMIIMIICLKOUT					=> open,													-- SOURCE: UG194, page 147
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
					RXBUFSTATUS_0										=> Trans_RX_BufferStatus(1 downto 0),

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
			genPHY_MII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_MII) generate
				assert FALSE report "Physical interface MII is not supported!" severity FAILURE;
			end generate;
						-- ========================================================================================================================================================
			-- FPGA-PHY inferface: GMII
			-- ========================================================================================================================================================
			genPHY_GMII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) generate
				assert FALSE report "Physical interface GMII is not supported!" severity FAILURE;
			end generate;
			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) generate

			begin

				Trans : entity PoC.eth_Transceiver_Virtex5_GTP
					generic map (
						DEBUG										=> DEBUG,
						CLOCK_IN_FREQ						=> CLOCK_FREQ,
						PORTS										=> PORTS
					)
					port map (
						PowerDown								=> PCS_PowerDown,
						TX_Reset								=> PCS_TX_Reset,
						RX_Reset								=> PCS_RX_Reset,
						UserClock								=> PCS_UserClock,
						UserClock2							=> PCS_UserClock2,
						EnableAlignment					=> PCS_EnableAlign,

						-- TRANS TX interface
						TX_Data									=> PCS_TX_Data,
						TX_CharIsK							=> PCS_TX_CharIsK,
						TX_CharDisparityMode		=> PCS_TX_CharDisparityMode,
						TX_CharDisparityValue		=> PCS_TX_CharDisparityValue,
						TX_BufferError					=> Trans_TX_BufferError,

						-- TRANS RX interface
						RX_Data									=> Trans_RX_Data,
						RX_CharIsK							=> Trans_RX_CharIsK,
						RX_CharIsComma					=> Trans_RX_CharIsComma,
						RX_BufferStatus					=> Trans_RX_BufferStatus,
						RX_DisparityError				=> Trans_RX_DisparityError,
						RX_NotInTable						=> Trans_RX_NotInTable,
						RX_RunningDisparity			=> Trans_RX_RunningDisparity,
						RX_ClockCorrectionCount	=> Trans_RX_ClockCorrectionCount,

						TX_n										=> open,
						TX_p										=> open,
						RX_n										=> '0',
						RX_p										=> '0'
					);

			end generate;		-- PHY_DATA_INTERFACE: SGMII
		end generate;		-- RS_DATA_INTERFACE: TRANSCEIVER
	end generate;		-- MAC_IP: IPSTYLE_HARD

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
					CLOCK_FREQ_MHZ									=> CLOCK_FREQ_MHZ,			--

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
			end generate;		-- PHY_DATA_INTERFACE: GMII

			-- ========================================================================================================================================================
			-- FPGA-PHY inferface: SGMII
			-- ========================================================================================================================================================
			genPHY_SGMII	: if (PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_SGMII) generate

			begin


				PCS : entity PoC.eth_GMII_SGMII_PCS_Virtex5
					port map (
						dcm_locked						=> 'X',

						reset									=> 'X',

						-- status
						status_vector					=> open,

						-- configuration interface (disabled)
						configuration_vector	=> (others => '0'),
						configuration_valid		=> '0',

						-- auto-negotiation
						an_restart_config			=> '0',
						an_adv_config_val			=> '0',
						an_adv_config_vector	=> (others => '0'),
						an_interrupt					=> open,

						link_timer_value			=> (others => '0'),

						-- GMII Interface
						gmii_isolate					=> open,
						gmii_txd							=> RS_TX_Data,			-- Transmit data from client MAC.
						gmii_tx_en						=> RS_TX_Valid,			-- Transmit control signal from client MAC.
						gmii_tx_er						=> RS_TX_Error,			-- Transmit control signal from client MAC.
						gmii_rxd							=> RS_RX_Data, 			-- Received Data to client MAC.
						gmii_rx_dv						=> RS_RX_Valid,			-- Received control signal to client MAC.
						gmii_rx_er						=> RS_RX_Error,			-- Received control signal to client MAC.

						phyad									=> PCS_MDIO_ADDRESS(4 downto 0),
						mdc										=> MDIO_Clock,
						mdio_in								=> MDIO_Data_i,
						mdio_out							=> MDIO_Data_o,
						mdio_tri							=> MDIO_Data_t,

						-- TRANS interface
						powerdown							=> PCS_PowerDown,
						mgt_tx_reset					=> PCS_TX_Reset,
						mgt_rx_reset					=> PCS_RX_Reset,
						userclk								=> PCS_UserClock,
						userclk2							=> PCS_UserClock2,
						enablealign						=> PCS_EnableAlign,

						-- TRANS TX interface
						txdata								=> PCS_TX_Data,
						txcharisk							=> PCS_TX_CharIsK,
						txchardispmode				=> PCS_TX_CharDisparityMode,
						txchardispval					=> PCS_TX_CharDisparityValue,
						txbuferr							=> Trans_TX_BufferError,

						-- TRANS RX interface
						rxdata								=> Trans_RX_Data,
						rxcharisk							=> Trans_RX_CharIsK,
						rxchariscomma					=> Trans_RX_CharIsComma,
						rxbufstatus						=> Trans_RX_BufferStatus,
						rxdisperr							=> Trans_RX_DisparityError,
						rxnotintable					=> Trans_RX_NotInTable,
						rxrundisp							=> Trans_RX_RunningDisparity,
						rxclkcorcnt						=> Trans_RX_ClockCorrectionCount,


						-- optical light detected in optical transceiver
						signal_detect					=> '1'


			--			sgmii_clk0					: out std_logic;										-- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).

					);

				Trans : entity PoC.eth_Transceiver_Virtex5_GTP
					generic map (
						DEBUG										=> DEBUG,
						CLOCK_IN_FREQ						=> CLOCK_FREQ,
						PORTS										=> PORTS
					)
					port map (
						PowerDown								=> PCS_PowerDown,
						TX_Reset								=> PCS_TX_Reset,
						RX_Reset								=> PCS_RX_Reset,
						UserClock								=> PCS_UserClock,
						UserClock2							=> PCS_UserClock2,
						EnableAlignment					=> PCS_EnableAlign,

						-- TRANS TX interface
						TX_Data									=> PCS_TX_Data,
						TX_CharIsK							=> PCS_TX_CharIsK,
						TX_CharDisparityMode		=> PCS_TX_CharDisparityMode,
						TX_CharDisparityValue		=> PCS_TX_CharDisparityValue,
						TX_BufferError					=> Trans_TX_BufferError,

						-- TRANS RX interface
						RX_Data									=> Trans_RX_Data,
						RX_CharIsK							=> Trans_RX_CharIsK,
						RX_CharIsComma					=> Trans_RX_CharIsComma,
						RX_BufferStatus					=> Trans_RX_BufferStatus,
						RX_DisparityError				=> Trans_RX_DisparityError,
						RX_NotInTable						=> Trans_RX_NotInTable,
						RX_RunningDisparity			=> Trans_RX_RunningDisparity,
						RX_ClockCorrectionCount	=> Trans_RX_ClockCorrectionCount,

						TX_n										=> open,
						TX_p										=> open,
						RX_n										=> '0',
						RX_p										=> '0'
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
end;
