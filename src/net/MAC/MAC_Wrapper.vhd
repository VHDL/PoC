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
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY MAC_Wrapper IS
	GENERIC (
		DEBUG												: BOOLEAN															:= FALSE;
		MAC_CONFIG									: T_NET_MAC_CONFIGURATION_VECTOR
	);
	PORT (
		Clock												: IN	STD_LOGIC;
		Reset												: IN	STD_LOGIC;
		
		Eth_TX_Valid								: OUT	STD_LOGIC;
		Eth_TX_Data									: OUT	T_SLV_8;
		Eth_TX_SOF									: OUT	STD_LOGIC;
		Eth_TX_EOF									: OUT	STD_LOGIC;
		Eth_TX_Ready								: IN	STD_LOGIC;
		
		Eth_RX_Valid								: IN	STD_LOGIC;
		Eth_RX_Data									: IN	T_SLV_8;
		Eth_RX_SOF									: IN	STD_LOGIC;
		Eth_RX_EOF									: IN	STD_LOGIC;
		Eth_RX_Ready								: OUT	STD_LOGIC;
		
		TX_Valid										: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_Data											: IN	T_SLVV_8(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_SOF											: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_EOF											: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_Ready										: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		Tx_Meta_rst									: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_Meta_DestMACAddress_nxt	: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		TX_Meta_DestMACAddress_Data	: IN	T_SLVV_8(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		
		RX_Valid										: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Data											: OUT	T_SLVV_8(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_SOF											: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_EOF											: OUT	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Ready										: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_rst									: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_nxt		: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_Data	: OUT	T_SLVV_8(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_nxt	: IN	STD_LOGIC_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_Data	: OUT	T_SLVV_8(getPortCount(MAC_CONFIG) - 1 DOWNTO 0);
		RX_Meta_EthType							: OUT	T_NET_MAC_ETHERNETTYPE_VECTOR(getPortCount(MAC_CONFIG) - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF MAC_Wrapper IS
	FUNCTION getInterfaceAddresses(MAC_CONFIG : T_NET_MAC_CONFIGURATION_VECTOR) RETURN T_NET_MAC_ADDRESS_VECTOR IS
		VARIABLE temp : T_NET_MAC_ADDRESS_VECTOR(MAC_CONFIG'range);
	BEGIN
		FOR I IN MAC_CONFIG'range LOOP
			temp(I) := MAC_CONFIG(I).Interface.Address;
		END LOOP;
	
		RETURN temp;
	END FUNCTION;

	FUNCTION getInterfaceMasks(MAC_CONFIG : T_NET_MAC_CONFIGURATION_VECTOR) RETURN T_NET_MAC_ADDRESS_VECTOR IS
		VARIABLE temp : T_NET_MAC_ADDRESS_VECTOR(MAC_CONFIG'range);
	BEGIN
		FOR I IN MAC_CONFIG'range LOOP
			temp(I) := MAC_CONFIG(I).Interface.Mask;
		END LOOP;
	
		RETURN temp;
	END FUNCTION;
	
	FUNCTION getSourceFilterCount(Interfaces : T_NET_MAC_INTERFACE_VECTOR) RETURN NATURAL IS
		VARIABLE count : NATURAL		:= 0;
	BEGIN
		FOR I IN Interfaces'range LOOP
			IF ((Interfaces(I).Address /= C_NET_MAC_ADDRESS_EMPTY) OR (Interfaces(I).Mask /= C_NET_MAC_MASK_EMPTY)) THEN
				count := count + 1;
			END IF;
		END LOOP;
	
		RETURN count;
	END FUNCTION;
	
	FUNCTION getSourceFilterAddresses(Interfaces : T_NET_MAC_INTERFACE_VECTOR) RETURN T_NET_MAC_ADDRESS_VECTOR IS
		VARIABLE temp : T_NET_MAC_ADDRESS_VECTOR(Interfaces'range);
	BEGIN
		FOR I IN Interfaces'range LOOP
			temp(I) := Interfaces(I).Address;
		END LOOP;
	
		RETURN temp;
	END FUNCTION;

	FUNCTION getSourceFilterMasks(Interfaces : T_NET_MAC_INTERFACE_VECTOR) RETURN T_NET_MAC_ADDRESS_VECTOR IS
		VARIABLE temp : T_NET_MAC_ADDRESS_VECTOR(Interfaces'range);
	BEGIN
		FOR I IN Interfaces'range LOOP
			temp(I) := Interfaces(I).Mask;
		END LOOP;
	
		RETURN temp;
	END FUNCTION;
	
	FUNCTION getTypeSwitchCount(Types : T_NET_MAC_ETHERNETTYPE_VECTOR) RETURN NATURAL IS
		VARIABLE count : NATURAL		:= 0;
	BEGIN
		FOR I IN Types'range LOOP
			IF (Types(I) /= C_NET_MAC_ETHERNETTYPE_EMPTY) THEN
				count := count + 1;
			END IF;
		END LOOP;
	
		RETURN count;
	END FUNCTION;
	
	FUNCTION calcPortIndex(MAC_CONFIG : T_NET_MAC_CONFIGURATION_VECTOR; CurrentInterfaceID : NATURAL) RETURN NATURAL IS
		VARIABLE count : NATURAL		:= 0;
	BEGIN
		IF (CurrentInterfaceID = 0) THEN
			RETURN 0;
		END IF;
	
		FOR I IN 0 TO CurrentInterfaceID - 1 LOOP
			count := count + getTypeSwitchCount(MAC_CONFIG(I).TypeSwitch);
		END LOOP;
		
		RETURN count;
	END FUNCTION;
	
	
	CONSTANT PORTS															: POSITIVE												:= getPortCount(MAC_CONFIG);
	CONSTANT INTERFACE_COUNT										: POSITIVE												:= MAC_CONFIG'length;
	CONSTANT INTERFACE_ADDRESSES								: T_NET_MAC_ADDRESS_VECTOR				:= getInterfaceAddresses(MAC_CONFIG);
	CONSTANT INTERFACE_MASKS										: T_NET_MAC_ADDRESS_VECTOR				:= getInterfaceMasks(MAC_CONFIG);
					
	SIGNAL DestEth_RX_Valid											: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL DestEth_RX_Data											: T_SLVV_8(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL DestEth_RX_SOF												: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL DestEth_RX_EOF												: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL DestEth_RX_Meta_DestMACAddress_Data	: T_SLVV_8(INTERFACE_COUNT - 1 DOWNTO 0);

	SIGNAL SrcEth_RX_Ready											: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL SrcEth_RX_Meta_rst										: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL SrcEth_RX_Meta_DestMACAddress_nxt		: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);

	SIGNAL EthType_TX_Valid											: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL EthType_TX_Data											: T_SLVV_8(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL EthType_TX_SOF												: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL EthType_TX_EOF												: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL EthType_TX_Meta_DestMACAddress_Data	: T_SLVV_8(INTERFACE_COUNT - 1 DOWNTO 0);
	
	SIGNAL SrcEth_TX_Valid											: STD_LOGIC;
	SIGNAL SrcEth_TX_Data												: T_SLV_8;
	SIGNAL SrcEth_TX_SOF												: STD_LOGIC;
	SIGNAL SrcEth_TX_EOF												: STD_LOGIC;
	SIGNAL SrcEth_TX_Ready											: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL SrcEth_TX_Meta_rst										: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL SrcEth_TX_Meta_DestMACAddress_nxt		: STD_LOGIC_VECTOR(INTERFACE_COUNT - 1 DOWNTO 0);
	SIGNAL SrcEth_TX_Meta_DestMACAddress_Data		: T_SLV_8;
							
	SIGNAL DestEth_TX_Ready											: STD_LOGIC;
	SIGNAL DestEth_TX_Meta_rst									: STD_LOGIC;
	SIGNAL DestEth_TX_Meta_DestMACAddress_nxt		: STD_LOGIC;
	
BEGIN

	RX_DestMAC : ENTITY PoC.MAC_RX_DestMAC_Switch
		GENERIC MAP (
			DEBUG								=> DEBUG,
			MAC_ADDRESSES									=> INTERFACE_ADDRESSES,
			MAC_ADDRESSE_MASKS						=> INTERFACE_MASKS
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> Eth_RX_Valid,
			In_Data												=> Eth_RX_Data,
			In_SOF												=> Eth_RX_SOF,
			In_EOF												=> Eth_RX_EOF,
			In_Ready											=> Eth_RX_Ready,

			Out_Valid											=> DestEth_RX_Valid,
			Out_Data											=> DestEth_RX_Data,
			Out_SOF												=> DestEth_RX_SOF,
			Out_EOF												=> DestEth_RX_EOF,
			Out_Ready											=> SrcEth_RX_Ready,
			Out_Meta_DestMACAddress_rst		=> SrcEth_RX_Meta_rst,
			Out_Meta_DestMACAddress_nxt		=> SrcEth_RX_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data	=> DestEth_RX_Meta_DestMACAddress_Data
		);

	genInterface : FOR I IN MAC_CONFIG'range GENERATE
		CONSTANT FILTER_COUNT										: NATURAL												:= getSourceFilterCount(MAC_CONFIG(I).SourceFilter);
		CONSTANT FILTER_ADDRESSES								: T_NET_MAC_ADDRESS_VECTOR			:= getSourceFilterAddresses(MAC_CONFIG(I).SourceFilter(0 TO FILTER_COUNT - 1));
		CONSTANT FILTER_MASKS										: T_NET_MAC_ADDRESS_VECTOR			:= getSourceFilterMasks(MAC_CONFIG(I).SourceFilter(0 TO FILTER_COUNT - 1));
		
		CONSTANT SWITCH_COUNT										: NATURAL												:= getTypeSwitchCount(MAC_CONFIG(I).TypeSwitch);
		CONSTANT SWITCH_TYPES										: T_NET_MAC_ETHERNETTYPE_VECTOR	:= MAC_CONFIG(I).TypeSwitch(0 TO SWITCH_COUNT - 1);
		
		CONSTANT PORT_INDEX_FROM								: NATURAL												:= calcPortIndex(MAC_CONFIG, I);
		CONSTANT PORT_INDEX_TO									: NATURAL												:= PORT_INDEX_FROM + SWITCH_COUNT - 1;
		
		SIGNAL SrcEth_RX_Valid									: STD_LOGIC;
		SIGNAL SrcEth_RX_Data										: T_SLV_8;
		SIGNAL SrcEth_RX_SOF										: STD_LOGIC;
		SIGNAL SrcEth_RX_EOF										: STD_LOGIC;
		
--		SIGNAL SrcEth_RX_Meta_SrcMACAddress_rst			: STD_LOGIC;
--		SIGNAL SrcEth_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		SIGNAL SrcEth_RX_Meta_DestMACAddress_Data		: T_SLV_8;
		SIGNAL SrcEth_RX_Meta_SrcMACAddress_Data		: T_SLV_8;
		
		SIGNAL EthEth_RX_Ready											: STD_LOGIC;
		SIGNAL EthEth_RX_Meta_rst										: STD_LOGIC;
		SIGNAL EthEth_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
		SIGNAL EthEth_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		
	BEGIN
--		ASSERT FALSE REPORT "Filter:      Count=" & INTEGER'image(FILTER_COUNT) SEVERITY NOTE;
--		ASSERT FALSE REPORT "PortIndex:   From="	& INTEGER'image(PORT_INDEX_FROM) & " to=" & INTEGER'image(PORT_INDEX_TO) SEVERITY NOTE;
	
		RX_SrcMAC : ENTITY PoC.MAC_RX_SrcMAC_Filter
			GENERIC MAP (
				DEBUG								=> DEBUG,
				MAC_ADDRESSES									=> FILTER_ADDRESSES,
				MAC_ADDRESSE_MASKS						=> FILTER_MASKS
			)
			PORT MAP (
				Clock													=> Clock,
				Reset													=> Reset,
				
				In_Valid											=> DestEth_RX_Valid(I),
				In_Data												=> DestEth_RX_Data(I),
				In_SOF												=> DestEth_RX_SOF(I),
				In_EOF												=> DestEth_RX_EOF(I),
				In_Ready				 							=> SrcEth_RX_Ready(I),
				In_Meta_rst										=> SrcEth_RX_Meta_rst(I),
				In_Meta_DestMACAddress_nxt		=> SrcEth_RX_Meta_DestMACAddress_nxt(I),
				In_Meta_DestMACAddress_Data		=> DestEth_RX_Meta_DestMACAddress_Data(I),

				Out_Valid											=> SrcEth_RX_Valid,
				Out_Data											=> SrcEth_RX_Data,
				Out_SOF												=> SrcEth_RX_SOF,
				Out_EOF												=> SrcEth_RX_EOF,
				Out_Ready											=> EthEth_RX_Ready,
				Out_Meta_rst									=> EthEth_RX_Meta_rst,
				Out_Meta_DestMACAddress_nxt		=> EthEth_RX_Meta_DestMACAddress_nxt,
				Out_Meta_DestMACAddress_Data	=> SrcEth_RX_Meta_DestMACAddress_Data,
				Out_Meta_SrcMACAddress_nxt		=> EthEth_RX_Meta_SrcMACAddress_nxt,
				Out_Meta_SrcMACAddress_Data		=> SrcEth_RX_Meta_SrcMACAddress_Data
			);

		RX_EthType : ENTITY PoC.MAC_RX_Type_Switch
			GENERIC MAP (
				DEBUG								=> DEBUG,
				ETHERNET_TYPES								=> SWITCH_TYPES
			)
			PORT MAP (
				Clock													=> Clock,
				Reset													=> Reset,
				
				In_Valid											=> SrcEth_RX_Valid,
				In_Data												=> SrcEth_RX_Data,
				In_SOF												=> SrcEth_RX_SOF,
				In_EOF												=> SrcEth_RX_EOF,
				In_Ready											=> EthEth_RX_Ready,
				In_Meta_rst										=> EthEth_RX_Meta_rst,
				In_Meta_DestMACAddress_nxt		=> EthEth_RX_Meta_DestMACAddress_nxt,
				In_Meta_DestMACAddress_Data		=> SrcEth_RX_Meta_DestMACAddress_Data,
				In_Meta_SrcMACAddress_nxt			=> EthEth_RX_Meta_SrcMACAddress_nxt,
				In_Meta_SrcMACAddress_Data		=> SrcEth_RX_Meta_SrcMACAddress_Data,

				Out_Valid											=> RX_Valid(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Data											=> RX_Data(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_SOF												=> RX_SOF(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_EOF												=> RX_EOF(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Ready											=> RX_Ready(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_rst									=> RX_Meta_rst(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_DestMACAddress_nxt		=> RX_Meta_DestMACAddress_nxt(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_DestMACAddress_Data	=> RX_Meta_DestMACAddress_Data(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_SrcMACAddress_nxt		=> RX_Meta_SrcMACAddress_nxt(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_SrcMACAddress_Data		=> RX_Meta_SrcMACAddress_Data(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				Out_Meta_EthType							=> RX_Meta_EthType(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM)
			);

		-- Ethernet Type prepender
		TX_EthType : ENTITY PoC.MAC_TX_Type_Prepender
			GENERIC MAP (
				ETHERNET_TYPES								=> SWITCH_TYPES
			)
			PORT MAP (
				Clock													=> Clock,
				Reset													=> Reset,
				
				In_Valid											=> TX_Valid(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_Data												=> TX_Data(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_SOF												=> TX_SOF(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_EOF												=> TX_EOF(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_Ready											=> TX_Ready(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_Meta_rst										=> TX_Meta_rst(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_Meta_DestMACAddress_nxt		=> TX_Meta_DestMACAddress_nxt(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				In_Meta_DestMACAddress_Data		=> TX_Meta_DestMACAddress_Data(PORT_INDEX_TO DOWNTO PORT_INDEX_FROM),
				
				Out_Valid											=> EthType_TX_Valid(I),
				Out_Data											=> EthType_TX_Data(I),
				Out_SOF												=> EthType_TX_SOF(I),
				Out_EOF												=> EthType_TX_EOF(I),
				Out_Ready											=> SrcEth_TX_Ready(I),
				Out_Meta_rst									=> SrcEth_TX_Meta_rst(I),
				Out_Meta_DestMACAddress_nxt		=> SrcEth_TX_Meta_DestMACAddress_nxt(I),
				Out_Meta_DestMACAddress_Data	=> EthType_TX_Meta_DestMACAddress_Data(I)
			);
	END GENERATE;

	-- Ethernet SourceMAC prepender
	TX_SrcMAC : ENTITY PoC.MAC_TX_SrcMAC_Prepender
		GENERIC MAP (
			MAC_ADDRESSES									=> INTERFACE_ADDRESSES
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> EthType_TX_Valid,
			In_Data												=> EthType_TX_Data,
			In_SOF												=> EthType_TX_SOF,
			In_EOF												=> EthType_TX_EOF,
			In_Ready											=> SrcEth_TX_Ready,
			In_Meta_rst										=> SrcEth_TX_Meta_rst,
			In_Meta_DestMACAddress_nxt		=> SrcEth_TX_Meta_DestMACAddress_nxt,
			In_Meta_DestMACAddress_Data		=> EthType_TX_Meta_DestMACAddress_Data,
			
			Out_Valid											=> SrcEth_TX_Valid,
			Out_Data											=> SrcEth_TX_Data,
			Out_SOF												=> SrcEth_TX_SOF,
			Out_EOF												=> SrcEth_TX_EOF,
			Out_Ready											=> DestEth_TX_Ready,
			Out_Meta_rst									=> DestEth_TX_Meta_rst,
			Out_Meta_DestMACAddress_nxt		=> DestEth_TX_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data	=> SrcEth_TX_Meta_DestMACAddress_Data
		);

	-- Ethernet SourceMAC prepender
	TX_DestMAC : ENTITY PoC.MAC_TX_DestMAC_Prepender
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> SrcEth_TX_Valid,
			In_Data												=> SrcEth_TX_Data,
			In_SOF												=> SrcEth_TX_SOF,
			In_EOF												=> SrcEth_TX_EOF,
			In_Ready											=> DestEth_TX_Ready,

			In_Meta_rst										=> DestEth_TX_Meta_rst,
			In_Meta_DestMACAddress_nxt		=> DestEth_TX_Meta_DestMACAddress_nxt,
			In_Meta_DestMACAddress_Data		=> SrcEth_TX_Meta_DestMACAddress_Data,
			
			Out_Valid											=> Eth_TX_Valid,
			Out_Data											=> Eth_TX_Data,
			Out_SOF												=> Eth_TX_SOF,
			Out_EOF												=> Eth_TX_EOF,
			Out_Ready											=> Eth_TX_Ready
		);

END ARCHITECTURE;
