-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Generic Dynamic Reconfiguration Port(DRP) bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic Dynamic Reconfiguration Port(DRP) description.
--
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


package DRP is

	type T_DRP_Bus_S2M is record
		Ready         : std_logic; 
		DataOut       : std_logic_vector; 
	end record;
  type T_DRP_Bus_S2M_VECTOR is array(natural range <>) of T_DRP_Bus_S2M;

	type T_DRP_Bus_M2S is record
		Enable        : std_logic; 
		WriteEnable   : std_logic; 
		Address       : unsigned; 
		DataIn        : std_logic_vector; 
	end record;
  type T_DRP_Bus_M2S_VECTOR is array(natural range <>) of T_DRP_Bus_M2S;	
	
  type T_DRP_Bus is record
    M2S   : T_DRP_Bus_M2S;
    S2M   : T_DRP_Bus_S2M;
  end record;
  type T_DRP_Bus_VECTOR is array(natural range <>) of T_DRP_Bus;
  

	function Initialize_DRP_Bus_M2S(AddressBits : natural; DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus_M2S;
	function Initialize_DRP_Bus_S2M(                       DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus_S2M;
	function Initialize_DRP_Bus(    AddressBits : natural; DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus;

end package;


package body DRP is
  function Initialize_DRP_Bus_M2S(AddressBits : natural; DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus_M2S is
    variable var : T_DRP_Bus_M2S :=(
        Enable      => Value,
        WriteEnable => Value,
        Address     => (AddressBits-1 downto 0 => Value), 
        DataIn      => (DataBits - 1 downto 0 => Value)
      );
  begin
    return var;
  end function;

  function Initialize_DRP_Bus_S2M(DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus_S2M is
    variable var : T_DRP_Bus_S2M :=(
      Ready => Value,
      DataOut   => (DataBits - 1 downto 0 => Value)
    );
  begin
    return var;
  end function;

  function Initialize_DRP_Bus(AddressBits : natural; DataBits : natural := 16; Value : std_logic := 'Z') return T_DRP_Bus is
  begin
    return ( 
      M2S => Initialize_DRP_Bus_M2S(AddressBits, DataBits, Value),
      S2M => Initialize_DRP_Bus_S2M(DataBits, Value)
    );
  end function;

 end package body;
