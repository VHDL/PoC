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

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity icmpv6_Wrapper is
	port (
		Clock															: in	std_logic;
		Reset															: in	std_logic;

		IP_TX_Valid												: out	std_logic;
		IP_TX_Data												: out	T_SLV_8;
		IP_TX_SOF													: out	std_logic;
		IP_TX_EOF													: out	std_logic;
		IP_TX_Ack													: in	std_logic;
		IP_TX_Meta_rst										: in	std_logic;
		IP_TX_Meta_DestIPv6Address_nxt		: in	std_logic;
		IP_TX_Meta_DestIPv6Address_Data		: out	T_SLV_8;

		IP_RX_Valid												: in	std_logic;
		IP_RX_Data												: in	T_SLV_8;
		IP_RX_SOF													: in	std_logic;
		IP_RX_EOF													: in	std_logic;
		IP_RX_Ack													: out	std_logic--;

--		Command										: in	T_ETHERNET_ICMPV6_COMMAND;
--		Status										: out	T_ETHERNET_ICMPV6_STATUS


	);
end entity;


architecture rtl of icmpv6_Wrapper is
	signal RX_Received_EchoRequest			: std_logic;

begin

	IP_RX_Ack													<= '1';

	IP_TX_Valid												<= '0';
	IP_TX_Data												<= (others => '0');
	IP_TX_SOF													<= '0';
	IP_TX_EOF													<= '0';
	IP_TX_Meta_DestIPv6Address_Data		<= (others => '0');


--	ICMPv6_loop : entity PoC.FrameLoopback
--		generic map (
--			DATA_BW										=> 8,
--			META_BW										=> 0
--		)
--		port map (
--			Clock									=> Clock,
--			Reset									=> Reset,
--
--			In_Valid							=> IP_RX_Valid,
--			In_Data								=> IP_RX_Data,
--			In_Meta								=> (others => '0'),
--			In_SOF								=> IP_RX_SOF,
--			In_EOF								=> IP_RX_EOF,
--			In_Ack								=> IP_RX_Ack,
--
--			Out_Valid							=> IP_TX_Valid,
--			Out_Data							=> IP_TX_Data,
--			Out_Meta							=> open,
--			Out_SOF								=> IP_TX_SOF,
--			Out_EOF								=> IP_TX_EOF,
--			Out_Ack								=> IP_TX_Ack
--		);

-- =============================================================================
-- RX Path
-- =============================================================================
--	RX : entity PoC.icmpv6_RX
--		port map (
--			Clock										=> Clock,
--			Reset										=> Reset,
--
--			RX_Valid								=> IP_RX_Valid,
--			RX_Data									=> IP_RX_Data,
--			RX_SOF									=> IP_RX_SOF,
--			RX_EOF									=> IP_RX_EOF,
--			RX_Ack									=> IP_RX_Ack,
--
--			Received_EchoRequest		=> RX_Received_EchoRequest
--		);

-- =============================================================================
-- TX Path
-- =============================================================================
--	TX : entity PoC.icmpv6_TX
--		port map (
--			Clock										=> Clock,
--			Reset										=> Reset,
--
--			TX_Valid								=> IP_TX_Valid,
--			TX_Data									=> IP_TX_Data,
--			TX_SOF									=> IP_TX_SOF,
--			TX_EOF									=> IP_TX_EOF,
--			TX_Ack									=> IP_TX_Ack,
--
--			Send_EchoResponse				=> RX_Received_EchoRequest
--    );
end architecture;
