-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4 bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4 description for:
--
-- * AXI4 (full)
-- * AXI4-Lite
-- * AXI4-Stream
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
-- Copyright 2017-2019 Patrick Lehmann - Bötzingen, Germany
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
use     work.AXI4_Common.all;
use     work.AXI4Stream.all;
use     work.AXI4Lite.all;
use     work.AXI4_Full.all;


  -- Generic
--    axi_addr_width   : natural := 32;
--    axi_data_width   : natural := 32;
--    axi_id_width     : natural := 2;
--    axi_user_width   : natural := 4


package AXI4 is
  -------Define AXI Register structure-------------
  constant Address_Width  : natural := 32;
  constant Data_Width  : natural := 32;
--  type T_AXI4_Register is record
--    Address : unsigned;
--    Data    : std_logic_vector;
--    Mask    : std_logic_vector;
--  end record;
  type T_AXI4_Register is record
    Address : unsigned(Address_Width -1 downto 0);
    Data    : std_logic_vector(Data_Width -1 downto 0);
    Mask    : std_logic_vector(Data_Width -1 downto 0);
  end record;
  
--  function to_AXI4_Register(Address : unsigned; Data : std_logic_vector; Mask : std_logic_vector; AddressBits : natural; DataBits : natural) return T_AXI4_Register;
  function to_AXI4_Register(Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register;
--  function Initialize_AXI4_register(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4_Register;
  function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register;
  
  type T_AXI4_Register_Vector is array (natural range <>) of T_AXI4_Register;
  
  type T_AXI4_Register_Set is record
    AXI4_Register  : T_AXI4_Register_Vector;
    Last_Index     : natural;
  end record;
  
  type T_AXI4_Register_Set_VECTOR is array (natural range <>) of T_AXI4_Register_Set;
  
  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set;
  

  type T_AXI4_Register_Description is record
		Address             : unsigned(Address_Width-1 downto 0);
		Writeable           : boolean;
		Init_Value          : std_logic_vector(Data_Width-1 downto 0);
		Auto_Clear_Mask     : std_logic_vector(Data_Width-1 downto 0);
  end record;
  
  type T_AXI4_Register_Description_Vector is array (natural range <>) of T_AXI4_Register_Description;
  
  function to_AXI4_Register_Description(	Address : unsigned(Address_Width -1 downto 0); 
  																				Writeable : boolean := true; 
  																				Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
  																				Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
																				) return T_AXI4_Register_Description;
  
  ----^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  
  -- AXI4 common types and constants
  alias T_AXI4_Response               is work.AXI4_Common.T_AXI4_Response;
	alias C_AXI4_RESPONSE_OKAY          is work.AXI4_Common.C_AXI4_RESPONSE_OKAY;
	alias C_AXI4_RESPONSE_EX_OKAY       is work.AXI4_Common.C_AXI4_RESPONSE_EX_OKAY;
	alias C_AXI4_RESPONSE_SLAVE_ERROR   is work.AXI4_Common.C_AXI4_RESPONSE_SLAVE_ERROR;
	alias C_AXI4_RESPONSE_DECODE_ERROR  is work.AXI4_Common.C_AXI4_RESPONSE_DECODE_ERROR;
	alias C_AXI4_RESPONSE_INIT          is work.AXI4_Common.C_AXI4_RESPONSE_INIT;
  
  alias T_AXI4_Cache                  is work.AXI4_Common.T_AXI4_Cache;
  alias C_AXI4_CACHE_INIT             is work.AXI4_Common.C_AXI4_CACHE_INIT;
  alias C_AXI4_CACHE                  is work.AXI4_Common.C_AXI4_CACHE;

  alias T_AXI4_QoS                    is work.AXI4_Common.T_AXI4_QoS;
  alias C_AXI4_QOS_INIT               is work.AXI4_Common.C_AXI4_QOS_INIT;

  alias T_AXI4_Region                 is work.AXI4_Common.T_AXI4_Region;
  alias C_AXI4_REGION_INIT            is work.AXI4_Common.C_AXI4_REGION_INIT;

  alias T_AXI4_Size                   is work.AXI4_Common.T_AXI4_Size;
  alias C_AXI4_SIZE_1                 is work.AXI4_Common.C_AXI4_SIZE_1;
  alias C_AXI4_SIZE_2                 is work.AXI4_Common.C_AXI4_SIZE_2;
  alias C_AXI4_SIZE_4                 is work.AXI4_Common.C_AXI4_SIZE_4;
  alias C_AXI4_SIZE_8                 is work.AXI4_Common.C_AXI4_SIZE_8;
  alias C_AXI4_SIZE_16                is work.AXI4_Common.C_AXI4_SIZE_16;
  alias C_AXI4_SIZE_32                is work.AXI4_Common.C_AXI4_SIZE_32;
  alias C_AXI4_SIZE_64                is work.AXI4_Common.C_AXI4_SIZE_64;
  alias C_AXI4_SIZE_128               is work.AXI4_Common.C_AXI4_SIZE_128;
  alias C_AXI4_SIZE_INIT              is work.AXI4_Common.C_AXI4_SIZE_INIT;

  alias T_AXI4_Burst                  is work.AXI4_Common.T_AXI4_Burst;
  alias C_AXI4_BURST_FIXED            is work.AXI4_Common.C_AXI4_BURST_FIXED;
  alias C_AXI4_BURST_INCR             is work.AXI4_Common.C_AXI4_BURST_INCR;
  alias C_AXI4_BURST_WRAP             is work.AXI4_Common.C_AXI4_BURST_WRAP;
  alias C_AXI4_BURST_INIT             is work.AXI4_Common.C_AXI4_BURST_INIT;

  alias T_AXI4_Protect                is work.AXI4_Common.T_AXI4_Protect;
  alias C_AXI4_PROTECT_INIT           is work.AXI4_Common.C_AXI4_PROTECT_INIT;
  alias C_AXI4_PROTECT                is work.AXI4_Common.C_AXI4_PROTECT;


	-- AXI4 (full)
	alias T_AXI4_Bus_M2S           is work.AXI4_Full.T_AXI4_Bus_M2S;
	alias T_AXI4_Bus_S2M           is work.AXI4_Full.T_AXI4_Bus_S2M;
  alias T_AXI4_Bus               is work.AXI4_Full.T_AXI4_Bus;
	
  alias T_AXI4_Bus_M2S_VECTOR    is work.AXI4_Full.T_AXI4_Bus_M2S_VECTOR;
  alias T_AXI4_Bus_S2M_VECTOR    is work.AXI4_Full.T_AXI4_Bus_S2M_VECTOR;
  alias T_AXI4_Bus_VECTOR        is work.AXI4_Full.T_AXI4_Bus_VECTOR;
	
	alias Initialize_AXI4_Bus_M2S  is work.AXI4_Full.Initialize_AXI4_Bus_M2S[natural, natural, natural, natural, std_logic return T_AXI4_Bus_M2S];
	alias Initialize_AXI4_Bus_S2M  is work.AXI4_Full.Initialize_AXI4_Bus_S2M[natural, natural, natural, natural, std_logic return T_AXI4_Bus_S2M];
	alias Initialize_AXI4_Bus      is work.AXI4_Full.Initialize_AXI4_Bus    [natural, natural, natural, natural return T_AXI4_Bus];
  
	
	-- AXI4-Lite
	alias T_AXI4Lite_Bus_M2S           is work.AXI4Lite.T_AXI4Lite_Bus_M2S;
	alias T_AXI4Lite_Bus_S2M           is work.AXI4Lite.T_AXI4Lite_Bus_S2M;
  alias T_AXI4Lite_Bus               is work.AXI4Lite.T_AXI4Lite_Bus;

  alias T_AXI4Lite_Bus_M2S_VECTOR    is work.AXI4Lite.T_AXI4Lite_Bus_M2S_VECTOR;
  alias T_AXI4Lite_Bus_S2M_VECTOR    is work.AXI4Lite.T_AXI4Lite_Bus_S2M_VECTOR;
  alias T_AXI4Lite_Bus_VECTOR        is work.AXI4Lite.T_AXI4Lite_Bus_VECTOR;

	alias Initialize_AXI4Lite_Bus_M2S  is work.AXI4Lite.Initialize_AXI4Lite_Bus_M2S[natural, natural, std_logic return T_AXI4Lite_Bus_M2S];
	alias Initialize_AXI4Lite_Bus_S2M  is work.AXI4Lite.Initialize_AXI4Lite_Bus_S2M[natural, natural, std_logic return T_AXI4Lite_Bus_S2M];
	alias Initialize_AXI4Lite_Bus      is work.AXI4Lite.Initialize_AXI4Lite_Bus    [natural, natural return T_AXI4Lite_Bus];

	
	-- AXI4-Stream
	alias T_AXI4Stream_M2S is work.AXI4Stream.T_AXI4Stream_M2S;
	alias T_AXI4Stream_S2M is work.AXI4Stream.T_AXI4Stream_S2M;
	
	alias T_AXI4Stream_M2S_VECTOR is work.AXI4Stream.T_AXI4Stream_M2S_VECTOR;
	alias T_AXI4Stream_S2M_VECTOR is work.AXI4Stream.T_AXI4Stream_S2M_VECTOR;

	alias Initialize_AXI4Stream_M2S is work.AXI4Stream.Initialize_AXI4Stream_M2S[natural, natural, std_logic return T_AXI4Stream_M2S];
	alias Initialize_AXI4Stream_S2M is work.AXI4Stream.Initialize_AXI4Stream_S2M[         natural, std_logic return T_AXI4Stream_S2M];
end package;


package body AXI4 is 
  -------Define AXI Register structure-------------
--  function to_AXI4_Register(Address : unsigned; Data : std_logic_vector; Mask : std_logic_vector; AddressBits : natural; DataBits : natural) return T_AXI4_Register is
--    variable temp : T_AXI4_Register(
--      Address(AddressBits -1 downto 0),
--      Data(DataBits -1 downto 0),
--      Mask(DataBits -1 downto 0)) := (
--        Address => Address,
--        Data    => Data,
--        Mask    => Mask
--      );
--  begin
--    return temp;
--  end function;

  function to_AXI4_Register(Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register is
    variable temp : T_AXI4_Register := (
        Address => Address,
        Data    => Data,
        Mask    => Mask
      );
  begin
    return temp;
  end function;
  
--  function Initialize_AXI4_register(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4_Register is
--    variable temp : T_AXI4_Register(
--      Address(AddressBits -1 downto 0),
--      Data(DataBits -1 downto 0),
--      Mask(DataBits -1 downto 0)):= 
--      to_AXI4_Register(
--        Address => (AddressBits -1 downto 0 => Value), 
--        Data => (DataBits -1 downto 0 => Value), 
--        Mask => (DataBits -1 downto 0 => Value),
--        AddressBits => AddressBits,
--        DataBits    => DataBits
--      );
--  begin
--    return temp;
--  end function;
  function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register is
    variable temp : T_AXI4_Register := 
      to_AXI4_Register(
        Address => (Address_Width -1 downto 0 => Value), 
        Data => (Data_Width -1 downto 0 => Value), 
        Mask => (Data_Width -1 downto 0 => Value)
      );
  begin
    return temp;
  end function;
-------------------------------------------------------------------------------------------------------------

--  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set is
--    variable temp : T_AXI4_Register_Set(AXI4_Register(0 to size -1)(
--      Address(reg_vec(reg_vec'left).Address'range),
--      Data(reg_vec(reg_vec'left).Data'range),
--      Mask(reg_vec(reg_vec'left).Mask'range)
--    )--) := (
----      AXI4_Register => 
----        (others => Initialize_AXI4_register(reg_vec(reg_vec'left).Address'length, reg_vec(reg_vec'left).Data'length)),
----      Last_Index => 0
--    );

--  begin
--    temp.AXI4_Register(reg_vec'range) := reg_vec;
--    temp.Last_Index := reg_vec'length -1;
--    return temp;
--  end function;
  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set is
    variable temp : T_AXI4_Register_Set(AXI4_Register(0 to size -1)) := (
      AXI4_Register => (others => Initialize_AXI4_register),
      Last_Index    => 0
    );

  begin
    temp.AXI4_Register(reg_vec'range) := reg_vec;
    temp.Last_Index := reg_vec'length -1;
    return temp;
  end function;
  
	function to_AXI4_Register_Description(	Address : unsigned(Address_Width -1 downto 0); 
  																				Writeable : boolean := true; 
  																				Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
  																				Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
																				) return T_AXI4_Register_Description is
																				
		variable temp : T_AXI4_Register_Description := (
			Address         => Address,
			Writeable       => Writeable,
			Init_Value      => Init_Value,
			Auto_Clear_Mask	=> Auto_Clear_Mask
		);
	begin
		return temp;
	end function;
  
--  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector) return T_AXI4_Register_Set is
--    variable temp : T_AXI4_Register_Set(AXI4_Register(reg_vec'length -1 downto 0), Last_Index(log2ceilnz(reg_vec'length) -1 downto 0)) := (
--      AXI4_Register => reg_vec,
--      Last_Index    => to_unsigned(reg_vec'length, log2ceilnz(reg_vec'length))
--    );
--  begin
--    return temp;
--  end function;
end package body;
