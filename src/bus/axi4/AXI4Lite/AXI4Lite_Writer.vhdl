-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	TBD
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.axi4lite.all;


entity AXI4Lite_Writer is
	port ( 
		Clock       : in  std_logic;
		Reset       : in  std_logic;
		
		Strobe      : in  std_logic;
		Address     : in  unsigned;
		Data        : in  std_logic_vector;
		Ready       : out std_logic;
		Done        : out std_logic;
		Error       : out std_logic;
		
		AWValid     : out std_logic; 
		AWReady     : in  std_logic;
		AWAddr      : out unsigned; 
		AWCache     : out T_AXI4_Cache   := C_AXI4_Cache;
		AWProt      : out T_AXI4_Protect := C_AXI4_Protect;
		 
		WValid      : out std_logic;
		WReady      : in  std_logic;
		WData       : out std_logic_vector;
		WStrb       : out std_logic_vector;
	 
		BValid      : in  std_logic;
		BReady      : out std_logic;
		BResp       : in  T_AXI4_Response
		
	);
end entity;


architecture rtl of AXI4Lite_Writer is
	type T_State is (S_Idle, S_Write, S_data_wait, S_Resp_wait);

	signal State : T_State := S_Idle;

begin
	WStrb <= (others => '1');

	process(Clock)
	begin
		if rising_edge(Clock) then
			Ready   <= '0';
			Done    <= '0';
			Error   <= '0';
			AWValid <= '0';
			WValid  <= '0';
			BReady  <= '0';
			
			if Reset = '1' then
				State <= S_Idle;
			else
				case State is
					when S_Idle =>
						Ready   <= '1';
						if Strobe = '1' then
							Ready   <= '0';
							AWValid <= '1';
							WValid  <= '1';
							AWAddr  <= Address;
							WData   <= Data;
							State <= S_Write;
						end if;
					when S_Write =>
						AWValid <= '1';
						WValid  <= '1';
						if AWReady = '1' then
							AWValid <= '0';
							if WReady = '1' then
								WValid  <= '0';
								BReady  <= '1';
								State   <= S_Resp_wait;
							else
								State   <= S_data_wait;
							end if;
						end if;
					when S_data_wait =>
						WValid  <= '1';
						if WReady = '1' then
							WValid  <= '0';
							BReady  <= '1';
							State   <= S_Resp_wait;
						end if;
					when S_Resp_wait =>
						BReady  <= '1';
						if BValid = '1' then
							BReady  <= '0';
							if BResp = C_AXI4_RESPONSE_OKAY then
								Done    <= '1';
							else
								Error <= '1';
							end if;
							State <= S_Idle;
						end if;
						
					when others =>
						State <= S_Idle;
						Error <= '1';
				end case;
			end if;
		end if;
	end process;
end architecture;
