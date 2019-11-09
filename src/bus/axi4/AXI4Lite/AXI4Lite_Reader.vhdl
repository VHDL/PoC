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


entity AXI4Lite_Reader is
	port ( 
		Clock         : in  std_logic;
		Reset         : in  std_logic;

		Strobe        : in  std_logic;
		Address       : in  unsigned;
		Ready         : out std_logic;

		Data          : out std_logic_vector;
		Done          : out std_logic;
		Error         : out std_logic;

		ARValid       : out std_logic;
		ARReady       : in  std_logic;
		ARAddr        : out unsigned;
		ARCache       : out T_AXI4_Cache   := C_AXI4_Cache;
		ARProt        : out T_AXI4_Protect := C_AXI4_Protect;

		RValid        : in  std_logic;
		RReady        : out std_logic;
		RData         : in  std_logic_vector;
		RResp         : in  T_AXI4_Response
	);
end entity;


architecture rtl of AXI4Lite_Reader is
	type T_State is (S_Idle, S_Write, S_wait);

	signal State : T_State := S_Idle;

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			Done        <= '0';
			Error       <= '0';
			ARValid     <= '0';
			RReady      <= '0';
			Ready       <= '0';
			
			if Reset = '1' then
				State  <= S_Idle;
			else
				case State is
					when S_Idle =>
						Ready       <= '1';
						if Strobe = '1' then
							Ready     <= '0';
							ARValid   <= '1';
							RReady    <= '1';
							ARAddr    <= Address;
							State     <= S_Write;
						end if;
						
					when S_Write =>
						ARValid     <= '1';
						RReady      <= '1';
						if ARReady = '1' then
							ARValid     <= '0';
							if RResp = C_AXI4_RESPONSE_OKAY then
								if RValid = '1' then
									RReady <= '0';
									Data   <= RData;
									State  <= S_Idle;
									Done   <= '1';
								else
									State  <= S_wait;
								end if;
							else
								Error       <= '1';
								State  <= S_Idle;
							end if;
						end if;
						
					when S_wait =>
						RReady   <= '1';
						if RValid = '1' then
							RReady <= '0';
							Data   <= RData;
							State  <= S_Idle;
							Done   <= '1';
						end if;
					when others =>
						Error  <= '1';
						State  <= S_Idle;
				end case;
			end if;
		end if;
	end process;
end architecture;