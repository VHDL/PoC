-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:					Global board configuration settings.
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This file evaluates the settings declared in the project specific package my_config.
--		See also template file my_config.vhdl.template.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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

library	PoC;
use			PoC.my_config.all;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.net.all;


package board is
	-- Functions extracting board and PCB properties from "MY_BOARD"
	-- which is declared in package "my_config".
	-- ===========================================================================
	function MY_DEVICE_STRING(BoardConfig : string := "None")				return string;

	-- 
	-- ===========================================================================
	TYPE T_BRD_ETHERNET_DESC IS RECORD
		IPStyle										: T_IPSTYLE;
		RS_DataInterface					: T_NET_ETH_RS_DATA_INTERFACE;
		PHY_Device								: T_NET_ETH_PHY_DEVICE;
		PHY_DeviceAddress					: T_NET_ETH_PHY_DEVICE_ADDRESS;
		PHY_DataInterface					: T_NET_ETH_PHY_DATA_INTERFACE;
		PHY_ManagementInterface		: T_NET_ETH_PHY_MANAGEMENT_INTERFACE;
	END RECORD;

	TYPE T_BOARD_DESCRIPTION IS RECORD
		Ethernet		: T_BRD_ETHERNET_DESC;
	
	END RECORD;


	function MY_BOARD_STRUCT(BoardConfig : string := "None") return T_BOARD_DESCRIPTION;


	CONSTANT C_BOARD_ML505			: T_BOARD_DESCRIPTION		:= (
		Ethernet => (
			IPStyle										=> IPSTYLE_SOFT,
			RS_DataInterface					=> NET_ETH_RS_DATA_INTERFACE_GMII,
			PHY_Device								=> NET_ETH_PHY_DEVICE_MARVEL_88E1111,
			PHY_DeviceAddress					=> x"07",
			PHY_DataInterface					=> NET_ETH_PHY_DATA_INTERFACE_GMII,
			PHY_ManagementInterface		=> NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO
		)
	);
	
	CONSTANT C_BOARD_ML605			: T_BOARD_DESCRIPTION		:= C_BOARD_ML505;
	CONSTANT C_BOARD_KC705			: T_BOARD_DESCRIPTION		:= C_BOARD_ML505;
	CONSTANT C_BOARD_VC707			: T_BOARD_DESCRIPTION		:= C_BOARD_ML505;
end;


package body board is

	-- purpose: extract vendor from MY_DEVICE
	function MY_DEVICE_STRING(BoardConfig : string := "None") return string is
		constant MY_BRD : string := ite((BoardConfig = "None"), MY_BOARD, BoardConfig);
	begin
		if str_equal(MY_BRD, "Custom") then
			return "Device is unknown for a custom board";
		else
			case MY_BRD'length is
				when 3 =>
					case MY_BRD(1 to 3) is
						when "DE0" =>				return "EP3C------";
						when "DE4" =>				return "EP4S------";
						when "DE5" =>				return "EP5S------";
						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
					end case;
				when 5 =>
					case MY_BRD(1 to 5) is
						when "ML505" =>			return "XC5VLX50T";
						when "ML605" =>			return "XC6VLX240T";
						when "KC705" =>			return "XC7K325T";
			--			when "VC707" =>			return "XC7VX485T";
						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
					end case;
				when 8 =>
					case MY_BRD(1 to 8) is
						when "S2GXAVDK" =>	return "EP2S------";
						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
					end case;
				when others => 		 			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
														 -- return statement is explicitly missing otherwise XST won't stop
			end case;
		end if;
	end MY_DEVICE_STRING;

	-- purpose: extract vendor from MY_DEVICE
	function MY_BOARD_STRUCT(BoardConfig : string := "None") return T_BOARD_DESCRIPTION is
		constant MY_BRD : string := ite((BoardConfig = "None"), MY_BOARD, BoardConfig);
	begin
		if str_equal(MY_BRD, "Custom") then
			report "A custom board has no predefined MY_BOARD_STRUCT" severity failure;
		else
			case MY_BRD'length is
--				when 3 =>
--					case MY_BRD(1 to 3) is
--						when "DE0" =>				return "EP3C------";
--						when "DE4" =>				return "EP4S------";
--						when "DE5" =>				return "EP5S------";
--						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
--					end case;
				when 5 =>
					case MY_BRD(1 to 5) is
						when "ML505" =>			return C_BOARD_ML505;
						when "ML605" =>			return C_BOARD_ML605;
						when "KC705" =>			return C_BOARD_KC705;
						when "VC707" =>			return C_BOARD_VC707;
						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
					end case;
--				when 8 =>
--					case MY_BRD(1 to 8) is
--						when "S2GXAVDK" =>	return "EP2S------";
--						when others =>			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
--					end case;
				when others => 		 			report "Unknown board name in MY_BOARD = " & MY_BRD & "." severity failure;
														 -- return statement is explicitly missing otherwise XST won't stop
			end case;
		end if;
	end MY_BOARD_STRUCT;
end board;
