-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Max Kraft-Kugler
--                  Stefan Unrein
--                  Patrick Lehmann
--
-- Package:				 	Generic AMBA AXI4-Stream bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4-Stream description.
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


package AXI4Stream is
	type T_AXI4Stream_M2S is record
		Valid : std_logic;
		Data  : std_logic_vector;
		Last  : std_logic;
		User  : std_logic_vector;
    	Keep  : std_logic_vector;
    -- Strobe       : std_logic_vector;
    -- Identifier   : std_logic_vector;
    -- Destination  : std_logic_vector;
	end record;
	
	type T_AXI4Stream_S2M is record
		Ready : std_logic;
	end record;

	type T_AXI4Stream_M2S_VECTOR is array(natural range <>) of T_AXI4Stream_M2S;
	type T_AXI4Stream_S2M_VECTOR is array(natural range <>) of T_AXI4Stream_S2M;

	function Initialize_AXI4Stream_M2S(DataBits : natural; UserBits : natural := 0; Value : std_logic := 'Z') return T_AXI4Stream_M2S;
	function Initialize_AXI4Stream_S2M(                    UserBits : natural := 0; Value : std_logic := 'Z') return T_AXI4Stream_S2M;
end package;


package body AXI4Stream is 
	function Initialize_AXI4Stream_M2S(DataBits : natural; UserBits : natural := 0; Value : std_logic := 'Z') return T_AXI4Stream_M2S is
		variable init : T_AXI4Stream_M2S(
				Data(DataBits -1 downto 0),
				User(UserBits -1 downto 0)
			) := (
				Valid => Value,
				Data  => (others => Value),
				Last  => Value,
				User  => (others => Value)
			);
	begin
		return init;
	end function;
	
	function Initialize_AXI4Stream_S2M(UserBits : natural := 0; Value : std_logic := 'Z') return T_AXI4Stream_S2M is
		variable init : T_AXI4Stream_S2M := (Ready => Value);
	begin
		return init;
	end function;
end package body;
